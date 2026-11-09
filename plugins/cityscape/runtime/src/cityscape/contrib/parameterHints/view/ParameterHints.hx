// Ported from vscode src/vs/editor/contrib/parameterHints/browser/parameterHints.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.parameterHints.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.SignatureHelpTriggerKind;
import cityscape.contrib.parameterHints.view.ParameterHintsModel;
import cityscape.contrib.parameterHints.view.ProvideSignatureHelp;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.colors.ListColors;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/**
 * The parameter hints of an editor (Monaco's `ParameterHintsController`):
 * the model that asks the signature help providers, and the widget that
 * shows their answer (created when first shown).
 */
class ParameterHintsController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.controller.parameterHints';

    public static function get(editor:ICodeEditor):Null<ParameterHintsController> {
        return editor.getContribution(ParameterHintsController.ID);
    }

    final editor:ICodeEditor;
    final model:ParameterHintsModel;
    /** `Lazy<ParameterHintsWidget>`: null until first shown (`rawValue`). */
    var _widget:Null<ParameterHintsWidget> = null;

    public function new(editor:ICodeEditor) {
        super();

        this.editor = editor;

        this.model = this._register(new ParameterHintsModel(editor, editor.context.languageFeaturesService.signatureHelpProvider));

        this._register(this.model.onChangedHints(newParameterHints -> {
            if (newParameterHints != null) {
                final widget = this.widget();
                widget.show();
                widget.render(newParameterHints);
            }
            else if (this._widget != null) {
                this._widget.hide();
            }
        }));
    }

    /** `this.widget.value` */
    function widget():ParameterHintsWidget {
        if (this._widget == null) {
            this._widget = this._register(new ParameterHintsWidget(this.editor, this.model));
        }
        return this._widget;
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function cancel():Void {
        this.model.cancel();
    }

    public function previous():Void {
        if (this._widget != null) {
            this._widget.previous();
        }
    }

    public function next():Void {
        if (this._widget != null) {
            this._widget.next();
        }
    }

    public function trigger(context:TriggerContext):Void {
        this.model.trigger(context, 0);
    }

    /** The model (tests). */
    public function getModel():ParameterHintsModel {
        return this.model;
    }

    /** The widget, null before it was first shown (tests, visual checks). */
    public function getWidget():Null<ParameterHintsWidget> {
        return this._widget;
    }

}

/**
 * `editor.action.triggerParameterHints` (Cmd+Shift+Space, Ctrl+Shift+Space
 * elsewhere).
 */
class TriggerParameterHintsAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.triggerParameterHints',
            label: r.localize('parameterHints.trigger.label', "Trigger Parameter Hints"),
            alias: 'Trigger Parameter Hints',
            precondition: EditorContextKeys.hasSignatureHelpProvider,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Space,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = ParameterHintsController.get(editor);
        if (controller != null) {
            controller.trigger({
                triggerKind: SignatureHelpTriggerKind.Invoke
            });
        }
    }

}

/**
 * The registration of parameterHints.ts (its module level code) and the
 * color of parameterHintsWidget.ts.
 */
class ParameterHintsRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        ColorUtils.registerColor('editorHoverWidget.highlightForeground', ListColors.listHighlightForeground, r.localize('editorHoverWidgetHighlightForeground', 'Foreground color of the active item in the parameter hint.'));

        r.registerEditorContribution(ParameterHintsController.ID, editor -> new ParameterHintsController(editor), EditorContributionInstantiation.BeforeFirstInteraction);
        r.registerEditorAction(new TriggerParameterHintsAction(r));

        final weight = KeybindingWeight.EditorContrib + 75;

        r.registerEditorCommand(new ContributionCommand<ParameterHintsController>(ParameterHintsController.get, {
            id: 'closeParameterHints',
            precondition: ParameterHintsContext.Visible,
            handler: (x, _) -> x.cancel(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.focus,
                primary: KeyCode.Escape,
                secondary: [KeyMod.Shift | KeyCode.Escape]
            }
        }));

        r.registerEditorCommand(new ContributionCommand<ParameterHintsController>(ParameterHintsController.get, {
            id: 'showPrevParameterHint',
            precondition: ContextKeyExpr.and(ParameterHintsContext.Visible, ParameterHintsContext.MultipleSignatures),
            handler: (x, _) -> x.previous(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.focus,
                primary: KeyCode.UpArrow,
                secondary: [KeyMod.Alt | KeyCode.UpArrow],
                mac: {primary: KeyCode.UpArrow, secondary: [KeyMod.Alt | KeyCode.UpArrow, KeyMod.WinCtrl | KeyCode.KeyP]}
            }
        }));

        r.registerEditorCommand(new ContributionCommand<ParameterHintsController>(ParameterHintsController.get, {
            id: 'showNextParameterHint',
            precondition: ContextKeyExpr.and(ParameterHintsContext.Visible, ParameterHintsContext.MultipleSignatures),
            handler: (x, _) -> x.next(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.focus,
                primary: KeyCode.DownArrow,
                secondary: [KeyMod.Alt | KeyCode.DownArrow],
                mac: {primary: KeyCode.DownArrow, secondary: [KeyMod.Alt | KeyCode.DownArrow, KeyMod.WinCtrl | KeyCode.KeyN]}
            }
        }));
    }

}
