// Ported from vscode src/vs/editor/contrib/rename/browser/rename.ts
// (and the EditorStateCancellationTokenSource of
// src/vs/editor/contrib/editorState/browser/editorState.ts that it uses)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.rename.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.base.common.Uri;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.RenameLocation;
import cityscape.common.Languages.RenameProvider;
import cityscape.common.Languages.WorkspaceEdit;
import cityscape.common.Languages.WorkspaceEditAndRejection;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.codeAction.view.CodeAction.CodeActionUtils;
import cityscape.contrib.rename.view.RenameWidget;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;

/**
 * Monaco's `CodeEditorStateFlag`.
 */
class CodeEditorStateFlag {
    public static inline final Value = 1;
    public static inline final Selection = 2;
    public static inline final Position = 4;
    public static inline final Scroll = 8;
}

/**
 * A cancellation token source that cancels when the editor changes as
 * expressed by the provided flags (editorState.ts); changes of the
 * position and the selection inside `range` do not cancel. Monaco's parent
 * class also cancels on the `editor.cancelOperation` keybinding (Escape),
 * not ported (the rename input cancels on Escape itself).
 */
class EditorStateCancellationTokenSource extends CancellationTokenSource {

    final _listener = new DisposableStore();

    public function new(editor:ICodeEditor, flags:Int, ?range:IRange, ?parent:CancellationToken) {
        super(parent);

        if ((flags & CodeEditorStateFlag.Position) != 0) {
            this._listener.add(editor.onDidChangeCursorPosition(e -> {
                if (range == null || !Range.containsPositionStatic(range, e.position)) {
                    this.cancel();
                }
            }));
        }
        if ((flags & CodeEditorStateFlag.Selection) != 0) {
            this._listener.add(editor.onDidChangeCursorSelection(e -> {
                if (range == null || !Range.containsRangeStatic(range, e.selection)) {
                    this.cancel();
                }
            }));
        }
        if ((flags & CodeEditorStateFlag.Scroll) != 0) {
            this._listener.add(editor.onDidScrollChange(_ -> this.cancel()));
        }
        if ((flags & CodeEditorStateFlag.Value) != 0) {
            this._listener.add(editor.onDidChangeModel(_ -> this.cancel()));
            this._listener.add(editor.onDidChangeModelContent(_ -> this.cancel()));
        }
    }

    /**
     * Monaco's override takes no argument: `dispose(true)` does not cancel
     * the token (the rename widget disposes its token source this way when
     * the input is done, and the rename goes on with that token).
     */
    override public function dispose(cancel:Bool = false):Void {
        this._listener.dispose();
        super.dispose();
    }

}

/**
 * The providers of a rename at a position, asked in order (Monaco's
 * `RenameSkeleton`): the first location a provider resolves (or the word at
 * the position), then the edits of the provider that resolved it, or of the
 * next ones when it gives none.
 */
class RenameSkeleton {

    final _providers:Array<RenameProvider>;
    var _providerRenameIdx:Int = 0;
    final model:ITextModel;
    final position:Position;
    final _localize:(key:String, message:String) -> String;

    /**
     * `localize`: the NLS of the context (`context.nls.localize`).
     */
    public function new(model:ITextModel, position:Position, registry:LanguageFeatureRegistry<RenameProvider>, ?localize:(key:String, message:String) -> String) {
        this.model = model;
        this.position = position;
        this._providers = registry.ordered(model);
        this._localize = localize != null ? localize : (_, message) -> message;
    }

    public function hasProvider():Bool {
        return this._providers.length > 0;
    }

    /**
     * Resolves with the location to rename (`RenameLocation` with an
     * optional `rejectReason`).
     */
    public function resolveRenameLocation(token:CancellationToken):Promise<RenameLocation> {
        final rejects:Array<String> = [];
        return this._resolveRenameLocation(0, rejects, token);
    }

    function _resolveRenameLocation(index:Int, rejects:Array<String>, token:CancellationToken):Promise<RenameLocation> {
        this._providerRenameIdx = index;
        if (index < this._providers.length) {
            final provider = this._providers[index];
            final resolve = provider.resolveRenameLocation;
            if (resolve != null) {
                return new Promise<RenameLocation>((done, _) -> resolve(this.model, this.position, token, done)).thenPromise(res -> {
                    if (res == null) {
                        return this._resolveRenameLocation(index + 1, rejects, token);
                    }
                    if (JsValues.truthy(res.rejectReason)) {
                        rejects.push(res.rejectReason);
                        return this._resolveRenameLocation(index + 1, rejects, token);
                    }
                    return Promise.resolve(res);
                });
            }
        }

        // we are here when no provider prepared a location which means we can
        // just rely on the word under cursor and start with the first provider
        this._providerRenameIdx = 0;

        final word = this.model.getWordAtPosition(this.position);
        if (word == null) {
            final location:RenameLocation = {
                range: Range.fromPositions(this.position),
                text: '',
                rejectReason: rejects.length > 0 ? rejects.join('\n') : null
            };
            return Promise.resolve(location);
        }
        final location:RenameLocation = {
            range: new Range(this.position.lineNumber, word.startColumn, this.position.lineNumber, word.endColumn),
            text: word.word,
            rejectReason: rejects.length > 0 ? rejects.join('\n') : null
        };
        return Promise.resolve(location);
    }

    public function provideRenameEdits(newName:String, token:CancellationToken):Promise<WorkspaceEditAndRejection> {
        return this._provideRenameEdits(newName, this._providerRenameIdx, [], token);
    }

    function _provideRenameEdits(newName:String, i:Int, rejects:Array<String>, token:CancellationToken):Promise<WorkspaceEditAndRejection> {
        final provider = i < this._providers.length ? this._providers[i] : null;
        if (provider == null) {
            final result:WorkspaceEditAndRejection = {
                edits: [],
                rejectReason: rejects.join('\n')
            };
            return Promise.resolve(result);
        }

        return new Promise<WorkspaceEditAndRejection>((done, _) -> provider.provideRenameEdits(this.model, this.position, newName, token, done)).thenPromise(result -> {
            if (result == null) {
                return this._provideRenameEdits(newName, i + 1, rejects.concat([this._localize('no result', "No result.")]), token);
            }
            else if (JsValues.truthy(result.rejectReason)) {
                return this._provideRenameEdits(newName, i + 1, rejects.concat([result.rejectReason]), token);
            }
            return Promise.resolve(result);
        });
    }

}

/**
 * The rename controller of an editor: F2 resolves the location, shows the
 * rename input over it, then asks the providers for the edits and applies
 * them (one undo stop, like Monaco's standalone bulk edit service).
 *
 * Monaco's `MessageController` (a message at the cursor for a rejected
 * location) and its notifications (the reason a provider rejected the
 * rename, "Rename failed to compute edits", "Rename failed to apply edits")
 * go to `Cityscape.onNoResult`, with the position of the rename. The
 * progress indicator, the telemetry, the preview of the edits and the new
 * symbol names providers are not ported.
 */
class RenameController implements IEditorContribution {

    public static inline final ID = 'editor.contrib.renameController';

    public static function get(editor:ICodeEditor):Null<RenameController> {
        return editor.getContribution(RenameController.ID);
    }

    final editor:ICodeEditor;
    final _renameWidget:RenameWidget;
    final _disposableStore = new DisposableStore();
    var _cts:CancellationTokenSource = new CancellationTokenSource();

    public function new(editor:ICodeEditor) {
        this.editor = editor;
        this._renameWidget = this._disposableStore.add(new RenameWidget(this.editor, ['acceptRenameInput', 'acceptRenameInputWithPreview'], editor.contextKeyService));
    }

    public function dispose():Void {
        this._disposableStore.dispose();
        this._cts.dispose(true);
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * The rename input (tests, the visual check).
     */
    public function getRenameWidget():RenameWidget {
        return this._renameWidget;
    }

    function localize(key:String, message:String, ?args:Array<Any>):String {
        return this.editor.context.nls.localize(key, message, args);
    }

    function showMessage(message:String, position:Position):Void {
        final f = this.editor.context.onNoResult;
        if (f != null) {
            f(this.editor, message, position);
        }
    }

    /**
     * Runs a rename at the cursor. The promise settles when the edits were
     * applied (or the rename ended without edits).
     */
    public function run():Promise<Any> {

        // set up cancellation token to prevent reentrant rename, this
        // is the parent to the resolve- and rename-tokens
        this._cts.dispose(true);
        this._cts = new CancellationTokenSource();

        if (!this.editor.hasModel()) {
            return Promise.resolve(null);
        }

        final position = this.editor.getPosition();
        final skeleton = new RenameSkeleton(this.editor.getModel(), position, this.editor.context.languageFeaturesService.renameProvider, (key, message) -> localize(key, message));

        if (!skeleton.hasProvider()) {
            return Promise.resolve(null);
        }

        // part 1 - resolve rename location
        final cts1 = new EditorStateCancellationTokenSource(this.editor, CodeEditorStateFlag.Position | CodeEditorStateFlag.Value, null, this._cts.token);

        return skeleton.resolveRenameLocation(cts1.token).thenPromise(loc -> {
            cts1.dispose();

            if (loc == null) {
                return Promise.resolve(null);
            }

            if (JsValues.truthy(loc.rejectReason)) {
                showMessage(loc.rejectReason, position);
                return Promise.resolve(null);
            }

            if (cts1.token.isCancellationRequested) {
                return Promise.resolve(null);
            }

            // part 2 - do rename at location
            final locRange = Range.lift(loc.range);
            final cts2 = new EditorStateCancellationTokenSource(this.editor, CodeEditorStateFlag.Position | CodeEditorStateFlag.Value, locRange, this._cts.token);

            // the standalone editor has no preview handler (bulk edit service)
            final supportPreview = false;
            return this._renameWidget.getInput(locRange, loc.text, supportPreview, cts2).thenPromise((inputFieldResult:Any) -> {

                // no result, only hint to focus the editor or not
                if (JsValues.isBoolean(inputFieldResult)) {
                    if ((inputFieldResult : Bool)) {
                        this.editor.focus();
                    }
                    cts2.dispose();
                    return Promise.resolve(null);
                }
                final widgetResult:RenameWidgetResult = inputFieldResult;

                this.editor.focus();

                return raceCancellation(skeleton.provideRenameEdits(widgetResult.newName, cts2.token), cts2.token).then(renameResult -> {
                    if (renameResult == null) {
                        return null;
                    }
                    if (!this.editor.hasModel()) {
                        return null;
                    }

                    if (JsValues.truthy(renameResult.rejectReason)) {
                        showMessage(renameResult.rejectReason, position);
                        return null;
                    }

                    // collapse selection to active end
                    this.editor.setSelection(Range.fromPositions(this.editor.getSelection().getPosition()));

                    try {
                        final edit:WorkspaceEdit = renameResult;
                        CodeActionUtils.applyWorkspaceEdit(this.editor.context, edit, this.editor);
                    }
                    catch (err:Any) {
                        showMessage(localize('rename.failedApply', "Rename failed to apply edits"), position);
                        Errors.onUnexpectedError(err);
                    }
                    return null;
                }, err -> {
                    showMessage(localize('rename.failed', "Rename failed to compute edits"), position);
                    Errors.onUnexpectedError(err);
                    return null;
                }).finally(() -> {
                    cts2.dispose();
                });
            });
        }, (e:Any) -> {
            cts1.dispose();
            if (!CancellationError.isCancellationError(e)) {
                if (JsValues.isString(e)) {
                    final message:String = e;
                    showMessage(message.length > 0 ? message : localize('resolveRenameLocationFailed', "An unknown error occurred while resolving rename location"), position);
                }
            }
            return Promise.resolve(null);
        });
    }

    /**
     * `raceCancellation`: the value of `promise`, or null when the token is
     * cancelled first.
     */
    static function raceCancellation<T>(promise:Promise<T>, token:CancellationToken):Promise<T> {
        return new Promise<T>((resolve, reject) -> {
            // an already cancelled token calls back on the next run of the
            // loop (Monaco's `shortcutEvent`): a promise settled before wins
            var ref:Null<IDisposable> = null;
            ref = token.onCancellationRequested(() -> {
                ref.dispose();
                resolve(null);
            });
            promise.done(value -> {
                ref.dispose();
                resolve(value);
            }, error -> {
                ref.dispose();
                reject(error);
            });
        });
    }

    public function acceptRenameInput(wantsPreview:Bool):Void {
        this._renameWidget.acceptInput(wantsPreview);
    }

    public function cancelRenameInput():Void {
        this._renameWidget.cancelInput(true, 'cancelRenameInput command');
    }

}

/**
 * `editor.action.rename` (F2): Rename Symbol.
 */
class RenameAction extends EditorAction {

    public static inline final ID = 'editor.action.rename';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('rename.label', "Rename Symbol"),
            alias: 'Rename Symbol',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasRenameProvider),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyCode.F2,
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {
                group: '1_modification',
                order: 1.1
            }
        });
    }

    /**
     * With `[uri, position]`, renames at that position of the editor of
     * that resource (opened with `CodeEditorService.openCodeEditor`).
     */
    override public function runCommand(accessor:Null<Cityscape>, args:Any):Void {
        if (JsValues.isArray(args)) {
            final list:Array<Any> = args;
            final uri:Any = list.length > 0 ? list[0] : null;
            final pos:Any = list.length > 1 ? list[1] : null;
            if (Std.isOfType(uri, Uri) && Position.isIPosition(pos) && accessor != null) {
                final editorService = accessor.codeEditorService;
                editorService.openCodeEditor({resource: (uri : Uri)}, editorService.getActiveCodeEditor(), false, editor -> {
                    if (editor == null) {
                        return;
                    }
                    editor.setPosition(Position.lift(pos));
                    editor.invokeWithinContext(accessor -> {
                        this.run(accessor, editor, null);
                        return null;
                    });
                });
                return;
            }
        }
        super.runCommand(accessor, args);
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = RenameController.get(editor);
        if (controller != null) {
            controller.run();
        }
    }

}

/**
 * The module level code of rename.ts: the contribution, the action and the
 * commands of the rename input.
 *
 * - `acceptRenameInputWithPreview` (Cmd/Ctrl+Enter) is registered with its
 *   precondition `config.editor.rename.enablePreview`, which no context key
 *   sets here (the standalone editor has no preview): it stays unbound
 *   like in Monaco's standalone editor.
 * - Not ported: `focusNextRenameSuggestion` and
 *   `focusPreviousRenameSuggestion` (the new symbol names providers are not
 *   ported), the API commands `_executeDocumentRenameProvider` and
 *   `_executePrepareRename` (they return results; the `rename` function and
 *   `RenameSkeleton` do the same), the `editor.rename.enablePreview` setting.
 */
class RenameRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(RenameController.ID, editor -> new RenameController(editor), EditorContributionInstantiation.Lazy);
        r.registerEditorAction(new RenameAction(r));

        r.registerEditorCommand(new ContributionCommand<RenameController>(RenameController.get, {
            id: 'acceptRenameInput',
            precondition: RenameWidget.CONTEXT_RENAME_INPUT_VISIBLE,
            handler: (x, _) -> x.acceptRenameInput(false),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 99,
                kbExpr: ContextKeyExpr.and(EditorContextKeys.focus, ContextKeyExpr.not('isComposing')),
                primary: KeyCode.Enter
            }
        }));

        r.registerEditorCommand(new ContributionCommand<RenameController>(RenameController.get, {
            id: 'acceptRenameInputWithPreview',
            precondition: ContextKeyExpr.and(RenameWidget.CONTEXT_RENAME_INPUT_VISIBLE, ContextKeyExpr.has('config.editor.rename.enablePreview')),
            handler: (x, _) -> x.acceptRenameInput(true),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 99,
                kbExpr: ContextKeyExpr.and(EditorContextKeys.focus, ContextKeyExpr.not('isComposing')),
                primary: KeyMod.CtrlCmd | KeyCode.Enter
            }
        }));

        r.registerEditorCommand(new ContributionCommand<RenameController>(RenameController.get, {
            id: 'cancelRenameInput',
            precondition: RenameWidget.CONTEXT_RENAME_INPUT_VISIBLE,
            handler: (x, _) -> x.cancelRenameInput(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 99,
                kbExpr: EditorContextKeys.focus,
                primary: KeyCode.Escape,
                secondary: [KeyMod.Shift | KeyCode.Escape]
            }
        }));
    }

    /**
     * The module function `rename`: the edits of renaming the symbol at
     * `position` to `newName` (with the reason when rejected).
     */
    public static function rename(registry:LanguageFeatureRegistry<RenameProvider>, model:ITextModel, position:Position, newName:String):Promise<WorkspaceEditAndRejection> {
        final skeleton = new RenameSkeleton(model, position, registry);
        return skeleton.resolveRenameLocation(CancellationTokens.None).thenPromise(loc -> {
            if (loc != null && JsValues.truthy(loc.rejectReason)) {
                final rejected:WorkspaceEditAndRejection = {edits: [], rejectReason: loc.rejectReason};
                return Promise.resolve(rejected);
            }
            return skeleton.provideRenameEdits(newName, CancellationTokens.None);
        });
    }

}
