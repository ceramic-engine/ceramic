// Ported from vscode src/vs/editor/common/cursorCommon.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.EditorCommon.ICommand;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.Model.TextModelResolvedOptions;
import cityscape.common.config.EditorConfiguration.IEditorConfiguration;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions.EditorLayoutInfo;
import cityscape.common.config.FontInfo;
import cityscape.common.core.CursorColumns;
import cityscape.common.core.Indentation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfiguration.AutoClosingPairs;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.languages.Supports;
import cityscape.common.languages.supports.ElectricCharacter.IElectricAction;
import cityscape.common.tokens.LineTokens;

typedef IColumnSelectData = {
    var isReal:Bool;
    var fromViewLineNumber:Int;
    var fromViewVisualColumn:Int;
    var toViewLineNumber:Int;
    var toViewVisualColumn:Int;
}

/**
 * This is an operation type that will be recorded for undo/redo purposes.
 * The goal is to introduce an undo stop when the controller switches between different operation types.
 */
enum abstract EditOperationType(Int) from Int to Int {
    var Other = 0;
    var DeletingLeft = 2;
    var DeletingRight = 3;
    var TypingOther = 4;
    var TypingFirstSpace = 5;
    var TypingConsecutiveSpace = 6;
}

/**
 * Monaco's `CharacterMap` (`{ [char: string]: string }`).
 */
typedef CharacterMap = Map<String, String>;

/**
 * The `shouldAutoCloseBefore` functions of a `CursorConfiguration`.
 */
class ShouldAutoCloseBefore {

    public final quote:(ch:String) -> Bool;
    public final bracket:(ch:String) -> Bool;
    public final comment:(ch:String) -> Bool;

    public function new(quote:(ch:String) -> Bool, bracket:(ch:String) -> Bool, comment:(ch:String) -> Bool) {
        this.quote = quote;
        this.bracket = bracket;
        this.comment = comment;
    }

}

/**
 * The configuration of the cursors of an editor (options of the editor and
 * of the model, and the language configuration of the model's language).
 *
 * Monaco's `CursorConfiguration` takes the `ILanguageConfigurationService`;
 * here it is the one of the editor's `Cityscape` context.
 */
class CursorConfiguration {

    public final readOnly:Bool;
    public final tabSize:Int;
    public final indentSize:Int;
    public final insertSpaces:Bool;
    public final stickyTabStops:Bool;
    public final pageSize:Int;
    public final lineHeight:Float;
    public final typicalHalfwidthCharacterWidth:Float;
    public final useTabStops:Bool;
    public final wordSeparators:String;
    public final emptySelectionClipboard:Bool;
    public final copyWithSyntaxHighlighting:Bool;
    public final multiCursorMergeOverlapping:Bool;
    /**
     * `'spread'` or `'full'`.
     */
    public final multiCursorPaste:String;
    public final multiCursorLimit:Int;
    public final autoClosingBrackets:EditorAutoClosingStrategy;
    public final autoClosingComments:EditorAutoClosingStrategy;
    public final autoClosingQuotes:EditorAutoClosingStrategy;
    public final autoClosingDelete:EditorAutoClosingEditStrategy;
    public final autoClosingOvertype:EditorAutoClosingEditStrategy;
    public final autoSurround:EditorAutoSurroundStrategy;
    public final autoIndent:EditorAutoIndentStrategy;
    public final autoClosingPairs:AutoClosingPairs;
    public final surroundingPairs:CharacterMap;
    public final blockCommentStartToken:Null<String>;
    public final shouldAutoCloseBefore:ShouldAutoCloseBefore;
    public final wordSegmenterLocales:Array<String>;

    public final languageConfigurationService:ILanguageConfigurationService;

    final _languageId:String;
    var _electricChars:Null<Map<String, Bool>>;

    public static function shouldRecreate(e:ConfigurationChangedEvent):Bool {
        return (
            e.hasChanged(EditorOption.layoutInfo)
            || e.hasChanged(EditorOption.wordSeparators)
            || e.hasChanged(EditorOption.emptySelectionClipboard)
            || e.hasChanged(EditorOption.multiCursorMergeOverlapping)
            || e.hasChanged(EditorOption.multiCursorPaste)
            || e.hasChanged(EditorOption.multiCursorLimit)
            || e.hasChanged(EditorOption.autoClosingBrackets)
            || e.hasChanged(EditorOption.autoClosingComments)
            || e.hasChanged(EditorOption.autoClosingQuotes)
            || e.hasChanged(EditorOption.autoClosingDelete)
            || e.hasChanged(EditorOption.autoClosingOvertype)
            || e.hasChanged(EditorOption.autoSurround)
            || e.hasChanged(EditorOption.useTabStops)
            || e.hasChanged(EditorOption.fontInfo)
            || e.hasChanged(EditorOption.readOnly)
            || e.hasChanged(EditorOption.wordSegmenterLocales)
        );
    }

    public function new(
        languageId:String,
        modelOptions:TextModelResolvedOptions,
        configuration:IEditorConfiguration,
        languageConfigurationService:ILanguageConfigurationService
    ) {
        this.languageConfigurationService = languageConfigurationService;
        this._languageId = languageId;

        final options = configuration.options;
        final layoutInfo:EditorLayoutInfo = options.get(EditorOption.layoutInfo);
        final fontInfo:FontInfo = options.get(EditorOption.fontInfo);

        this.readOnly = options.get(EditorOption.readOnly);
        this.tabSize = modelOptions.tabSize;
        this.indentSize = modelOptions.indentSize;
        this.insertSpaces = modelOptions.insertSpaces;
        this.stickyTabStops = options.get(EditorOption.stickyTabStops);
        this.lineHeight = fontInfo.lineHeight;
        this.typicalHalfwidthCharacterWidth = fontInfo.typicalHalfwidthCharacterWidth;
        this.pageSize = Std.int(Math.max(1, Math.floor(layoutInfo.height / this.lineHeight) - 2));
        this.useTabStops = options.get(EditorOption.useTabStops);
        this.wordSeparators = options.get(EditorOption.wordSeparators);
        this.emptySelectionClipboard = options.get(EditorOption.emptySelectionClipboard);
        this.copyWithSyntaxHighlighting = options.get(EditorOption.copyWithSyntaxHighlighting);
        this.multiCursorMergeOverlapping = options.get(EditorOption.multiCursorMergeOverlapping);
        this.multiCursorPaste = options.get(EditorOption.multiCursorPaste);
        this.multiCursorLimit = options.get(EditorOption.multiCursorLimit);
        this.autoClosingBrackets = options.get(EditorOption.autoClosingBrackets);
        this.autoClosingComments = options.get(EditorOption.autoClosingComments);
        this.autoClosingQuotes = options.get(EditorOption.autoClosingQuotes);
        this.autoClosingDelete = options.get(EditorOption.autoClosingDelete);
        this.autoClosingOvertype = options.get(EditorOption.autoClosingOvertype);
        this.autoSurround = options.get(EditorOption.autoSurround);
        this.autoIndent = options.get(EditorOption.autoIndent);
        this.wordSegmenterLocales = options.get(EditorOption.wordSegmenterLocales);

        this.surroundingPairs = new Map();
        this._electricChars = null;

        this.shouldAutoCloseBefore = new ShouldAutoCloseBefore(
            this._getShouldAutoClose(languageId, this.autoClosingQuotes, true),
            this._getShouldAutoClose(languageId, this.autoClosingBrackets, false),
            this._getShouldAutoClose(languageId, this.autoClosingComments, false)
        );

        this.autoClosingPairs = this.languageConfigurationService.getLanguageConfiguration(languageId).getAutoClosingPairs();

        final surroundingPairs = this.languageConfigurationService.getLanguageConfiguration(languageId).getSurroundingPairs();
        if (surroundingPairs != null) {
            for (pair in surroundingPairs) {
                this.surroundingPairs.set(pair.open, pair.close);
            }
        }

        final commentsConfiguration = this.languageConfigurationService.getLanguageConfiguration(languageId).comments;
        this.blockCommentStartToken = (commentsConfiguration != null ? commentsConfiguration.blockCommentStartToken : null);
    }

    public var electricChars(get, never):Map<String, Bool>;
    function get_electricChars():Map<String, Bool> {
        if (this._electricChars == null) {
            final result = new Map<String, Bool>();
            final electricCharacter = this.languageConfigurationService.getLanguageConfiguration(this._languageId).electricCharacter;
            final electricChars = (electricCharacter != null ? electricCharacter.getElectricCharacters() : null);
            if (electricChars != null) {
                for (char in electricChars) {
                    result.set(char, true);
                }
            }
            this._electricChars = result;
        }
        return this._electricChars;
    }

    /**
     * Should return opening bracket type to match indentation with
     */
    public function onElectricCharacter(character:String, context:LineTokens, column:Int):Null<IElectricAction> {
        final scopedLineTokens = Supports.createScopedLineTokens(context, column - 1);
        final electricCharacterSupport = this.languageConfigurationService.getLanguageConfiguration(scopedLineTokens.languageId).electricCharacter;
        if (electricCharacterSupport == null) {
            return null;
        }
        return electricCharacterSupport.onElectricCharacter(character, scopedLineTokens, column - scopedLineTokens.firstCharOffset);
    }

    public function normalizeIndentation(str:String):String {
        return Indentation.normalizeIndentation(str, this.indentSize, this.insertSpaces);
    }

    static function autoCloseAlways(ch:String):Bool {
        return true;
    }

    static function autoCloseNever(ch:String):Bool {
        return false;
    }

    static function autoCloseBeforeWhitespace(ch:String):Bool {
        return (ch == ' ' || ch == '\t');
    }

    function _getShouldAutoClose(languageId:String, autoCloseConfig:EditorAutoClosingStrategy, forQuotes:Bool):(ch:String) -> Bool {
        switch (autoCloseConfig) {
            case 'beforeWhitespace':
                return autoCloseBeforeWhitespace;
            case 'languageDefined':
                return this._getLanguageDefinedShouldAutoClose(languageId, forQuotes);
            case 'always':
                return autoCloseAlways;
            case 'never':
                return autoCloseNever;
            case _:
                // Monaco returns undefined for a value outside the strategy (the validated options never give one)
                return autoCloseNever;
        }
    }

    function _getLanguageDefinedShouldAutoClose(languageId:String, forQuotes:Bool):(ch:String) -> Bool {
        final autoCloseBeforeSet = this.languageConfigurationService.getLanguageConfiguration(languageId).getAutoCloseBeforeSet(forQuotes);
        return c -> autoCloseBeforeSet.indexOf(c) != -1;
    }

    /**
     * Returns a visible column from a column.
     * @see {@link CursorColumns}
     */
    public function visibleColumnFromColumn(model:ICursorSimpleModel, position:Position):Int {
        return CursorColumns.visibleColumnFromColumn(model.getLineContent(position.lineNumber), position.column, this.tabSize);
    }

    /**
     * Returns a visible column from a column.
     * @see {@link CursorColumns}
     */
    public function columnFromVisibleColumn(model:ICursorSimpleModel, lineNumber:Int, visibleColumn:Int):Int {
        final result = CursorColumns.columnFromVisibleColumn(model.getLineContent(lineNumber), visibleColumn, this.tabSize);

        final minColumn = model.getLineMinColumn(lineNumber);
        if (result < minColumn) {
            return minColumn;
        }

        final maxColumn = model.getLineMaxColumn(lineNumber);
        if (result > maxColumn) {
            return maxColumn;
        }

        return result;
    }

}

/**
 * Represents a simple model (either the model or the view model).
 */
interface ICursorSimpleModel {
    function getLineCount():Int;
    function getLineContent(lineNumber:Int):String;
    function getLineMinColumn(lineNumber:Int):Int;
    function getLineMaxColumn(lineNumber:Int):Int;
    function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int;
    function getLineLastNonWhitespaceColumn(lineNumber:Int):Int;
    function normalizePosition(position:Position, affinity:PositionAffinity):Position;

    /**
     * Gets the column at which indentation stops at a given line.
     * @internal
     */
    function getLineIndentColumn(lineNumber:Int):Int;
}

/**
 * Monaco's `PartialCursorState`: `CursorState | PartialModelCursorState |
 * PartialViewCursorState`, the common base of the three classes (a model
 * state, a view state, or both).
 */
class PartialCursorState {

    public final modelState:Null<SingleCursorState>;
    public final viewState:Null<SingleCursorState>;

    function new(modelState:Null<SingleCursorState>, viewState:Null<SingleCursorState>) {
        this.modelState = modelState;
        this.viewState = viewState;
    }

}

/**
 * The state of one cursor (model and view states).
 *
 * `modelState` and `viewState` are never null here (the fields are typed
 * as in `PartialCursorState`; read them through `CursorState`).
 */
class CursorState extends PartialCursorState {

    public static function fromModelState(modelState:SingleCursorState):PartialModelCursorState {
        return new PartialModelCursorState(modelState);
    }

    public static function fromViewState(viewState:SingleCursorState):PartialViewCursorState {
        return new PartialViewCursorState(viewState);
    }

    public static function fromModelSelection(modelSelection:ISelection):PartialModelCursorState {
        final selection = Selection.liftSelection(modelSelection);
        final modelState = new SingleCursorState(
            Range.fromPositions(selection.getSelectionStart()),
            SelectionStartKind.Simple, 0,
            selection.getPosition(), 0
        );
        return CursorState.fromModelState(modelState);
    }

    /**
     * Lifts selections (classes or `ISelection` literals) to model states.
     */
    public static function fromModelSelections(modelSelections:Array<ISelection>):Array<PartialCursorState> {
        final states:Array<PartialCursorState> = [];
        for (i in 0...modelSelections.length) {
            states[i] = fromModelSelection(modelSelections[i]);
        }
        return states;
    }

    /**
     * `fromModelSelections` for `Selection` instances (no structural access).
     */
    public static function fromSelections(modelSelections:Array<Selection>):Array<PartialCursorState> {
        final states:Array<PartialCursorState> = [];
        for (i in 0...modelSelections.length) {
            final selection = modelSelections[i];
            states[i] = CursorState.fromModelState(new SingleCursorState(
                Range.fromPositions(selection.getSelectionStart()),
                SelectionStartKind.Simple, 0,
                selection.getPosition(), 0
            ));
        }
        return states;
    }

    public function new(modelState:SingleCursorState, viewState:SingleCursorState) {
        super(modelState, viewState);
    }

    public function equals(other:CursorState):Bool {
        return (this.viewState.equals(other.viewState) && this.modelState.equals(other.modelState));
    }

}

class PartialModelCursorState extends PartialCursorState {

    public function new(modelState:SingleCursorState) {
        super(modelState, null);
    }

}

class PartialViewCursorState extends PartialCursorState {

    public function new(viewState:SingleCursorState) {
        super(null, viewState);
    }

}

enum abstract SelectionStartKind(Int) from Int to Int {
    var Simple = 0;
    var Word = 1;
    var Line = 2;
}

/**
 * Represents the cursor state on either the model or on the view model.
 */
class SingleCursorState {

    public final selection:Selection;

    public final selectionStart:Range;
    public final selectionStartKind:SelectionStartKind;
    public final selectionStartLeftoverVisibleColumns:Int;
    public final position:Position;
    public final leftoverVisibleColumns:Int;

    public function new(
        selectionStart:Range,
        selectionStartKind:SelectionStartKind,
        selectionStartLeftoverVisibleColumns:Int,
        position:Position,
        leftoverVisibleColumns:Int
    ) {
        this.selectionStart = selectionStart;
        this.selectionStartKind = selectionStartKind;
        this.selectionStartLeftoverVisibleColumns = selectionStartLeftoverVisibleColumns;
        this.position = position;
        this.leftoverVisibleColumns = leftoverVisibleColumns;
        this.selection = SingleCursorState._computeSelection(this.selectionStart, this.position);
    }

    public function equals(other:SingleCursorState):Bool {
        return (
            this.selectionStartLeftoverVisibleColumns == other.selectionStartLeftoverVisibleColumns
            && this.leftoverVisibleColumns == other.leftoverVisibleColumns
            && this.selectionStartKind == other.selectionStartKind
            && this.position.equals(other.position)
            && this.selectionStart.equalsRange(other.selectionStart)
        );
    }

    public function hasSelection():Bool {
        return (!this.selection.isEmpty() || !this.selectionStart.isEmpty());
    }

    public function move(inSelectionMode:Bool, lineNumber:Int, column:Int, leftoverVisibleColumns:Int):SingleCursorState {
        if (inSelectionMode) {
            // move just position
            return new SingleCursorState(
                this.selectionStart,
                this.selectionStartKind,
                this.selectionStartLeftoverVisibleColumns,
                new Position(lineNumber, column),
                leftoverVisibleColumns
            );
        }
        else {
            // move everything
            return new SingleCursorState(
                new Range(lineNumber, column, lineNumber, column),
                SelectionStartKind.Simple,
                leftoverVisibleColumns,
                new Position(lineNumber, column),
                leftoverVisibleColumns
            );
        }
    }

    static function _computeSelection(selectionStart:Range, position:Position):Selection {
        if (selectionStart.isEmpty() || !position.isBeforeOrEqual(selectionStart.getStartPosition())) {
            return Selection.fromPositions(selectionStart.getStartPosition(), position);
        }
        else {
            return Selection.fromPositions(selectionStart.getEndPosition(), position);
        }
    }

}

/**
 * The options of `EditOperationResult`.
 */
typedef EditOperationResultOptions = {
    var shouldPushStackElementBefore:Bool;
    var shouldPushStackElementAfter:Bool;
}

class EditOperationResult {

    public final type:EditOperationType;
    public final commands:Array<Null<ICommand>>;
    public final shouldPushStackElementBefore:Bool;
    public final shouldPushStackElementAfter:Bool;

    public function new(type:EditOperationType, commands:Array<Null<ICommand>>, opts:EditOperationResultOptions) {
        this.type = type;
        this.commands = commands;
        this.shouldPushStackElementBefore = opts.shouldPushStackElementBefore;
        this.shouldPushStackElementAfter = opts.shouldPushStackElementAfter;
    }

}

class CursorCommon {

    public static function isQuote(ch:String):Bool {
        return (ch == '\'' || ch == '"' || ch == '`');
    }

}
