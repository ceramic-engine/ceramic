// Ported from vscode src/vs/editor/contrib/wordOperations/browser/wordOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.wordOperations.view;

import cityscape.Cityscape;
import cityscape.common.CursorCommon;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Model.ITextModel;
import cityscape.common.commands.ReplaceCommand;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.WordCharacterClassifier;
import cityscape.common.cursor.CursorWordOperations;
import cityscape.common.model.TextModel;
import cityscape.view.CoreCommands;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.common.EditorContextKeys;
import cityscape.platform.accessibility.common.Accessibility.AccessibilityContextKeys;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.contextkey.common.ContextKeys;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorExtensions;

/*
 * The word commands of the editor: move by word, select by word, delete by
 * word (wordOperations.ts).
 *
 * The commands, their keybindings and their registration in a context
 * (`WordOperationsRegistration.register`).
 */

abstract class MoveWordCommand extends EditorCommand {

    final _inSelectionMode:Bool;
    final _wordNavigationType:WordNavigationType;

    public function new(opts:ICommandOptions, inSelectionMode:Bool, wordNavigationType:WordNavigationType) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
        this._wordNavigationType = wordNavigationType;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getTextModel();
        if (model == null) {
            return;
        }
        final wordSeparators = WordCharacterClassifier.getMapForWordSeparators(editor.getOption(EditorOption.wordSeparators), editor.getOption(EditorOption.wordSegmenterLocales));
        final selections = editor.getSelections();
        final hasMulticursor = selections.length > 1;
        final result = [for (sel in selections) {
            final inPosition = new Position(sel.positionLineNumber, sel.positionColumn);
            final outPosition = this._move(wordSeparators, model, inPosition, this._wordNavigationType, hasMulticursor);
            this._moveTo(sel, outPosition, this._inSelectionMode);
        }];

        model.pushStackElement();
        editor._getViewModel().setCursorStates('moveWordCommand', CursorChangeReason.Explicit, CursorState.fromSelections(result));
        if (result.length == 1) {
            final pos = new Position(result[0].positionLineNumber, result[0].positionColumn);
            editor.revealPosition(pos, ScrollType.Smooth);
        }
    }

    function _moveTo(from:Selection, to:Position, inSelectionMode:Bool):Selection {
        if (inSelectionMode) {
            // move just position
            return new Selection(
                from.selectionStartLineNumber,
                from.selectionStartColumn,
                to.lineNumber,
                to.column
            );
        }
        else {
            // move everything
            return new Selection(
                to.lineNumber,
                to.column,
                to.lineNumber,
                to.column
            );
        }
    }

    abstract function _move(wordSeparators:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position;

}

class WordLeftCommand extends MoveWordCommand {

    function _move(wordSeparators:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return WordOperations.moveWordLeft(wordSeparators, model, position, wordNavigationType, hasMulticursor);
    }

}

class WordRightCommand extends MoveWordCommand {

    function _move(wordSeparators:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return WordOperations.moveWordRight(wordSeparators, model, position, wordNavigationType);
    }

}

class CursorWordStartLeft extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordStartLeft', precondition: null}, false, WordNavigationType.WordStart);
    }
}

class CursorWordEndLeft extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordEndLeft', precondition: null}, false, WordNavigationType.WordEnd);
    }
}

class CursorWordLeft extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordLeft', precondition: null, kbOpts: {kbExpr: ContextKeyExpr.and(EditorContextKeys.textInputFocus, WordOperationsUtils.notAccessibilityModeOnWindows()), primary: KeyMod.CtrlCmd | KeyCode.LeftArrow, mac: {primary: KeyMod.Alt | KeyCode.LeftArrow}, weight: KeybindingWeight.EditorContrib}}, false, WordNavigationType.WordStartFast);
    }
}

class CursorWordStartLeftSelect extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordStartLeftSelect', precondition: null}, true, WordNavigationType.WordStart);
    }
}

class CursorWordEndLeftSelect extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordEndLeftSelect', precondition: null}, true, WordNavigationType.WordEnd);
    }
}

class CursorWordLeftSelect extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordLeftSelect', precondition: null, kbOpts: {kbExpr: ContextKeyExpr.and(EditorContextKeys.textInputFocus, WordOperationsUtils.notAccessibilityModeOnWindows()), primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.LeftArrow, mac: {primary: KeyMod.Alt | KeyMod.Shift | KeyCode.LeftArrow}, weight: KeybindingWeight.EditorContrib}}, true, WordNavigationType.WordStartFast);
    }
}

// Accessibility navigation commands should only be enabled on windows since they are tuned to what NVDA expects
class CursorWordAccessibilityLeft extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordAccessibilityLeft', precondition: null}, false, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

class CursorWordAccessibilityLeftSelect extends WordLeftCommand {
    public function new() {
        super({id: 'cursorWordAccessibilityLeftSelect', precondition: null}, true, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

class CursorWordStartRight extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordStartRight', precondition: null}, false, WordNavigationType.WordStart);
    }
}

class CursorWordEndRight extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordEndRight', precondition: null, kbOpts: {kbExpr: ContextKeyExpr.and(EditorContextKeys.textInputFocus, WordOperationsUtils.notAccessibilityModeOnWindows()), primary: KeyMod.CtrlCmd | KeyCode.RightArrow, mac: {primary: KeyMod.Alt | KeyCode.RightArrow}, weight: KeybindingWeight.EditorContrib}}, false, WordNavigationType.WordEnd);
    }
}

class CursorWordRight extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordRight', precondition: null}, false, WordNavigationType.WordEnd);
    }
}

class CursorWordStartRightSelect extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordStartRightSelect', precondition: null}, true, WordNavigationType.WordStart);
    }
}

class CursorWordEndRightSelect extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordEndRightSelect', precondition: null, kbOpts: {kbExpr: ContextKeyExpr.and(EditorContextKeys.textInputFocus, WordOperationsUtils.notAccessibilityModeOnWindows()), primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.RightArrow, mac: {primary: KeyMod.Alt | KeyMod.Shift | KeyCode.RightArrow}, weight: KeybindingWeight.EditorContrib}}, true, WordNavigationType.WordEnd);
    }
}

class CursorWordRightSelect extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordRightSelect', precondition: null}, true, WordNavigationType.WordEnd);
    }
}

class CursorWordAccessibilityRight extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordAccessibilityRight', precondition: null}, false, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

class CursorWordAccessibilityRightSelect extends WordRightCommand {
    public function new() {
        super({id: 'cursorWordAccessibilityRightSelect', precondition: null}, true, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

abstract class DeleteWordCommand extends EditorCommand {

    final _whitespaceHeuristics:Bool;
    final _wordNavigationType:WordNavigationType;

    public function new(opts:ICommandOptions, whitespaceHeuristics:Bool, wordNavigationType:WordNavigationType) {
        super(opts);
        this._whitespaceHeuristics = whitespaceHeuristics;
        this._wordNavigationType = wordNavigationType;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getTextModel();
        if (model == null) {
            return;
        }
        final languageConfigurationService = WordOperationsUtils.contextOf(accessor, model).languageConfigurationService;
        final wordSeparators = WordCharacterClassifier.getMapForWordSeparators(editor.getOption(EditorOption.wordSeparators), editor.getOption(EditorOption.wordSegmenterLocales));
        final selections = editor.getSelections();
        final autoClosingBrackets = editor.getOption(EditorOption.autoClosingBrackets);
        final autoClosingQuotes = editor.getOption(EditorOption.autoClosingQuotes);
        final autoClosingPairs = languageConfigurationService.getLanguageConfiguration(model.getLanguageId()).getAutoClosingPairs();
        final viewModel = editor._getViewModel();
        final commands:Array<Null<ICommand>> = [for (sel in selections) {
            final deleteRange = this._delete({
                wordSeparators: wordSeparators,
                model: model,
                selection: sel,
                whitespaceHeuristics: this._whitespaceHeuristics,
                autoClosingDelete: editor.getOption(EditorOption.autoClosingDelete),
                autoClosingBrackets: autoClosingBrackets,
                autoClosingQuotes: autoClosingQuotes,
                autoClosingPairs: autoClosingPairs,
                autoClosedCharacters: viewModel.getCursorAutoClosedCharacters(),
            }, this._wordNavigationType);
            new ReplaceCommand(deleteRange, '');
        }];

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

    abstract function _delete(ctx:DeleteWordContext, wordNavigationType:WordNavigationType):Range;

}

class DeleteWordLeftCommand extends DeleteWordCommand {

    function _delete(ctx:DeleteWordContext, wordNavigationType:WordNavigationType):Range {
        final r = WordOperations.deleteWordLeft(ctx, wordNavigationType);
        if (r != null) {
            return r;
        }
        return new Range(1, 1, 1, 1);
    }

}

class DeleteWordRightCommand extends DeleteWordCommand {

    function _delete(ctx:DeleteWordContext, wordNavigationType:WordNavigationType):Range {
        final r = WordOperations.deleteWordRight(ctx, wordNavigationType);
        if (r != null) {
            return r;
        }
        final lineCount = ctx.model.getLineCount();
        final maxColumn = ctx.model.getLineMaxColumn(lineCount);
        return new Range(lineCount, maxColumn, lineCount, maxColumn);
    }

}

class DeleteWordStartLeft extends DeleteWordLeftCommand {
    public function new() {
        super({id: 'deleteWordStartLeft', precondition: EditorContextKeys.writable}, false, WordNavigationType.WordStart);
    }
}

class DeleteWordEndLeft extends DeleteWordLeftCommand {
    public function new() {
        super({id: 'deleteWordEndLeft', precondition: EditorContextKeys.writable}, false, WordNavigationType.WordEnd);
    }
}

class DeleteWordLeft extends DeleteWordLeftCommand {
    public function new() {
        super({id: 'deleteWordLeft', precondition: EditorContextKeys.writable, kbOpts: {kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.Backspace, mac: {primary: KeyMod.Alt | KeyCode.Backspace}, weight: KeybindingWeight.EditorContrib}}, true, WordNavigationType.WordStart);
    }
}

class DeleteWordStartRight extends DeleteWordRightCommand {
    public function new() {
        super({id: 'deleteWordStartRight', precondition: EditorContextKeys.writable}, false, WordNavigationType.WordStart);
    }
}

class DeleteWordEndRight extends DeleteWordRightCommand {
    public function new() {
        super({id: 'deleteWordEndRight', precondition: EditorContextKeys.writable}, false, WordNavigationType.WordEnd);
    }
}

class DeleteWordRight extends DeleteWordRightCommand {
    public function new() {
        super({id: 'deleteWordRight', precondition: EditorContextKeys.writable, kbOpts: {kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.Delete, mac: {primary: KeyMod.Alt | KeyCode.Delete}, weight: KeybindingWeight.EditorContrib}}, true, WordNavigationType.WordEnd);
    }
}

class DeleteInsideWord extends EditorAction {

    /**
     * `r` localizes the label (English without it).
     */
    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'deleteInsideWord',
            precondition: EditorContextKeys.writable,
            label: r != null ? r.localize('deleteInsideWord', "Delete Word") : "Delete Word",
            alias: 'Delete Word'
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getTextModel();
        if (model == null) {
            return;
        }
        final wordSeparators = WordCharacterClassifier.getMapForWordSeparators(editor.getOption(EditorOption.wordSeparators), editor.getOption(EditorOption.wordSegmenterLocales));
        final selections = editor.getSelections();
        final commands:Array<Null<ICommand>> = [for (sel in selections) {
            final deleteRange = WordOperations.deleteInsideWord(wordSeparators, model, sel);
            new ReplaceCommand(deleteRange, '');
        }];

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

/**
 * The module level registrations of wordOperations.ts, for one context.
 */
class WordOperationsRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorCommand(new CursorWordStartLeft());
        r.registerEditorCommand(new CursorWordEndLeft());
        r.registerEditorCommand(new CursorWordLeft());
        r.registerEditorCommand(new CursorWordStartLeftSelect());
        r.registerEditorCommand(new CursorWordEndLeftSelect());
        r.registerEditorCommand(new CursorWordLeftSelect());
        r.registerEditorCommand(new CursorWordStartRight());
        r.registerEditorCommand(new CursorWordEndRight());
        r.registerEditorCommand(new CursorWordRight());
        r.registerEditorCommand(new CursorWordStartRightSelect());
        r.registerEditorCommand(new CursorWordEndRightSelect());
        r.registerEditorCommand(new CursorWordRightSelect());
        r.registerEditorCommand(new CursorWordAccessibilityLeft());
        r.registerEditorCommand(new CursorWordAccessibilityLeftSelect());
        r.registerEditorCommand(new CursorWordAccessibilityRight());
        r.registerEditorCommand(new CursorWordAccessibilityRightSelect());
        r.registerEditorCommand(new DeleteWordStartLeft());
        r.registerEditorCommand(new DeleteWordEndLeft());
        r.registerEditorCommand(new DeleteWordLeft());
        r.registerEditorCommand(new DeleteWordStartRight());
        r.registerEditorCommand(new DeleteWordEndRight());
        r.registerEditorCommand(new DeleteWordRight());
        r.registerEditorAction(new DeleteInsideWord(r));
    }

}

private class WordOperationsUtils {

    /**
     * `ContextKeyExpr.and(CONTEXT_ACCESSIBILITY_MODE_ENABLED, IsWindowsContext)?.negate()`
     */
    public static function notAccessibilityModeOnWindows():Null<ContextKeyExpression> {
        final e = ContextKeyExpr.and(AccessibilityContextKeys.CONTEXT_ACCESSIBILITY_MODE_ENABLED, ContextKeys.IsWindowsContext);
        return e != null ? e.negate() : null;
    }

    /**
     * The services: Monaco's accessor, or else the context of the model.
     */
    public static function contextOf(accessor:Null<Cityscape>, model:ITextModel):Cityscape {
        if (accessor != null) {
            return accessor;
        }
        final textModel = Std.downcast(model, TextModel);
        return textModel != null ? textModel.context : Cityscape.defaultContext;
    }

}
