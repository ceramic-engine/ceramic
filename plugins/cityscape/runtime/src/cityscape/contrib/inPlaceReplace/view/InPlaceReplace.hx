// Ported from vscode src/vs/editor/contrib/inPlaceReplace/browser/inPlaceReplace.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inPlaceReplace.view;

import cityscape.Cityscape;
import cityscape.base.common.Async.TimeoutTimer;
import cityscape.base.common.Errors;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.common.EditorCommon;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.IInplaceReplaceSupportResult;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.common.services.EditorSimpleWorker;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * Replace with the previous or next value (inPlaceReplace.ts), registered
 * by `InPlaceReplaceRegistration.register`.
 *
 * Monaco asks the editor worker for the value (`IEditorWorkerService`,
 * a promise) and checks that the editor did not change meanwhile
 * (`EditorState`). Cityscape computes it synchronously
 * (`EditorSimpleWorker.navigateValueSet`), so the state cannot change and
 * the replacement happens before `run` returns. Monaco only navigates
 * models of its model service; Cityscape navigates any model of the editor
 * that is not too large for syncing (Monaco's other condition).
 *
 * The decoration flash (`valueSetReplacement`, inPlaceReplace.css: a 2 px
 * outline in `editorBracketMatch.border`) is a decoration style registered
 * in the context unless the host registered its own; it is removed after
 * 350 ms like Monaco's.
 */

class InPlaceReplaceController implements IEditorContribution {

    public static inline final ID = 'editor.contrib.inPlaceReplaceController';

    public static function get(editor:ICodeEditor):Null<InPlaceReplaceController> {
        return editor.getContribution(InPlaceReplaceController.ID);
    }

    static final DECORATION = ModelDecorationOptions.register({
        description: 'in-place-replace',
        className: 'valueSetReplacement'
    });

    final editor:ICodeEditor;
    final decorations:IEditorDecorationsCollection;
    var decorationRemover:Null<TimeoutTimer> = null;

    public function new(editor:ICodeEditor) {
        this.editor = editor;
        this.decorations = this.editor.createDecorationsCollection();
    }

    public function dispose():Void {
        // Monaco disposes nothing here (its decoration remover runs once
        // more and clears the decorations); the timer is stopped here
        if (this.decorationRemover != null) {
            this.decorationRemover.dispose();
            this.decorationRemover = null;
        }
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * Monaco's `editorWorkerService.canNavigateValueSet(uri)`.
     */
    function canNavigateValueSet():Bool {
        final model = this.editor.getModel();
        return model != null && !model.isTooLargeForSyncing();
    }

    /**
     * Monaco's `editorWorkerService.navigateValueSet(uri, range, up)`.
     */
    function navigateValueSet(range:IRange, up:Bool):Null<IInplaceReplaceSupportResult> {
        final model = this.editor.getModel();
        if (model == null) {
            return null;
        }
        final wordDefRegExp = this.editor.context.languageConfigurationService.getLanguageConfiguration(model.getLanguageId()).getWordDefinition();
        return EditorSimpleWorker.navigateValueSet(model, range, up, wordDefRegExp);
    }

    /**
     * Replaces the value at the selection (Monaco returns a promise; the
     * replacement is done when this returns).
     */
    public function run(source:String, up:Bool):Void {

        final editorSelection = this.editor.getSelection();
        final model = this.editor.getModel();
        if (model == null || editorSelection == null) {
            return;
        }
        var selection = editorSelection;
        if (selection.startLineNumber != selection.endLineNumber) {
            // Can't accept multiline selection
            return;
        }

        if (!this.canNavigateValueSet()) {
            return;
        }

        var result:Null<IInplaceReplaceSupportResult> = null;
        try {
            result = this.navigateValueSet(selection, up);
        }
        catch (e:Dynamic) {
            Errors.onUnexpectedError(e);
            return;
        }

        if (result == null || result.range == null || result.value == null || result.value.length == 0) {
            // No proper result
            return;
        }

        // Selection
        final editRange = Range.lift(result.range);
        var highlightRange = result.range;
        final diff = result.value.length - (selection.endColumn - selection.startColumn);

        // highlight
        highlightRange = {
            startLineNumber: highlightRange.startLineNumber,
            startColumn: highlightRange.startColumn,
            endLineNumber: highlightRange.endLineNumber,
            endColumn: highlightRange.startColumn + result.value.length
        };
        if (diff > 1) {
            selection = new Selection(selection.startLineNumber, selection.startColumn, selection.endLineNumber, selection.endColumn + diff - 1);
        }

        // Insert new text
        final command = new InPlaceReplaceCommand(editRange, selection, result.value);

        this.editor.pushUndoStop();
        this.editor.executeCommand(source, command);
        this.editor.pushUndoStop();

        // add decoration
        this.decorations.set([{
            range: highlightRange,
            options: cast InPlaceReplaceController.DECORATION
        }]);

        // remove decoration after delay
        if (this.decorationRemover != null) {
            this.decorationRemover.dispose();
        }
        this.decorationRemover = new TimeoutTimer(() -> {
            this.decorationRemover = null;
            this.decorations.clear();
        }, 350);
    }

}

class InPlaceReplaceUp extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.inPlaceReplace.up',
            label: r != null ? r.localize('InPlaceReplaceAction.previous.label', "Replace with Previous Value") : "Replace with Previous Value",
            alias: 'Replace with Previous Value',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Comma,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InPlaceReplaceController.get(editor);
        if (controller == null) {
            return;
        }
        controller.run(this.id, false);
    }

}

class InPlaceReplaceDown extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.inPlaceReplace.down',
            label: r != null ? r.localize('InPlaceReplaceAction.next.label', "Replace with Next Value") : "Replace with Next Value",
            alias: 'Replace with Next Value',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Period,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InPlaceReplaceController.get(editor);
        if (controller == null) {
            return;
        }
        controller.run(this.id, true);
    }

}

class InPlaceReplaceRegistration {

    /**
     * The look of the flash (inPlaceReplace.css `.valueSetReplacement`),
     * registered in the context unless the host registered its own.
     */
    static function registerDecorationStyles(context:Cityscape):Void {
        if (context.decorationStyles.get('valueSetReplacement') == null) {
            context.registerDecorationStyle('valueSetReplacement', {
                border: {color: {id: 'editorBracketMatch.border'}, width: 2}
            });
        }
    }

    public static function register(r:EditorExtensionsRegistry):Void {
        registerDecorationStyles(r.context);
        r.registerEditorContribution(InPlaceReplaceController.ID, editor -> new InPlaceReplaceController(editor), EditorContributionInstantiation.Lazy);
        r.registerEditorAction(new InPlaceReplaceUp(r));
        r.registerEditorAction(new InPlaceReplaceDown(r));
    }

}
