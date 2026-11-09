// Ported from vscode src/vs/editor/contrib/codeAction/browser/codeActionController.ts,
// codeActionCommands.ts and codeActionContributions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codeAction.view;

import cityscape.Cityscape;
import cityscape.base.common.Errors;
import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages;
import cityscape.common.Model.IModelDeltaDecoration;
import cityscape.common.core.Position;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.contrib.codeAction.view.CodeAction;
import cityscape.contrib.codeAction.view.CodeActionMenu;
import cityscape.contrib.codeAction.view.CodeActionModel;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;
import cityscape.view.EditorWidgets;
import glaze.Bounds;
import glaze.Point;
import glaze.Size;

typedef IActionShowOptions = {
    final includeDisabledActions:Bool;
    final fromLightbulb:Bool;
}

/**
 * The code actions of an editor (Monaco's `CodeActionController`): the
 * lightbulb, the quick fix menu (the kit's `PopupMenu`, Monaco's action
 * widget), applying an action.
 *
 * Not ported: the message shown when no action is available (Monaco's
 * `MessageController`: `onNoResult` of the context is called with it instead), the
 * preview of refactorings, the action bar of the menu (documentation
 * commands, show disabled), the AI lightbulb.
 */
class CodeActionController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.codeActionController';

    public static function get(editor:ICodeEditor):Null<CodeActionController> {
        return editor.getContribution(CodeActionController.ID);
    }

    static var _decoration:Null<ModelDecorationOptions> = null;

    static function decoration():ModelDecorationOptions {
        if (_decoration == null) {
            _decoration = ModelDecorationOptions.register({
                description: 'quickfix-highlight',
                className: 'quickfix-edit-highlight'
            });
        }
        return _decoration;
    }

    final _editor:ICodeEditor;
    final _model:CodeActionModel;
    var _lightBulbWidget:Null<LightBulbWidget> = null;
    var _lightBulbResolved = false;
    final _activeCodeActions = new MutableDisposable<CodeActionSet>();
    var _showDisabled = false;
    final _resolver:CodeActionKeybindingResolver;
    var _disposed = false;
    var _actionWidget:Null<CodeActionWidget> = null;

    public function new(editor:ICodeEditor) {
        super();

        this._editor = editor;
        final context = editor.context;
        this._model = this._register(new CodeActionModel(this._editor, context.languageFeaturesService.codeActionProvider, context.markerService, editor.contextKeyService));
        this._register(this._model.onDidChangeState(newState -> this.update(newState)));
        this._register(_activeCodeActions);

        this._resolver = new CodeActionKeybindingResolver(() -> context.keybindingService.getKeybindings());

        this._register(this._editor.onDidLayoutChange(_ -> this.hideCodeActions()));
    }

    function lightBulbWidget():Null<LightBulbWidget> {
        if (!_lightBulbResolved) {
            _lightBulbResolved = true;
            final widget = LightBulbWidget.get(this._editor);
            _lightBulbWidget = widget;
            if (widget != null) {
                this._register(widget.onClick(e -> this.showCodeActionsFromLightbulb(e.actions, new Bounds(new Point(e.x, e.y), new Size(1, 1)))));
            }
        }
        return _lightBulbWidget;
    }

    function actionWidget():CodeActionWidget {
        if (_actionWidget == null) {
            _actionWidget = this._register(new CodeActionWidget(this._editor));
        }
        return _actionWidget;
    }

    /**
     * The menu of the code actions (tests read its items).
     */
    public function getActionWidget():CodeActionWidget {
        return actionWidget();
    }

    /**
     * The model (tests run its pending trigger).
     * @internal
     */
    public function _getModel():CodeActionModel {
        return _model;
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    override public function dispose():Void {
        this._disposed = true;
        super.dispose();
    }

    function showCodeActionsFromLightbulb(actions:CodeActionSet, at:Bounds):Void {
        this.showCodeActionList(actions, at, {includeDisabledActions: false, fromLightbulb: true});
    }

    public function showCodeActions(trigger:CodeActionTrigger, actions:CodeActionSet, at:Bounds):Void {
        this.showCodeActionList(actions, at, {includeDisabledActions: false, fromLightbulb: false});
    }

    public function hideCodeActions():Void {
        if (_actionWidget != null) {
            _actionWidget.hide();
        }
    }

    public function manualTriggerAtCurrentPosition(notAvailableMessage:String, triggerAction:CodeActionTriggerSource, ?filter:CodeActionFilter, ?autoApply:CodeActionAutoApply):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        final triggerPosition = this._editor.getPosition();
        this._trigger({type: CodeActionTriggerType.Invoke, triggerAction: triggerAction, filter: filter, autoApply: autoApply, context: {notAvailableMessage: notAvailableMessage, position: triggerPosition}});
    }

    function _trigger(trigger:CodeActionTrigger):Void {
        this._model.trigger(trigger);
    }

    function _applyCodeAction(action:CodeActionItem, retrigger:Bool, preview:Bool, actionReason:ApplyCodeActionReason):Void {
        CodeActionUtils.applyCodeAction(this._editor.context, action, actionReason, this._editor, null, _ -> {
            if (retrigger) {
                this._trigger({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.QuickFix, filter: {}});
            }
        });
    }

    public function hideLightBulbWidget():Void {
        if (_lightBulbWidget != null) {
            _lightBulbWidget.hide();
        }
    }

    function update(newState:CodeActionsState):Void {
        if (newState.type != CodeActionsStateType.Triggered) {
            this.hideLightBulbWidget();
            return;
        }

        newState.actions.done(actions -> {
            if (this._disposed) {
                return;
            }

            final selection = this._editor.getSelection();
            if (selection == null || selection.startLineNumber != newState.position.lineNumber) {
                return;
            }

            final widget = this.lightBulbWidget();
            if (widget != null) {
                widget.update(actions, newState.trigger, newState.position);
            }

            final trigger = newState.trigger;
            if (trigger.type == CodeActionTriggerType.Invoke) {
                if (trigger.filter != null && trigger.filter.include != null) { // Triggered for specific scope

                    final validActionToApply = this.tryGetValidActionToApply(trigger, actions);
                    if (validActionToApply != null) {
                        this.hideLightBulbWidget();
                        this._applyCodeAction(validActionToApply, false, false, ApplyCodeActionReason.FromCodeActions);
                        actions.dispose();
                        return;
                    }

                    if (trigger.context != null) {
                        final invalidAction = this.getInvalidActionThatWouldHaveBeenApplied(trigger, actions);
                        if (invalidAction != null && invalidAction.action.disabled != null) {
                            notAvailable(invalidAction.action.disabled, trigger.context.position);
                            actions.dispose();
                            return;
                        }
                    }
                }

                final includeDisabledActions = trigger.filter != null && trigger.filter.include != null;
                if (trigger.context != null) {
                    if (actions.allActions.length == 0 || !includeDisabledActions && actions.validActions.length == 0) {
                        notAvailable(trigger.context.notAvailableMessage, trigger.context.position);
                        this._activeCodeActions.value = actions;
                        actions.dispose();
                        return;
                    }
                }

                this._activeCodeActions.value = actions;
                this.showCodeActionList(actions, this.toCoords(newState.position), {includeDisabledActions: includeDisabledActions, fromLightbulb: false});
            }
            else {
                if (_actionWidget != null && _actionWidget.isVisible) {
                    actions.dispose();
                }
                else {
                    this._activeCodeActions.value = actions;
                }
            }
        }, e -> Errors.onUnexpectedError(e));
    }

    function notAvailable(message:String, position:IPosition):Void {
        final f = this._editor.context.onNoResult;
        if (f != null) {
            f(this._editor, message, Position.lift(position));
        }
    }

    function getInvalidActionThatWouldHaveBeenApplied(trigger:CodeActionTrigger, actions:CodeActionSet):Null<CodeActionItem> {
        if (actions.allActions.length == 0) {
            return null;
        }

        if ((trigger.autoApply == CodeActionAutoApply.First && actions.validActions.length == 0)
            || (trigger.autoApply == CodeActionAutoApply.IfSingle && actions.allActions.length == 1)
        ) {
            for (item in actions.allActions) {
                if (item.action.disabled != null && item.action.disabled.length > 0) {
                    return item;
                }
            }
        }

        return null;
    }

    function tryGetValidActionToApply(trigger:CodeActionTrigger, actions:CodeActionSet):Null<CodeActionItem> {
        if (actions.validActions.length == 0) {
            return null;
        }

        if ((trigger.autoApply == CodeActionAutoApply.First && actions.validActions.length > 0)
            || (trigger.autoApply == CodeActionAutoApply.IfSingle && actions.validActions.length == 1)
        ) {
            return actions.validActions[0];
        }

        return null;
    }

    public function showCodeActionList(actions:CodeActionSet, at:Null<Bounds>, options:IActionShowOptions):Void {

        final currentDecorations = this._editor.createDecorationsCollection();

        final actionsToShow = options.includeDisabledActions && (this._showDisabled || actions.validActions.length == 0) ? actions.allActions : actions.validActions;
        if (actionsToShow.length == 0) {
            return;
        }

        final delegate:ActionListDelegate = {
            onSelect: (action:CodeActionItem, preview:Bool) -> {
                this._applyCodeAction(action, /* retrigger */ true, preview, options.fromLightbulb ? ApplyCodeActionReason.FromAILightbulb : ApplyCodeActionReason.FromCodeActions);
                actionWidget().hide(false);
                currentDecorations.clear();
            },
            onHide: (didCancel:Bool) -> {
                this._editor.focus();
                currentDecorations.clear();
            },
            onFocus: (action:Null<CodeActionItem>) -> {
                if (action != null && action.action != null) {
                    final ranges = action.action.ranges;
                    final diagnostics = action.action.diagnostics;
                    currentDecorations.clear();
                    if (ranges != null && ranges.length > 0) {
                        final decorations:Array<IModelDeltaDecoration> = (diagnostics != null && diagnostics.length > 1)
                            ? [for (diagnostic in diagnostics) {range: cast diagnostic, options: cast decoration()}]
                            : [for (range in ranges) {range: range, options: cast decoration()}];
                        currentDecorations.set(decorations);
                    }
                    else if (diagnostics != null && diagnostics.length > 0) {
                        currentDecorations.set([for (diagnostic in diagnostics) ({range: cast diagnostic, options: cast decoration()} : IModelDeltaDecoration)]);
                    }
                }
                else {
                    currentDecorations.clear();
                }
            }
        };

        final context = this._editor.context;
        actionWidget().show(
            CodeActionMenu.toMenuItems(actionsToShow, true, this._resolver.getResolver(), (key, message) -> context.nls.localize(key, message)),
            delegate,
            at
        );
    }

    function toCoords(position:IPosition):Null<Bounds> {
        if (!this._editor.hasModel()) {
            return null;
        }

        this._editor.revealPosition(position, ScrollType.Immediate);
        this._editor.render();

        return EditorWidgets.positionBounds(this._editor, Position.lift(position));
    }

}

private class CodeActionHelpers {

    public static function triggerCodeActionsForEditorSelection(editor:ICodeEditor, notAvailableMessage:String, filter:Null<CodeActionFilter>, autoApply:Null<CodeActionAutoApply>, triggerAction:CodeActionTriggerSource = CodeActionTriggerSource.Default):Void {
        if (editor.hasModel()) {
            final controller = CodeActionController.get(editor);
            if (controller != null) {
                controller.manualTriggerAtCurrentPosition(notAvailableMessage, triggerAction, filter, autoApply);
            }
        }
    }

}

class QuickFixAction extends EditorAction {

    final r:EditorExtensionsRegistry;

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: CodeActionCommandIds.quickFixCommandId,
            label: r.localize('quickfix.trigger.label', "Quick Fix..."),
            alias: 'Quick Fix...',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCodeActionsProvider),
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.CtrlCmd | KeyCode.Period,
                weight: KeybindingWeight.EditorContrib
            }
        });
        this.r = r;
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        CodeActionHelpers.triggerCodeActionsForEditorSelection(editor, r.localize('editor.action.quickFix.noneMessage', "No code actions available"), null, null, CodeActionTriggerSource.QuickFix);
    }
}

class CodeActionCommand extends EditorCommand {

    final r:EditorExtensionsRegistry;

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: CodeActionCommandIds.codeActionCommandId,
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCodeActionsProvider),
        });
        this.r = r;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, userArgs:Any):Void {
        final args = CodeActionCommandArgs.fromUser(userArgs, {
            kind: HierarchicalKind.Empty,
            apply: CodeActionAutoApply.IfSingle,
        });
        final kind:Any = userArgs != null && JsValues.isObject(userArgs) ? JsValues.field(userArgs, 'kind') : null;
        final message = JsValues.isString(kind)
            ? (args.preferred
                ? r.localize('editor.action.codeAction.noneMessage.preferred.kind', "No preferred code actions for '{0}' available", [kind])
                : r.localize('editor.action.codeAction.noneMessage.kind', "No code actions for '{0}' available", [kind]))
            : (args.preferred
                ? r.localize('editor.action.codeAction.noneMessage.preferred', "No preferred code actions available")
                : r.localize('editor.action.codeAction.noneMessage', "No code actions available"));
        CodeActionHelpers.triggerCodeActionsForEditorSelection(editor, message, {
            include: args.kind,
            includeSourceActions: true,
            onlyIncludePreferredActions: args.preferred,
        }, args.apply);
    }
}

/**
 * The registration of codeActionContributions.ts (its module level code):
 * the controller, the lightbulb, the quick fix action and the code action
 * command. The refactor, source, organize imports, auto fix and fix all
 * actions are not ported yet.
 * TODO(step 7): the other code action commands.
 */
class CodeActionRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        if (r.context.decorationStyles.get('quickfix-edit-highlight') == null) {
            // codeActionController.ts theme participant
            r.context.registerDecorationStyle('quickfix-edit-highlight', {
                background: {id: 'editor.findMatchHighlightBackground'},
                border: {color: {id: 'editor.findMatchHighlightBorder'}}
            });
        }
        r.registerEditorContribution(CodeActionController.ID, editor -> new CodeActionController(editor), EditorContributionInstantiation.Eventually);
        r.registerEditorContribution(LightBulbWidget.ID, editor -> new LightBulbWidget(editor), EditorContributionInstantiation.Lazy);
        r.registerEditorAction(new QuickFixAction(r));
        r.registerEditorCommand(new CodeActionCommand(r));
    }

}
