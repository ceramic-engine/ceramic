// Ported from vscode src/vs/editor/common/cursor/cursorWordOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.CursorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.EditorAutoClosingEditStrategy;
import cityscape.common.config.EditorOptions.EditorAutoClosingStrategy;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.WordCharacterClassifier;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.common.cursor.CursorDeleteOperations;
import cityscape.common.languages.LanguageConfiguration.AutoClosingPairs;

private class IFindWordResult {
    /**
     * The index where the word starts.
     */
    public final start:Int;
    /**
     * The index where the word ends.
     */
    public final end:Int;
    /**
     * The word type.
     */
    public final wordType:WordType;
    /**
     * The reason the word ended.
     */
    public final nextCharClass:WordCharacterClass;

    public function new(start:Int, end:Int, wordType:WordType, nextCharClass:WordCharacterClass) {
        this.start = start;
        this.end = end;
        this.wordType = wordType;
        this.nextCharClass = nextCharClass;
    }
}

private enum abstract WordType(Int) from Int to Int {
    var None = 0;
    var Regular = 1;
    var Separator = 2;
}

enum abstract WordNavigationType(Int) from Int to Int {
    var WordStart = 0;
    var WordStartFast = 1;
    var WordEnd = 2;
    var WordAccessibility = 3; // Respect chrome definition of a word
}

typedef DeleteWordContext = {
    var wordSeparators:WordCharacterClassifier;
    var model:ITextModel;
    var selection:Selection;
    var whitespaceHeuristics:Bool;
    var autoClosingDelete:EditorAutoClosingEditStrategy;
    var autoClosingBrackets:EditorAutoClosingStrategy;
    var autoClosingQuotes:EditorAutoClosingStrategy;
    var autoClosingPairs:AutoClosingPairs;
    var autoClosedCharacters:Array<Range>;
}

class WordOperations {

    static function _createWord(lineContent:String, wordType:WordType, nextCharClass:WordCharacterClass, start:Int, end:Int):IFindWordResult {
        return new IFindWordResult(start, end, wordType, nextCharClass);
    }

    static function _createIntlWord(intlWord:IntlWordSegmentData, nextCharClass:WordCharacterClass):IFindWordResult {
        return new IFindWordResult(intlWord.index, intlWord.index + intlWord.segment.length, WordType.Regular, nextCharClass);
    }

    static function _findPreviousWordOnLine(wordSeparators:WordCharacterClassifier, model:ICursorSimpleModel, position:Position):Null<IFindWordResult> {
        final lineContent = model.getLineContent(position.lineNumber);
        return _doFindPreviousWordOnLine(lineContent, wordSeparators, position);
    }

    static function _doFindPreviousWordOnLine(lineContent:String, wordSeparators:WordCharacterClassifier, position:Position):Null<IFindWordResult> {
        var wordType = WordType.None;

        final previousIntlWord = wordSeparators.findPrevIntlWordBeforeOrAtOffset(lineContent, position.column - 2);

        var chIndex = position.column - 2;
        while (chIndex >= 0) {
            final chCode = StringTools.fastCodeAt(lineContent, chIndex);
            final chClass:WordCharacterClass = wordSeparators.get(chCode);

            if (previousIntlWord != null && chIndex == previousIntlWord.index) {
                return _createIntlWord(previousIntlWord, chClass);
            }

            if (chClass == WordCharacterClass.Regular) {
                if (wordType == WordType.Separator) {
                    return _createWord(lineContent, wordType, chClass, chIndex + 1, _findEndOfWord(lineContent, wordSeparators, wordType, chIndex + 1));
                }
                wordType = WordType.Regular;
            }
            else if (chClass == WordCharacterClass.WordSeparator) {
                if (wordType == WordType.Regular) {
                    return _createWord(lineContent, wordType, chClass, chIndex + 1, _findEndOfWord(lineContent, wordSeparators, wordType, chIndex + 1));
                }
                wordType = WordType.Separator;
            }
            else if (chClass == WordCharacterClass.Whitespace) {
                if (wordType != WordType.None) {
                    return _createWord(lineContent, wordType, chClass, chIndex + 1, _findEndOfWord(lineContent, wordSeparators, wordType, chIndex + 1));
                }
            }
            chIndex--;
        }

        if (wordType != WordType.None) {
            return _createWord(lineContent, wordType, WordCharacterClass.Whitespace, 0, _findEndOfWord(lineContent, wordSeparators, wordType, 0));
        }

        return null;
    }

    static function _findEndOfWord(lineContent:String, wordSeparators:WordCharacterClassifier, wordType:WordType, startIndex:Int):Int {

        final nextIntlWord = wordSeparators.findNextIntlWordAtOrAfterOffset(lineContent, startIndex);

        final len = lineContent.length;
        for (chIndex in startIndex...len) {
            final chCode = StringTools.fastCodeAt(lineContent, chIndex);
            final chClass:WordCharacterClass = wordSeparators.get(chCode);

            if (nextIntlWord != null && chIndex == nextIntlWord.index + nextIntlWord.segment.length) {
                return chIndex;
            }

            if (chClass == WordCharacterClass.Whitespace) {
                return chIndex;
            }
            if (wordType == WordType.Regular && chClass == WordCharacterClass.WordSeparator) {
                return chIndex;
            }
            if (wordType == WordType.Separator && chClass == WordCharacterClass.Regular) {
                return chIndex;
            }
        }
        return len;
    }

    static function _findNextWordOnLine(wordSeparators:WordCharacterClassifier, model:ICursorSimpleModel, position:Position):Null<IFindWordResult> {
        final lineContent = model.getLineContent(position.lineNumber);
        return _doFindNextWordOnLine(lineContent, wordSeparators, position);
    }

    static function _doFindNextWordOnLine(lineContent:String, wordSeparators:WordCharacterClassifier, position:Position):Null<IFindWordResult> {
        var wordType = WordType.None;
        final len = lineContent.length;

        final nextIntlWord = wordSeparators.findNextIntlWordAtOrAfterOffset(lineContent, position.column - 1);

        var chIndex = position.column - 1;
        while (chIndex < len) {
            final chCode = StringTools.fastCodeAt(lineContent, chIndex);
            final chClass:WordCharacterClass = wordSeparators.get(chCode);

            if (nextIntlWord != null && chIndex == nextIntlWord.index) {
                return _createIntlWord(nextIntlWord, chClass);
            }

            if (chClass == WordCharacterClass.Regular) {
                if (wordType == WordType.Separator) {
                    return _createWord(lineContent, wordType, chClass, _findStartOfWord(lineContent, wordSeparators, wordType, chIndex - 1), chIndex);
                }
                wordType = WordType.Regular;
            }
            else if (chClass == WordCharacterClass.WordSeparator) {
                if (wordType == WordType.Regular) {
                    return _createWord(lineContent, wordType, chClass, _findStartOfWord(lineContent, wordSeparators, wordType, chIndex - 1), chIndex);
                }
                wordType = WordType.Separator;
            }
            else if (chClass == WordCharacterClass.Whitespace) {
                if (wordType != WordType.None) {
                    return _createWord(lineContent, wordType, chClass, _findStartOfWord(lineContent, wordSeparators, wordType, chIndex - 1), chIndex);
                }
            }
            chIndex++;
        }

        if (wordType != WordType.None) {
            return _createWord(lineContent, wordType, WordCharacterClass.Whitespace, _findStartOfWord(lineContent, wordSeparators, wordType, len - 1), len);
        }

        return null;
    }

    static function _findStartOfWord(lineContent:String, wordSeparators:WordCharacterClassifier, wordType:WordType, startIndex:Int):Int {

        final previousIntlWord = wordSeparators.findPrevIntlWordBeforeOrAtOffset(lineContent, startIndex);

        var chIndex = startIndex;
        while (chIndex >= 0) {
            final chCode = StringTools.fastCodeAt(lineContent, chIndex);
            final chClass:WordCharacterClass = wordSeparators.get(chCode);

            if (previousIntlWord != null && chIndex == previousIntlWord.index) {
                return chIndex;
            }

            if (chClass == WordCharacterClass.Whitespace) {
                return chIndex + 1;
            }
            if (wordType == WordType.Regular && chClass == WordCharacterClass.WordSeparator) {
                return chIndex + 1;
            }
            if (wordType == WordType.Separator && chClass == WordCharacterClass.Regular) {
                return chIndex + 1;
            }
            chIndex--;
        }
        return 0;
    }

    public static function moveWordLeft(wordSeparators:WordCharacterClassifier, model:ICursorSimpleModel, position:Position, wordNavigationType:WordNavigationType, hasMulticursor:Bool):Position {
        var lineNumber = position.lineNumber;
        var column = position.column;

        if (column == 1) {
            if (lineNumber > 1) {
                lineNumber = lineNumber - 1;
                column = model.getLineMaxColumn(lineNumber);
            }
        }

        var prevWordOnLine = WordOperations._findPreviousWordOnLine(wordSeparators, model, new Position(lineNumber, column));

        if (wordNavigationType == WordNavigationType.WordStart) {
            return new Position(lineNumber, prevWordOnLine != null ? prevWordOnLine.start + 1 : 1);
        }

        if (wordNavigationType == WordNavigationType.WordStartFast) {
            if (
                !hasMulticursor // avoid having multiple cursors stop at different locations when doing word start
                && prevWordOnLine != null
                && prevWordOnLine.wordType == WordType.Separator
                && prevWordOnLine.end - prevWordOnLine.start == 1
                && prevWordOnLine.nextCharClass == WordCharacterClass.Regular
            ) {
                // Skip over a word made up of one single separator and followed by a regular character
                prevWordOnLine = WordOperations._findPreviousWordOnLine(wordSeparators, model, new Position(lineNumber, prevWordOnLine.start + 1));
            }

            return new Position(lineNumber, prevWordOnLine != null ? prevWordOnLine.start + 1 : 1);
        }

        if (wordNavigationType == WordNavigationType.WordAccessibility) {
            while (
                prevWordOnLine != null
                && prevWordOnLine.wordType == WordType.Separator
            ) {
                // Skip over words made up of only separators
                prevWordOnLine = WordOperations._findPreviousWordOnLine(wordSeparators, model, new Position(lineNumber, prevWordOnLine.start + 1));
            }

            return new Position(lineNumber, prevWordOnLine != null ? prevWordOnLine.start + 1 : 1);
        }

        // We are stopping at the ending of words

        if (prevWordOnLine != null && column <= prevWordOnLine.end + 1) {
            prevWordOnLine = WordOperations._findPreviousWordOnLine(wordSeparators, model, new Position(lineNumber, prevWordOnLine.start + 1));
        }

        return new Position(lineNumber, prevWordOnLine != null ? prevWordOnLine.end + 1 : 1);
    }

    public static function _moveWordPartLeft(model:ICursorSimpleModel, position:Position):Position {
        final lineNumber = position.lineNumber;
        final maxColumn = model.getLineMaxColumn(lineNumber);

        if (position.column == 1) {
            return (lineNumber > 1 ? new Position(lineNumber - 1, model.getLineMaxColumn(lineNumber - 1)) : position);
        }

        final lineContent = model.getLineContent(lineNumber);
        var column = position.column - 1;
        while (column > 1) {
            final left = StringTools.fastCodeAt(lineContent, column - 2);
            final right = StringTools.fastCodeAt(lineContent, column - 1);

            if (left == CharCode.Underline && right != CharCode.Underline) {
                // snake_case_variables
                return new Position(lineNumber, column);
            }

            if (left == CharCode.Dash && right != CharCode.Dash) {
                // kebab-case-variables
                return new Position(lineNumber, column);
            }

            if ((Strings.isLowerAsciiLetter(left) || Strings.isAsciiDigit(left)) && Strings.isUpperAsciiLetter(right)) {
                // camelCaseVariables
                return new Position(lineNumber, column);
            }

            if (Strings.isUpperAsciiLetter(left) && Strings.isUpperAsciiLetter(right)) {
                // thisIsACamelCaseWithOneLetterWords
                if (column + 1 < maxColumn) {
                    final rightRight = StringTools.fastCodeAt(lineContent, column);
                    if (Strings.isLowerAsciiLetter(rightRight) || Strings.isAsciiDigit(rightRight)) {
                        return new Position(lineNumber, column);
                    }
                }
            }
            column--;
        }

        return new Position(lineNumber, 1);
    }

    public static function moveWordRight(wordSeparators:WordCharacterClassifier, model:ICursorSimpleModel, position:Position, wordNavigationType:WordNavigationType):Position {
        var lineNumber = position.lineNumber;
        var column = position.column;

        var movedDown = false;
        if (column == model.getLineMaxColumn(lineNumber)) {
            if (lineNumber < model.getLineCount()) {
                movedDown = true;
                lineNumber = lineNumber + 1;
                column = 1;
            }
        }

        var nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, new Position(lineNumber, column));

        if (wordNavigationType == WordNavigationType.WordEnd) {
            if (nextWordOnLine != null && nextWordOnLine.wordType == WordType.Separator) {
                if (nextWordOnLine.end - nextWordOnLine.start == 1 && nextWordOnLine.nextCharClass == WordCharacterClass.Regular) {
                    // Skip over a word made up of one single separator and followed by a regular character
                    nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, new Position(lineNumber, nextWordOnLine.end + 1));
                }
            }
            if (nextWordOnLine != null) {
                column = nextWordOnLine.end + 1;
            }
            else {
                column = model.getLineMaxColumn(lineNumber);
            }
        }
        else if (wordNavigationType == WordNavigationType.WordAccessibility) {
            if (movedDown) {
                // If we move to the next line, pretend that the cursor is right before the first character.
                // This is needed when the first word starts right at the first character - and in order not to miss it,
                // we need to start before.
                column = 0;
            }

            while (
                nextWordOnLine != null
                && (nextWordOnLine.wordType == WordType.Separator
                    || nextWordOnLine.start + 1 <= column
                )
            ) {
                // Skip over a word made up of one single separator
                // Also skip over word if it begins before current cursor position to ascertain we're moving forward at least 1 character.
                nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, new Position(lineNumber, nextWordOnLine.end + 1));
            }

            if (nextWordOnLine != null) {
                column = nextWordOnLine.start + 1;
            }
            else {
                column = model.getLineMaxColumn(lineNumber);
            }
        }
        else {
            if (nextWordOnLine != null && !movedDown && column >= nextWordOnLine.start + 1) {
                nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, new Position(lineNumber, nextWordOnLine.end + 1));
            }
            if (nextWordOnLine != null) {
                column = nextWordOnLine.start + 1;
            }
            else {
                column = model.getLineMaxColumn(lineNumber);
            }
        }

        return new Position(lineNumber, column);
    }

    public static function _moveWordPartRight(model:ICursorSimpleModel, position:Position):Position {
        final lineNumber = position.lineNumber;
        final maxColumn = model.getLineMaxColumn(lineNumber);

        if (position.column == maxColumn) {
            return (lineNumber < model.getLineCount() ? new Position(lineNumber + 1, 1) : position);
        }

        final lineContent = model.getLineContent(lineNumber);
        for (column in (position.column + 1)...maxColumn) {
            final left = StringTools.fastCodeAt(lineContent, column - 2);
            final right = StringTools.fastCodeAt(lineContent, column - 1);

            if (left != CharCode.Underline && right == CharCode.Underline) {
                // snake_case_variables
                return new Position(lineNumber, column);
            }

            if (left != CharCode.Dash && right == CharCode.Dash) {
                // kebab-case-variables
                return new Position(lineNumber, column);
            }

            if ((Strings.isLowerAsciiLetter(left) || Strings.isAsciiDigit(left)) && Strings.isUpperAsciiLetter(right)) {
                // camelCaseVariables
                return new Position(lineNumber, column);
            }

            if (Strings.isUpperAsciiLetter(left) && Strings.isUpperAsciiLetter(right)) {
                // thisIsACamelCaseWithOneLetterWords
                if (column + 1 < maxColumn) {
                    final rightRight = StringTools.fastCodeAt(lineContent, column);
                    if (Strings.isLowerAsciiLetter(rightRight) || Strings.isAsciiDigit(rightRight)) {
                        return new Position(lineNumber, column);
                    }
                }
            }
        }

        return new Position(lineNumber, maxColumn);
    }

    static function _deleteWordLeftWhitespace(model:ICursorSimpleModel, position:Position):Null<Range> {
        final lineContent = model.getLineContent(position.lineNumber);
        final startIndex = position.column - 2;
        final lastNonWhitespace = Strings.lastNonWhitespaceIndex(lineContent, startIndex);
        if (lastNonWhitespace + 1 < startIndex) {
            return new Range(position.lineNumber, lastNonWhitespace + 2, position.lineNumber, position.column);
        }
        return null;
    }

    public static function deleteWordLeft(ctx:DeleteWordContext, wordNavigationType:WordNavigationType):Null<Range> {
        final wordSeparators = ctx.wordSeparators;
        final model = ctx.model;
        final selection = ctx.selection;
        final whitespaceHeuristics = ctx.whitespaceHeuristics;

        if (!selection.isEmpty()) {
            return selection;
        }

        if (DeleteOperations.isAutoClosingPairDelete(ctx.autoClosingDelete, ctx.autoClosingBrackets, ctx.autoClosingQuotes, ctx.autoClosingPairs.autoClosingPairsOpenByEnd, ctx.model, [ctx.selection], ctx.autoClosedCharacters)) {
            final position = ctx.selection.getPosition();
            return new Range(position.lineNumber, position.column - 1, position.lineNumber, position.column + 1);
        }

        final position = new Position(selection.positionLineNumber, selection.positionColumn);

        var lineNumber = position.lineNumber;
        var column = position.column;

        if (lineNumber == 1 && column == 1) {
            // Ignore deleting at beginning of file
            return null;
        }

        if (whitespaceHeuristics) {
            final r = _deleteWordLeftWhitespace(model, position);
            if (r != null) {
                return r;
            }
        }

        var prevWordOnLine = WordOperations._findPreviousWordOnLine(wordSeparators, model, position);

        if (wordNavigationType == WordNavigationType.WordStart) {
            if (prevWordOnLine != null) {
                column = prevWordOnLine.start + 1;
            }
            else {
                if (column > 1) {
                    column = 1;
                }
                else {
                    lineNumber--;
                    column = model.getLineMaxColumn(lineNumber);
                }
            }
        }
        else {
            if (prevWordOnLine != null && column <= prevWordOnLine.end + 1) {
                prevWordOnLine = WordOperations._findPreviousWordOnLine(wordSeparators, model, new Position(lineNumber, prevWordOnLine.start + 1));
            }
            if (prevWordOnLine != null) {
                column = prevWordOnLine.end + 1;
            }
            else {
                if (column > 1) {
                    column = 1;
                }
                else {
                    lineNumber--;
                    column = model.getLineMaxColumn(lineNumber);
                }
            }
        }

        return new Range(lineNumber, column, position.lineNumber, position.column);
    }

    public static function deleteInsideWord(wordSeparators:WordCharacterClassifier, model:ITextModel, selection:Selection):Range {
        if (!selection.isEmpty()) {
            return selection;
        }

        final position = new Position(selection.positionLineNumber, selection.positionColumn);

        final r = _deleteInsideWordWhitespace(model, position);
        if (r != null) {
            return r;
        }

        return _deleteInsideWordDetermineDeleteRange(wordSeparators, model, position);
    }

    static function _charAtIsWhitespace(str:String, index:Int):Bool {
        final charCode = StringTools.fastCodeAt(str, index);
        return (charCode == CharCode.Space || charCode == CharCode.Tab);
    }

    static function _deleteInsideWordWhitespace(model:ICursorSimpleModel, position:Position):Null<Range> {
        final lineContent = model.getLineContent(position.lineNumber);
        final lineContentLength = lineContent.length;

        if (lineContentLength == 0) {
            // empty line
            return null;
        }

        var leftIndex = Std.int(Math.max(position.column - 2, 0));
        if (!_charAtIsWhitespace(lineContent, leftIndex)) {
            // touches a non-whitespace character to the left
            return null;
        }

        var rightIndex = Std.int(Math.min(position.column - 1, lineContentLength - 1));
        if (!_charAtIsWhitespace(lineContent, rightIndex)) {
            // touches a non-whitespace character to the right
            return null;
        }

        // walk over whitespace to the left
        while (leftIndex > 0 && _charAtIsWhitespace(lineContent, leftIndex - 1)) {
            leftIndex--;
        }

        // walk over whitespace to the right
        while (rightIndex + 1 < lineContentLength && _charAtIsWhitespace(lineContent, rightIndex + 1)) {
            rightIndex++;
        }

        return new Range(position.lineNumber, leftIndex + 1, position.lineNumber, rightIndex + 2);
    }

    static function _deleteInsideWordDetermineDeleteRange(wordSeparators:WordCharacterClassifier, model:ICursorSimpleModel, position:Position):Range {
        final lineContent = model.getLineContent(position.lineNumber);
        final lineLength = lineContent.length;
        if (lineLength == 0) {
            // empty line
            if (position.lineNumber > 1) {
                return new Range(position.lineNumber - 1, model.getLineMaxColumn(position.lineNumber - 1), position.lineNumber, 1);
            }
            else {
                if (position.lineNumber < model.getLineCount()) {
                    return new Range(position.lineNumber, 1, position.lineNumber + 1, 1);
                }
                else {
                    // empty model
                    return new Range(position.lineNumber, 1, position.lineNumber, 1);
                }
            }
        }

        final touchesWord = (word:IFindWordResult) -> {
            return (word.start + 1 <= position.column && position.column <= word.end + 1);
        };
        final createRangeWithPosition = (startColumn:Int, endColumn:Int) -> {
            startColumn = Std.int(Math.min(startColumn, position.column));
            endColumn = Std.int(Math.max(endColumn, position.column));
            return new Range(position.lineNumber, startColumn, position.lineNumber, endColumn);
        };
        final deleteWordAndAdjacentWhitespace = (word:IFindWordResult) -> {
            var startColumn = word.start + 1;
            var endColumn = word.end + 1;
            var expandedToTheRight = false;
            while (endColumn - 1 < lineLength && _charAtIsWhitespace(lineContent, endColumn - 1)) {
                expandedToTheRight = true;
                endColumn++;
            }
            if (!expandedToTheRight) {
                while (startColumn > 1 && _charAtIsWhitespace(lineContent, startColumn - 2)) {
                    startColumn--;
                }
            }
            return createRangeWithPosition(startColumn, endColumn);
        };

        final prevWordOnLine = WordOperations._findPreviousWordOnLine(wordSeparators, model, position);
        if (prevWordOnLine != null && touchesWord(prevWordOnLine)) {
            return deleteWordAndAdjacentWhitespace(prevWordOnLine);
        }
        final nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, position);
        if (nextWordOnLine != null && touchesWord(nextWordOnLine)) {
            return deleteWordAndAdjacentWhitespace(nextWordOnLine);
        }
        if (prevWordOnLine != null && nextWordOnLine != null) {
            return createRangeWithPosition(prevWordOnLine.end + 1, nextWordOnLine.start + 1);
        }
        if (prevWordOnLine != null) {
            return createRangeWithPosition(prevWordOnLine.start + 1, prevWordOnLine.end + 1);
        }
        if (nextWordOnLine != null) {
            return createRangeWithPosition(nextWordOnLine.start + 1, nextWordOnLine.end + 1);
        }

        return createRangeWithPosition(1, lineLength + 1);
    }

    public static function _deleteWordPartLeft(model:ICursorSimpleModel, selection:Selection):Range {
        if (!selection.isEmpty()) {
            return selection;
        }

        final pos = selection.getPosition();
        final toPosition = WordOperations._moveWordPartLeft(model, pos);
        return new Range(pos.lineNumber, pos.column, toPosition.lineNumber, toPosition.column);
    }

    static function _findFirstNonWhitespaceChar(str:String, startIndex:Int):Int {
        final len = str.length;
        for (chIndex in startIndex...len) {
            final ch = str.charAt(chIndex);
            if (ch != ' ' && ch != '\t') {
                return chIndex;
            }
        }
        return len;
    }

    static function _deleteWordRightWhitespace(model:ICursorSimpleModel, position:Position):Null<Range> {
        final lineContent = model.getLineContent(position.lineNumber);
        final startIndex = position.column - 1;
        final firstNonWhitespace = _findFirstNonWhitespaceChar(lineContent, startIndex);
        if (startIndex + 1 < firstNonWhitespace) {
            // bingo
            return new Range(position.lineNumber, position.column, position.lineNumber, firstNonWhitespace + 1);
        }
        return null;
    }

    public static function deleteWordRight(ctx:DeleteWordContext, wordNavigationType:WordNavigationType):Null<Range> {
        final wordSeparators = ctx.wordSeparators;
        final model = ctx.model;
        final selection = ctx.selection;
        final whitespaceHeuristics = ctx.whitespaceHeuristics;

        if (!selection.isEmpty()) {
            return selection;
        }

        final position = new Position(selection.positionLineNumber, selection.positionColumn);

        var lineNumber = position.lineNumber;
        var column = position.column;

        final lineCount = model.getLineCount();
        final maxColumn = model.getLineMaxColumn(lineNumber);
        if (lineNumber == lineCount && column == maxColumn) {
            // Ignore deleting at end of file
            return null;
        }

        if (whitespaceHeuristics) {
            final r = _deleteWordRightWhitespace(model, position);
            if (r != null) {
                return r;
            }
        }

        var nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, position);

        if (wordNavigationType == WordNavigationType.WordEnd) {
            if (nextWordOnLine != null) {
                column = nextWordOnLine.end + 1;
            }
            else {
                if (column < maxColumn || lineNumber == lineCount) {
                    column = maxColumn;
                }
                else {
                    lineNumber++;
                    nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, new Position(lineNumber, 1));
                    if (nextWordOnLine != null) {
                        column = nextWordOnLine.start + 1;
                    }
                    else {
                        column = model.getLineMaxColumn(lineNumber);
                    }
                }
            }
        }
        else {
            if (nextWordOnLine != null && column >= nextWordOnLine.start + 1) {
                nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, new Position(lineNumber, nextWordOnLine.end + 1));
            }
            if (nextWordOnLine != null) {
                column = nextWordOnLine.start + 1;
            }
            else {
                if (column < maxColumn || lineNumber == lineCount) {
                    column = maxColumn;
                }
                else {
                    lineNumber++;
                    nextWordOnLine = WordOperations._findNextWordOnLine(wordSeparators, model, new Position(lineNumber, 1));
                    if (nextWordOnLine != null) {
                        column = nextWordOnLine.start + 1;
                    }
                    else {
                        column = model.getLineMaxColumn(lineNumber);
                    }
                }
            }
        }

        return new Range(lineNumber, column, position.lineNumber, position.column);
    }

    public static function _deleteWordPartRight(model:ICursorSimpleModel, selection:Selection):Range {
        if (!selection.isEmpty()) {
            return selection;
        }

        final pos = selection.getPosition();
        final toPosition = WordOperations._moveWordPartRight(model, pos);
        return new Range(pos.lineNumber, pos.column, toPosition.lineNumber, toPosition.column);
    }

    static function _createWordAtPosition(model:ITextModel, lineNumber:Int, word:IFindWordResult):IWordAtPosition {
        final range = new Range(lineNumber, word.start + 1, lineNumber, word.end + 1);
        return {
            word: model.getValueInRange(range),
            startColumn: range.startColumn,
            endColumn: range.endColumn
        };
    }

    public static function getWordAtPosition(model:ITextModel, _wordSeparators:String, _intlSegmenterLocales:Array<String>, position:Position):Null<IWordAtPosition> {
        final wordSeparators = WordCharacterClassifier.getMapForWordSeparators(_wordSeparators, _intlSegmenterLocales);
        final prevWord = WordOperations._findPreviousWordOnLine(wordSeparators, model, position);
        if (prevWord != null && prevWord.wordType == WordType.Regular && prevWord.start <= position.column - 1 && position.column - 1 <= prevWord.end) {
            return WordOperations._createWordAtPosition(model, position.lineNumber, prevWord);
        }
        final nextWord = WordOperations._findNextWordOnLine(wordSeparators, model, position);
        if (nextWord != null && nextWord.wordType == WordType.Regular && nextWord.start <= position.column - 1 && position.column - 1 <= nextWord.end) {
            return WordOperations._createWordAtPosition(model, position.lineNumber, nextWord);
        }
        return null;
    }

    public static function word(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool, position:Position):SingleCursorState {
        final wordSeparators = WordCharacterClassifier.getMapForWordSeparators(config.wordSeparators, config.wordSegmenterLocales);
        final prevWord = WordOperations._findPreviousWordOnLine(wordSeparators, model, position);
        final nextWord = WordOperations._findNextWordOnLine(wordSeparators, model, position);

        if (!inSelectionMode) {
            // Entering word selection for the first time
            var startColumn:Int;
            var endColumn:Int;

            if (prevWord != null && prevWord.wordType == WordType.Regular && prevWord.start <= position.column - 1 && position.column - 1 <= prevWord.end) {
                // isTouchingPrevWord
                startColumn = prevWord.start + 1;
                endColumn = prevWord.end + 1;
            }
            else if (nextWord != null && nextWord.wordType == WordType.Regular && nextWord.start <= position.column - 1 && position.column - 1 <= nextWord.end) {
                // isTouchingNextWord
                startColumn = nextWord.start + 1;
                endColumn = nextWord.end + 1;
            }
            else {
                if (prevWord != null) {
                    startColumn = prevWord.end + 1;
                }
                else {
                    startColumn = 1;
                }
                if (nextWord != null) {
                    endColumn = nextWord.start + 1;
                }
                else {
                    endColumn = model.getLineMaxColumn(position.lineNumber);
                }
            }

            return new SingleCursorState(
                new Range(position.lineNumber, startColumn, position.lineNumber, endColumn), SelectionStartKind.Word, 0,
                new Position(position.lineNumber, endColumn), 0
            );
        }

        var startColumn:Int;
        var endColumn:Int;

        if (prevWord != null && prevWord.wordType == WordType.Regular && prevWord.start < position.column - 1 && position.column - 1 < prevWord.end) {
            // isInsidePrevWord
            startColumn = prevWord.start + 1;
            endColumn = prevWord.end + 1;
        }
        else if (nextWord != null && nextWord.wordType == WordType.Regular && nextWord.start < position.column - 1 && position.column - 1 < nextWord.end) {
            // isInsideNextWord
            startColumn = nextWord.start + 1;
            endColumn = nextWord.end + 1;
        }
        else {
            startColumn = position.column;
            endColumn = position.column;
        }

        final lineNumber = position.lineNumber;
        var column:Int;
        if (cursor.selectionStart.containsPosition(position)) {
            column = cursor.selectionStart.endColumn;
        }
        else if (position.isBeforeOrEqual(cursor.selectionStart.getStartPosition())) {
            column = startColumn;
            final possiblePosition = new Position(lineNumber, column);
            if (cursor.selectionStart.containsPosition(possiblePosition)) {
                column = cursor.selectionStart.endColumn;
            }
        }
        else {
            column = endColumn;
            final possiblePosition = new Position(lineNumber, column);
            if (cursor.selectionStart.containsPosition(possiblePosition)) {
                column = cursor.selectionStart.startColumn;
            }
        }

        return cursor.move(true, lineNumber, column, 0);
    }

}

class WordPartOperations extends WordOperations {

    public static function deleteWordPartLeft(ctx:DeleteWordContext):Null<Range> {
        final candidates = enforceDefined([
            WordOperations.deleteWordLeft(ctx, WordNavigationType.WordStart),
            WordOperations.deleteWordLeft(ctx, WordNavigationType.WordEnd),
            WordOperations._deleteWordPartLeft(ctx.model, ctx.selection)
        ]);
        haxe.ds.ArraySort.sort(candidates, Range.compareRangesUsingEnds);
        return candidates[2];
    }

    public static function deleteWordPartRight(ctx:DeleteWordContext):Null<Range> {
        final candidates = enforceDefined([
            WordOperations.deleteWordRight(ctx, WordNavigationType.WordStart),
            WordOperations.deleteWordRight(ctx, WordNavigationType.WordEnd),
            WordOperations._deleteWordPartRight(ctx.model, ctx.selection)
        ]);
        haxe.ds.ArraySort.sort(candidates, Range.compareRangesUsingStarts);
        return candidates[0];
    }

    public static function moveWordPartLeft(wordSeparators:WordCharacterClassifier, model:ICursorSimpleModel, position:Position, hasMulticursor:Bool):Position {
        final candidates = enforceDefined([
            WordOperations.moveWordLeft(wordSeparators, model, position, WordNavigationType.WordStart, hasMulticursor),
            WordOperations.moveWordLeft(wordSeparators, model, position, WordNavigationType.WordEnd, hasMulticursor),
            WordOperations._moveWordPartLeft(model, position)
        ]);
        haxe.ds.ArraySort.sort(candidates, Position.compare);
        return candidates[2];
    }

    public static function moveWordPartRight(wordSeparators:WordCharacterClassifier, model:ICursorSimpleModel, position:Position):Position {
        final candidates = enforceDefined([
            WordOperations.moveWordRight(wordSeparators, model, position, WordNavigationType.WordStart),
            WordOperations.moveWordRight(wordSeparators, model, position, WordNavigationType.WordEnd),
            WordOperations._moveWordPartRight(model, position)
        ]);
        haxe.ds.ArraySort.sort(candidates, Position.compare);
        return candidates[0];
    }

    static function enforceDefined<T>(arr:Array<Null<T>>):Array<T> {
        return [for (el in arr) if (el != null) el];
    }

}
