// Ported from vscode src/vs/editor/contrib/codeAction/browser/codeAction.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codeAction.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Range;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * The command ids of codeAction.ts.
 */
class CodeActionCommandIds {
    public static inline final codeActionCommandId = 'editor.action.codeAction';
    public static inline final quickFixCommandId = 'editor.action.quickFix';
    public static inline final autoFixCommandId = 'editor.action.autoFix';
    public static inline final refactorCommandId = 'editor.action.refactor';
    public static inline final refactorPreviewCommandId = 'editor.action.refactor.preview';
    public static inline final sourceActionCommandId = 'editor.action.sourceAction';
    public static inline final organizeImportsCommandId = 'editor.action.organizeImports';
    public static inline final fixAllCommandId = 'editor.action.fixAll';
}

class ManagedCodeActionSet extends Disposable implements CodeActionSet {

    static function codeActionsPreferredComparator(a:CodeAction, b:CodeAction):Int {
        if (a.isPreferred == true && b.isPreferred != true) {
            return -1;
        }
        else if (a.isPreferred != true && b.isPreferred == true) {
            return 1;
        }
        else {
            return 0;
        }
    }

    static inline function isNonEmptyArray(a:Null<Array<Dynamic>>):Bool {
        return a != null && a.length > 0;
    }

    static function codeActionsComparator(itemA:CodeActionItem, itemB:CodeActionItem):Int {
        final a = itemA.action;
        final b = itemB.action;
        if (a.isAI == true && b.isAI != true) {
            return 1;
        }
        else if (a.isAI != true && b.isAI == true) {
            return -1;
        }
        if (isNonEmptyArray(a.diagnostics)) {
            return isNonEmptyArray(b.diagnostics) ? ManagedCodeActionSet.codeActionsPreferredComparator(a, b) : -1;
        }
        else if (isNonEmptyArray(b.diagnostics)) {
            return 1;
        }
        else {
            return ManagedCodeActionSet.codeActionsPreferredComparator(a, b); // both have no diagnostics
        }
    }

    public var validActions(default, null):Array<CodeActionItem>;
    public var allActions(default, null):Array<CodeActionItem>;
    public var documentation(default, null):Array<Command>;

    public function new(actions:Array<CodeActionItem>, documentation:Array<Command>, disposables:DisposableStore) {
        super();

        this._register(disposables);
        this.documentation = documentation;

        final all = actions.copy();
        haxe.ds.ArraySort.sort(all, ManagedCodeActionSet.codeActionsComparator);
        this.allActions = all;
        this.validActions = [for (item in all) if (item.action.disabled == null || item.action.disabled.length == 0) item];
    }

    public var hasAutoFix(get, never):Bool;
    function get_hasAutoFix():Bool {
        for (item in validActions) {
            final fix = item.action;
            if (fix.kind != null && fix.kind.length > 0 && CodeActionKind.QuickFix.contains(new HierarchicalKind(fix.kind)) && fix.isPreferred == true) {
                return true;
            }
        }
        return false;
    }

    public var hasAIFix(get, never):Bool;
    function get_hasAIFix():Bool {
        for (item in validActions) {
            if (item.action.isAI == true) {
                return true;
            }
        }
        return false;
    }

    public var allAIFixes(get, never):Bool;
    function get_allAIFixes():Bool {
        for (item in validActions) {
            if (item.action.isAI != true) {
                return false;
            }
        }
        return true;
    }
}

enum abstract ApplyCodeActionReason(String) from String to String {
    var OnSave = 'onSave';
    var FromProblemsView = 'fromProblemsView';
    var FromCodeActions = 'fromCodeActions';
    var FromAILightbulb = 'fromAILightbulb'; // direct invocation when clicking on the AI lightbulb
}

/**
 * Module functions of codeAction.ts, and Monaco's standalone bulk edit
 * service.
 */
class CodeActionUtils {

    /**
     * Asks the code action providers of the model for code actions (Monaco's
     * `getCodeActions`). `progress` is called with each provider asked.
     * Monaco's `TextModelCancellationTokenSource` (cancel when the model
     * changes) is kept: the request is cancelled when the model content
     * changes before the providers answer.
     */
    public static function getCodeActions(registry:LanguageFeatureRegistry<CodeActionProvider>, model:ITextModel, rangeOrSelection:Range, trigger:CodeActionTrigger, ?progress:(provider:CodeActionProvider) -> Void, ?token:CancellationToken):Promise<CodeActionSet> {
        final filter:CodeActionFilter = trigger.filter != null ? trigger.filter : {};
        final notebookFilter:CodeActionFilter = {
            include: filter.include,
            excludes: (filter.excludes != null ? filter.excludes : []).concat([CodeActionKind.Notebook]),
            includeSourceActions: filter.includeSourceActions,
            onlyIncludePreferredActions: filter.onlyIncludePreferredActions
        };

        final codeActionContext:CodeActionContext = {
            only: filter.include != null ? filter.include.value : null,
            trigger: trigger.type,
        };

        final cts = new CancellationTokenSource(token);
        final contentListener = model.onDidChangeContent(_ -> cts.cancel());
        // if the trigger is auto (autosave, lightbulb, etc), we should exclude notebook codeActions
        final excludeNotebookCodeActions = (trigger.type == CodeActionTriggerType.Auto);
        final providers = getCodeActionProviders(registry, model, excludeNotebookCodeActions ? notebookFilter : filter);

        final disposables = new DisposableStore();
        final promises:Array<Promise<{actions:Array<CodeActionItem>, documentation:Null<Command>}>> = [for (provider in providers) {
            if (progress != null) {
                progress(provider);
            }
            Promise.fromCallback(done -> {
                try {
                    provider.provideCodeActions(model, rangeOrSelection, codeActionContext, cts.token, done);
                }
                catch (err:Dynamic) {
                    Errors.onUnexpectedExternalError(err);
                    done(null);
                }
            }).then(providedCodeActions -> {
                if (providedCodeActions != null && providedCodeActions.dispose != null) {
                    disposables.add(Lifecycle.toDisposable(providedCodeActions.dispose));
                }

                if (cts.token.isCancellationRequested) {
                    return {actions: [], documentation: null};
                }

                final provided = providedCodeActions != null && providedCodeActions.actions != null ? providedCodeActions.actions : [];
                final filteredActions = [for (action in provided) if (action != null && CodeActionFilters.filtersAction(filter, action)) action];
                final documentation = getDocumentationFromProvider(provider, filteredActions, filter.include);
                return {
                    actions: [for (action in filteredActions) new CodeActionItem(action, provider)],
                    documentation: documentation
                };
            });
        }];

        final listener = registry.onDidChange(_ -> {
            final newProviders = registry.all(model);
            if (!cityscape.base.common.Arrays.equals(newProviders, providers)) {
                cts.cancel();
            }
        });

        return Promise.all(promises).then(actions -> {
            listener.dispose();
            contentListener.dispose();
            cts.dispose();
            final allActions:Array<CodeActionItem> = [];
            final allDocumentation:Array<Command> = [];
            for (x in actions) {
                for (a in x.actions) {
                    allActions.push(a);
                }
                if (x.documentation != null) {
                    allDocumentation.push(x.documentation);
                }
            }
            return (new ManagedCodeActionSet(allActions, allDocumentation, disposables) : CodeActionSet);
        }, err -> {
            listener.dispose();
            contentListener.dispose();
            cts.dispose();
            throw err;
        });
    }

    static function getCodeActionProviders(registry:LanguageFeatureRegistry<CodeActionProvider>, model:ITextModel, filter:CodeActionFilter):Array<CodeActionProvider> {
        return registry.all(model)
            // Don't include providers that we know will not return code actions of interest
            .filter(provider -> {
                if (provider.providedCodeActionKinds == null) {
                    // We don't know what type of actions this provider will return.
                    return true;
                }
                for (kind in provider.providedCodeActionKinds) {
                    if (CodeActionFilters.mayIncludeActionsOfKind(filter, new HierarchicalKind(kind))) {
                        return true;
                    }
                }
                return false;
            });
    }

    static function getDocumentationFromProvider(provider:CodeActionProvider, providedCodeActions:Array<CodeAction>, ?only:HierarchicalKind):Null<Command> {
        if (provider.documentation == null) {
            return null;
        }

        final documentation = [for (entry in provider.documentation) {kind: new HierarchicalKind(entry.kind), command: entry.command}];

        if (only != null) {
            var currentBest:Null<{kind:HierarchicalKind, command:Command}> = null;
            for (entry in documentation) {
                if (entry.kind.contains(only)) {
                    if (currentBest == null) {
                        currentBest = entry;
                    }
                    else {
                        // Take best match
                        if (currentBest.kind.contains(entry.kind)) {
                            currentBest = entry;
                        }
                    }
                }
            }
            if (currentBest != null) {
                return currentBest.command;
            }
        }

        // Otherwise, check to see if any of the provided actions match.
        for (action in providedCodeActions) {
            if (action.kind == null || action.kind.length == 0) {
                continue;
            }

            for (entry in documentation) {
                if (entry.kind.contains(new HierarchicalKind(action.kind))) {
                    return entry.command;
                }
            }
        }
        return null;
    }

    /**
     * Applies a code action (Monaco's `applyCodeAction`): resolves its edit,
     * applies the text edits of its workspace edit, then runs its command.
     * `callback` is called once done (with false when nothing was applied).
     */
    public static function applyCodeAction(context:Cityscape, item:CodeActionItem, codeActionReason:ApplyCodeActionReason, ?editor:ICodeEditor, ?token:CancellationToken, ?callback:(applied:Bool) -> Void):Void {
        if (token == null) {
            token = CancellationTokens.None;
        }
        final tok = token;
        item.resolve(tok).done(_ -> {
            if (tok.isCancellationRequested) {
                if (callback != null) {
                    callback(false);
                }
                return;
            }

            final edit = item.action.edit;
            if (edit != null && edit.edits != null && edit.edits.length > 0) {
                var applied = false;
                try {
                    applied = applyWorkspaceEdit(context, edit, editor);
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                    applied = false;
                }
                if (!applied) {
                    if (callback != null) {
                        callback(false);
                    }
                    return;
                }
            }

            final command = item.action.command;
            if (command != null) {
                try {
                    context.commandService.executeCommand(command.id, command.arguments != null ? command.arguments.copy() : []);
                }
                catch (err:Dynamic) {
                    Errors.onUnexpectedError(err);
                }
            }
            if (callback != null) {
                callback(true);
            }
        });
    }

    /**
     * The model of a resource: a model of the model service, or the model of
     * an editor of the context.
     */
    static function findModel(context:Cityscape, resource:Uri):Null<ITextModel> {
        final model = context.modelService.getModel(resource);
        if (model != null) {
            return model;
        }
        final key = resource.toString();
        for (editor in context.codeEditorService.listCodeEditors()) {
            final m = editor.getModel();
            if (m != null && m.uri.toString() == key) {
                return m;
            }
        }
        return null;
    }

    /**
     * Applies the text edits of a workspace edit (Monaco's
     * `StandaloneBulkEditService.apply`): one undo stop around the edits of
     * each model. File operations are not supported (like Monaco's
     * standalone editor, an error is thrown); a host applies them itself
     * with `Cityscape.workspaceEditHandler`. Returns whether edits were
     * applied.
     */
    public static function applyWorkspaceEdit(context:Cityscape, edit:WorkspaceEdit, ?editor:ICodeEditor):Bool {
        final handler = context.workspaceEditHandler;
        if (handler != null && handler(edit, editor)) {
            return true;
        }
        final models:Array<ITextModel> = [];
        final textEdits:Array<Array<ISingleEditOperation>> = [];

        for (e in edit.edits) {
            if (JsValues.field(e, 'resource') == null) {
                throw 'bad edit - only text edits are supported';
            }
            final textEdit:IWorkspaceTextEdit = cast e;
            final model = findModel(context, textEdit.resource);
            if (model == null) {
                throw 'bad edit - model not found';
            }
            if (textEdit.versionId != null && model.getVersionId() != textEdit.versionId) {
                throw 'bad state - model changed in the meantime';
            }
            var index = models.indexOf(model);
            if (index < 0) {
                index = models.length;
                models.push(model);
                textEdits.push([]);
            }
            textEdits[index].push(EditOperation.replaceMove(Range.lift(textEdit.textEdit.range), textEdit.textEdit.text));
        }

        var totalEdits = 0;
        for (i in 0...models.length) {
            final model = models[i];
            final edits = textEdits[i];
            model.pushStackElement();
            model.pushEditOperations([], cast edits, _ -> []);
            model.pushStackElement();
            totalEdits += edits.length;
        }

        return totalEdits > 0;
    }

}
