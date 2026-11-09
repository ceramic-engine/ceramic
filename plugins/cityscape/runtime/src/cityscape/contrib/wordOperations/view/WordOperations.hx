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

/*
 * The word commands of the editor: move by word, select by word, delete by
 * word (wordOperations.ts).
 *
 * Ported: the commands and what they do. Not ported yet (TODO(step 3,
 * keybindings)): their registration (`registerEditorCommand`,
 * `registerEditorAction`, `kbOpts`, `precondition`) and the localized label
 * of `DeleteInsideWord` (its English label is kept).
 */

abstract class MoveWordCommand extends EditorCommand {

    final _inSelectionMode:Bool;
    final _wordNavigationType:WordNavigationType;

    public function new(id:String, inSelectionMode:Bool, wordNavigationType:WordNavigationType) {
        super(id);
        this._inSelectionMode = inSelectionMode;
        this._wordNavigationType = wordNavigationType;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Null<CoreCommandArgs>):Void {
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
        super('cursorWordStartLeft', false, WordNavigationType.WordStart);
    }
}

class CursorWordEndLeft extends WordLeftCommand {
    public function new() {
        super('cursorWordEndLeft', false, WordNavigationType.WordEnd);
    }
}

class CursorWordLeft extends WordLeftCommand {
    public function new() {
        super('cursorWordLeft', false, WordNavigationType.WordStartFast);
    }
}

class CursorWordStartLeftSelect extends WordLeftCommand {
    public function new() {
        super('cursorWordStartLeftSelect', true, WordNavigationType.WordStart);
    }
}

class CursorWordEndLeftSelect extends WordLeftCommand {
    public function new() {
        super('cursorWordEndLeftSelect', true, WordNavigationType.WordEnd);
    }
}

class CursorWordLeftSelect extends WordLeftCommand {
    public function new() {
        super('cursorWordLeftSelect', true, WordNavigationType.WordStartFast);
    }
}

// Accessibility navigation commands should only be enabled on windows since they are tuned to what NVDA expects
class CursorWordAccessibilityLeft extends WordLeftCommand {
    public function new() {
        super('cursorWordAccessibilityLeft', false, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

class CursorWordAccessibilityLeftSelect extends WordLeftCommand {
    public function new() {
        super('cursorWordAccessibilityLeftSelect', true, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

class CursorWordStartRight extends WordRightCommand {
    public function new() {
        super('cursorWordStartRight', false, WordNavigationType.WordStart);
    }
}

class CursorWordEndRight extends WordRightCommand {
    public function new() {
        super('cursorWordEndRight', false, WordNavigationType.WordEnd);
    }
}

class CursorWordRight extends WordRightCommand {
    public function new() {
        super('cursorWordRight', false, WordNavigationType.WordEnd);
    }
}

class CursorWordStartRightSelect extends WordRightCommand {
    public function new() {
        super('cursorWordStartRightSelect', true, WordNavigationType.WordStart);
    }
}

class CursorWordEndRightSelect extends WordRightCommand {
    public function new() {
        super('cursorWordEndRightSelect', true, WordNavigationType.WordEnd);
    }
}

class CursorWordRightSelect extends WordRightCommand {
    public function new() {
        super('cursorWordRightSelect', true, WordNavigationType.WordEnd);
    }
}

class CursorWordAccessibilityRight extends WordRightCommand {
    public function new() {
        super('cursorWordAccessibilityRight', false, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

class CursorWordAccessibilityRightSelect extends WordRightCommand {
    public function new() {
        super('cursorWordAccessibilityRightSelect', true, WordNavigationType.WordAccessibility);
    }

    override function _move(wordCharacterClassifier:WordCharacterClassifier, model:ITextModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        return super._move(WordCharacterClassifier.getMapForWordSeparators(EditorOptions.wordSeparators.defaultValue, wordCharacterClassifier.intlSegmenterLocales), model, position, wordNavigationType, hasMulticursor);
    }
}

abstract class DeleteWordCommand extends EditorCommand {

    final _whitespaceHeuristics:Bool;
    final _wordNavigationType:WordNavigationType;

    public function new(id:String, whitespaceHeuristics:Bool, wordNavigationType:WordNavigationType) {
        super(id);
        this._whitespaceHeuristics = whitespaceHeuristics;
        this._wordNavigationType = wordNavigationType;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Null<CoreCommandArgs>):Void {
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
        super('deleteWordStartLeft', false, WordNavigationType.WordStart);
    }
}

class DeleteWordEndLeft extends DeleteWordLeftCommand {
    public function new() {
        super('deleteWordEndLeft', false, WordNavigationType.WordEnd);
    }
}

class DeleteWordLeft extends DeleteWordLeftCommand {
    public function new() {
        super('deleteWordLeft', true, WordNavigationType.WordStart);
    }
}

class DeleteWordStartRight extends DeleteWordRightCommand {
    public function new() {
        super('deleteWordStartRight', false, WordNavigationType.WordStart);
    }
}

class DeleteWordEndRight extends DeleteWordRightCommand {
    public function new() {
        super('deleteWordEndRight', false, WordNavigationType.WordEnd);
    }
}

class DeleteWordRight extends DeleteWordRightCommand {
    public function new() {
        super('deleteWordRight', true, WordNavigationType.WordEnd);
    }
}

/**
 * Monaco's `DeleteInsideWord` editor action (`EditorAction.run`).
 */
class DeleteInsideWord {

    public final id = 'deleteInsideWord';
    public final label = 'Delete Word';
    public final alias = 'Delete Word';

    public function new() {}

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

private class WordOperationsUtils {

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
