// Ported from vscode src/vs/editor/common/model/textModelSearch.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.CharCode;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.Model.EndOfLinePreference;
import cityscape.common.Model.FindMatch;
import cityscape.common.Model.SearchData;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.WordCharacterClassifier;

class SearchParams {

    public final searchString:String;

    public final isRegex:Bool;

    public final matchCase:Bool;

    public final wordSeparators:Null<String>;

    public function new(searchString:String, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>) {
        this.searchString = searchString;
        this.isRegex = isRegex;
        this.matchCase = matchCase;
        this.wordSeparators = wordSeparators;
    }

    public function parseSearchRequest():Null<SearchData> {
        if (this.searchString == '') {
            return null;
        }

        // Try to create a RegExp out of the params
        var multiline:Bool;
        if (this.isRegex) {
            multiline = TextModelSearch.isMultilineRegexSource(this.searchString);
        }
        else {
            multiline = (this.searchString.indexOf('\n') >= 0);
        }

        var regex:Null<RegExp> = null;
        try {
            regex = Strings.createRegExp(this.searchString, this.isRegex, {
                matchCase: this.matchCase,
                wholeWord: false,
                multiline: multiline,
                global: true,
                unicode: true
            });
        }
        catch (err:Dynamic) {
            return null;
        }

        if (regex == null) {
            return null;
        }

        var canUseSimpleSearch = (!this.isRegex && !multiline);
        if (canUseSimpleSearch && this.searchString.toLowerCase() != this.searchString.toUpperCase()) {
            // casing might make a difference
            canUseSimpleSearch = this.matchCase;
        }

        return new SearchData(regex, (this.wordSeparators != null && this.wordSeparators.length > 0) ? WordCharacterClassifier.getMapForWordSeparators(this.wordSeparators, []) : null, canUseSimpleSearch ? this.searchString : null);
    }

}

class LineFeedCounter {

    final _lineFeedsOffsets:Array<Int>;

    public function new(text:String) {
        final lineFeedsOffsets:Array<Int> = [];
        var lineFeedsOffsetsLen = 0;
        for (i in 0...text.length) {
            if (StringTools.fastCodeAt(text, i) == CharCode.LineFeed) {
                lineFeedsOffsets[lineFeedsOffsetsLen++] = i;
            }
        }
        this._lineFeedsOffsets = lineFeedsOffsets;
    }

    public function findLineFeedCountBeforeOffset(offset:Int):Int {
        final lineFeedsOffsets = this._lineFeedsOffsets;
        var min = 0;
        var max = lineFeedsOffsets.length - 1;

        if (max == -1) {
            // no line feeds
            return 0;
        }

        if (offset <= lineFeedsOffsets[0]) {
            // before first line feed
            return 0;
        }

        while (min < max) {
            final mid = min + ((max - min) >> 1);

            if (lineFeedsOffsets[mid] >= offset) {
                max = mid - 1;
            }
            else {
                if (lineFeedsOffsets[mid + 1] >= offset) {
                    // bingo!
                    min = mid;
                    max = mid;
                }
                else {
                    min = mid + 1;
                }
            }
        }
        return min + 1;
    }

}

class TextModelSearch {

    static inline final LIMIT_FIND_COUNT = 999;

    public static function isMultilineRegexSource(searchString:Null<String>):Bool {
        if (searchString == null || searchString.length == 0) {
            return false;
        }

        var i = 0;
        final len = searchString.length;
        while (i < len) {
            final chCode = StringTools.fastCodeAt(searchString, i);

            if (chCode == CharCode.LineFeed) {
                return true;
            }

            if (chCode == CharCode.Backslash) {

                // move to next char
                i++;

                if (i >= len) {
                    // string ends with a \
                    break;
                }

                final nextChCode = StringTools.fastCodeAt(searchString, i);
                if (nextChCode == CharCode.n || nextChCode == CharCode.r || nextChCode == CharCode.W) {
                    return true;
                }
            }
            i++;
        }

        return false;
    }

    public static function createFindMatch(range:Range, rawMatches:RegExpExecArray, captureMatches:Bool):FindMatch {
        if (!captureMatches) {
            return new FindMatch(range, null);
        }
        final matches:Array<String> = [];
        for (i in 0...rawMatches.length) {
            matches[i] = rawMatches[i];
        }
        return new FindMatch(range, matches);
    }

    public static function findMatches(model:TextModel, searchParams:SearchParams, searchRange:Range, captureMatches:Bool, limitResultCount:Int):Array<FindMatch> {
        final searchData = searchParams.parseSearchRequest();
        if (searchData == null) {
            return [];
        }

        if (searchData.regex.multiline) {
            return _doFindMatchesMultiline(model, searchRange, new Searcher(searchData.wordSeparators, searchData.regex), captureMatches, limitResultCount);
        }
        return _doFindMatchesLineByLine(model, searchRange, searchData, captureMatches, limitResultCount);
    }

    /**
     * Multiline search always executes on the lines concatenated with \n.
     * We must therefore compensate for the count of \n in case the model is CRLF
     */
    static function _getMultilineMatchRange(model:TextModel, deltaOffset:Int, text:String, lfCounter:Null<LineFeedCounter>, matchIndex:Int, match0:String):Range {
        var startOffset:Int;
        var lineFeedCountBeforeMatch = 0;
        if (lfCounter != null) {
            lineFeedCountBeforeMatch = lfCounter.findLineFeedCountBeforeOffset(matchIndex);
            startOffset = deltaOffset + matchIndex + lineFeedCountBeforeMatch /* add as many \r as there were \n */;
        }
        else {
            startOffset = deltaOffset + matchIndex;
        }

        var endOffset:Int;
        if (lfCounter != null) {
            final lineFeedCountBeforeEndOfMatch = lfCounter.findLineFeedCountBeforeOffset(matchIndex + match0.length);
            final lineFeedCountInMatch = lineFeedCountBeforeEndOfMatch - lineFeedCountBeforeMatch;
            endOffset = startOffset + match0.length + lineFeedCountInMatch /* add as many \r as there were \n */;
        }
        else {
            endOffset = startOffset + match0.length;
        }

        final startPosition = model.getPositionAt(startOffset);
        final endPosition = model.getPositionAt(endOffset);
        return new Range(startPosition.lineNumber, startPosition.column, endPosition.lineNumber, endPosition.column);
    }

    static function _doFindMatchesMultiline(model:TextModel, searchRange:Range, searcher:Searcher, captureMatches:Bool, limitResultCount:Int):Array<FindMatch> {
        final deltaOffset = model.getOffsetAt(searchRange.getStartPosition());
        // We always execute multiline search over the lines joined with \n
        // This makes it that \n will match the EOL for both CRLF and LF models
        // We compensate for offset errors in `_getMultilineMatchRange`
        final text = model.getValueInRange(searchRange, EndOfLinePreference.LF);
        final lfCounter = (model.getEOL() == '\r\n' ? new LineFeedCounter(text) : null);

        final result:Array<FindMatch> = [];
        var counter = 0;

        var m:Null<RegExpExecArray>;
        searcher.reset(0);
        while ((m = searcher.next(text)) != null) {
            result[counter++] = createFindMatch(_getMultilineMatchRange(model, deltaOffset, text, lfCounter, m.index, m[0]), m, captureMatches);
            if (counter >= limitResultCount) {
                return result;
            }
        }

        return result;
    }

    static function _doFindMatchesLineByLine(model:TextModel, searchRange:Range, searchData:SearchData, captureMatches:Bool, limitResultCount:Int):Array<FindMatch> {
        final result:Array<FindMatch> = [];
        var resultLen = 0;

        // Early case for a search range that starts & stops on the same line number
        if (searchRange.startLineNumber == searchRange.endLineNumber) {
            final text = model.getLineContent(searchRange.startLineNumber).substring(searchRange.startColumn - 1, searchRange.endColumn - 1);
            resultLen = _findMatchesInLine(searchData, text, searchRange.startLineNumber, searchRange.startColumn - 1, resultLen, result, captureMatches, limitResultCount);
            return result;
        }

        // Collect results from first line
        final text = model.getLineContent(searchRange.startLineNumber).substring(searchRange.startColumn - 1);
        resultLen = _findMatchesInLine(searchData, text, searchRange.startLineNumber, searchRange.startColumn - 1, resultLen, result, captureMatches, limitResultCount);

        // Collect results from middle lines
        var lineNumber = searchRange.startLineNumber + 1;
        while (lineNumber < searchRange.endLineNumber && resultLen < limitResultCount) {
            resultLen = _findMatchesInLine(searchData, model.getLineContent(lineNumber), lineNumber, 0, resultLen, result, captureMatches, limitResultCount);
            lineNumber++;
        }

        // Collect results from last line
        if (resultLen < limitResultCount) {
            final text = model.getLineContent(searchRange.endLineNumber).substring(0, searchRange.endColumn - 1);
            resultLen = _findMatchesInLine(searchData, text, searchRange.endLineNumber, 0, resultLen, result, captureMatches, limitResultCount);
        }

        return result;
    }

    static function _findMatchesInLine(searchData:SearchData, text:String, lineNumber:Int, deltaOffset:Int, resultLen:Int, result:Array<FindMatch>, captureMatches:Bool, limitResultCount:Int):Int {
        final wordSeparators = searchData.wordSeparators;
        if (!captureMatches && searchData.simpleSearch != null && searchData.simpleSearch.length > 0) {
            final searchString = searchData.simpleSearch;
            final searchStringLen = searchString.length;
            final textLength = text.length;

            var lastMatchIndex = -searchStringLen;
            while ((lastMatchIndex = text.indexOf(searchString, lastMatchIndex + searchStringLen)) != -1) {
                if (wordSeparators == null || isValidMatch(wordSeparators, text, textLength, lastMatchIndex, searchStringLen)) {
                    result[resultLen++] = new FindMatch(new Range(lineNumber, lastMatchIndex + 1 + deltaOffset, lineNumber, lastMatchIndex + 1 + searchStringLen + deltaOffset), null);
                    if (resultLen >= limitResultCount) {
                        return resultLen;
                    }
                }
            }
            return resultLen;
        }

        final searcher = new Searcher(searchData.wordSeparators, searchData.regex);
        var m:Null<RegExpExecArray>;
        // Reset regex to search from the beginning
        searcher.reset(0);
        do {
            m = searcher.next(text);
            if (m != null) {
                result[resultLen++] = createFindMatch(new Range(lineNumber, m.index + 1 + deltaOffset, lineNumber, m.index + 1 + m[0].length + deltaOffset), m, captureMatches);
                if (resultLen >= limitResultCount) {
                    return resultLen;
                }
            }
        } while (m != null);
        return resultLen;
    }

    public static function findNextMatch(model:TextModel, searchParams:SearchParams, searchStart:Position, captureMatches:Bool):Null<FindMatch> {
        final searchData = searchParams.parseSearchRequest();
        if (searchData == null) {
            return null;
        }

        final searcher = new Searcher(searchData.wordSeparators, searchData.regex);

        if (searchData.regex.multiline) {
            return _doFindNextMatchMultiline(model, searchStart, searcher, captureMatches);
        }
        return _doFindNextMatchLineByLine(model, searchStart, searcher, captureMatches);
    }

    static function _doFindNextMatchMultiline(model:TextModel, searchStart:Position, searcher:Searcher, captureMatches:Bool):Null<FindMatch> {
        final searchTextStart = new Position(searchStart.lineNumber, 1);
        final deltaOffset = model.getOffsetAt(searchTextStart);
        final lineCount = model.getLineCount();
        // We always execute multiline search over the lines joined with \n
        // This makes it that \n will match the EOL for both CRLF and LF models
        // We compensate for offset errors in `_getMultilineMatchRange`
        final text = model.getValueInRange(new Range(searchTextStart.lineNumber, searchTextStart.column, lineCount, model.getLineMaxColumn(lineCount)), EndOfLinePreference.LF);
        final lfCounter = (model.getEOL() == '\r\n' ? new LineFeedCounter(text) : null);
        searcher.reset(searchStart.column - 1);
        final m = searcher.next(text);
        if (m != null) {
            return createFindMatch(
                _getMultilineMatchRange(model, deltaOffset, text, lfCounter, m.index, m[0]),
                m,
                captureMatches
            );
        }

        if (searchStart.lineNumber != 1 || searchStart.column != 1) {
            // Try again from the top
            return _doFindNextMatchMultiline(model, new Position(1, 1), searcher, captureMatches);
        }

        return null;
    }

    static function _doFindNextMatchLineByLine(model:TextModel, searchStart:Position, searcher:Searcher, captureMatches:Bool):Null<FindMatch> {
        final lineCount = model.getLineCount();
        final startLineNumber = searchStart.lineNumber;

        // Look in first line
        final text = model.getLineContent(startLineNumber);
        final r = _findFirstMatchInLine(searcher, text, startLineNumber, searchStart.column, captureMatches);
        if (r != null) {
            return r;
        }

        for (i in 1...lineCount + 1) {
            final lineIndex = (startLineNumber + i - 1) % lineCount;
            final text = model.getLineContent(lineIndex + 1);
            final r = _findFirstMatchInLine(searcher, text, lineIndex + 1, 1, captureMatches);
            if (r != null) {
                return r;
            }
        }

        return null;
    }

    static function _findFirstMatchInLine(searcher:Searcher, text:String, lineNumber:Int, fromColumn:Int, captureMatches:Bool):Null<FindMatch> {
        // Set regex to search from column
        searcher.reset(fromColumn - 1);
        final m:Null<RegExpExecArray> = searcher.next(text);
        if (m != null) {
            return createFindMatch(
                new Range(lineNumber, m.index + 1, lineNumber, m.index + 1 + m[0].length),
                m,
                captureMatches
            );
        }
        return null;
    }

    public static function findPreviousMatch(model:TextModel, searchParams:SearchParams, searchStart:Position, captureMatches:Bool):Null<FindMatch> {
        final searchData = searchParams.parseSearchRequest();
        if (searchData == null) {
            return null;
        }

        final searcher = new Searcher(searchData.wordSeparators, searchData.regex);

        if (searchData.regex.multiline) {
            return _doFindPreviousMatchMultiline(model, searchStart, searcher, captureMatches);
        }
        return _doFindPreviousMatchLineByLine(model, searchStart, searcher, captureMatches);
    }

    static function _doFindPreviousMatchMultiline(model:TextModel, searchStart:Position, searcher:Searcher, captureMatches:Bool):Null<FindMatch> {
        final matches = _doFindMatchesMultiline(model, new Range(1, 1, searchStart.lineNumber, searchStart.column), searcher, captureMatches, 10 * LIMIT_FIND_COUNT);
        if (matches.length > 0) {
            return matches[matches.length - 1];
        }

        final lineCount = model.getLineCount();
        if (searchStart.lineNumber != lineCount || searchStart.column != model.getLineMaxColumn(lineCount)) {
            // Try again with all content
            return _doFindPreviousMatchMultiline(model, new Position(lineCount, model.getLineMaxColumn(lineCount)), searcher, captureMatches);
        }

        return null;
    }

    static function _doFindPreviousMatchLineByLine(model:TextModel, searchStart:Position, searcher:Searcher, captureMatches:Bool):Null<FindMatch> {
        final lineCount = model.getLineCount();
        final startLineNumber = searchStart.lineNumber;

        // Look in first line
        final text = model.getLineContent(startLineNumber).substring(0, searchStart.column - 1);
        final r = _findLastMatchInLine(searcher, text, startLineNumber, captureMatches);
        if (r != null) {
            return r;
        }

        for (i in 1...lineCount + 1) {
            final lineIndex = (lineCount + startLineNumber - i - 1) % lineCount;
            final text = model.getLineContent(lineIndex + 1);
            final r = _findLastMatchInLine(searcher, text, lineIndex + 1, captureMatches);
            if (r != null) {
                return r;
            }
        }

        return null;
    }

    static function _findLastMatchInLine(searcher:Searcher, text:String, lineNumber:Int, captureMatches:Bool):Null<FindMatch> {
        var bestResult:Null<FindMatch> = null;
        var m:Null<RegExpExecArray>;
        searcher.reset(0);
        while ((m = searcher.next(text)) != null) {
            bestResult = createFindMatch(new Range(lineNumber, m.index + 1, lineNumber, m.index + 1 + m[0].length), m, captureMatches);
        }
        return bestResult;
    }

    static function leftIsWordBounday(wordSeparators:WordCharacterClassifier, text:String, textLength:Int, matchStartIndex:Int, matchLength:Int):Bool {
        if (matchStartIndex == 0) {
            // Match starts at start of string
            return true;
        }

        final charBefore = StringTools.fastCodeAt(text, matchStartIndex - 1);
        if (wordSeparators.get(charBefore) != WordCharacterClass.Regular) {
            // The character before the match is a word separator
            return true;
        }

        if (charBefore == CharCode.CarriageReturn || charBefore == CharCode.LineFeed) {
            // The character before the match is line break or carriage return.
            return true;
        }

        if (matchLength > 0) {
            final firstCharInMatch = StringTools.fastCodeAt(text, matchStartIndex);
            if (wordSeparators.get(firstCharInMatch) != WordCharacterClass.Regular) {
                // The first character inside the match is a word separator
                return true;
            }
        }

        return false;
    }

    static function rightIsWordBounday(wordSeparators:WordCharacterClassifier, text:String, textLength:Int, matchStartIndex:Int, matchLength:Int):Bool {
        if (matchStartIndex + matchLength == textLength) {
            // Match ends at end of string
            return true;
        }

        final charAfter = StringTools.fastCodeAt(text, matchStartIndex + matchLength);
        if (wordSeparators.get(charAfter) != WordCharacterClass.Regular) {
            // The character after the match is a word separator
            return true;
        }

        if (charAfter == CharCode.CarriageReturn || charAfter == CharCode.LineFeed) {
            // The character after the match is line break or carriage return.
            return true;
        }

        if (matchLength > 0) {
            final lastCharInMatch = StringTools.fastCodeAt(text, matchStartIndex + matchLength - 1);
            if (wordSeparators.get(lastCharInMatch) != WordCharacterClass.Regular) {
                // The last character in the match is a word separator
                return true;
            }
        }

        return false;
    }

    public static function isValidMatch(wordSeparators:WordCharacterClassifier, text:String, textLength:Int, matchStartIndex:Int, matchLength:Int):Bool {
        return (
            leftIsWordBounday(wordSeparators, text, textLength, matchStartIndex, matchLength)
            && rightIsWordBounday(wordSeparators, text, textLength, matchStartIndex, matchLength)
        );
    }

}

class Searcher {

    public final _wordSeparators:Null<WordCharacterClassifier>;

    final _searchRegex:RegExp;

    var _prevMatchStartIndex:Int;

    var _prevMatchLength:Int;

    public function new(wordSeparators:Null<WordCharacterClassifier>, searchRegex:RegExp) {
        this._wordSeparators = wordSeparators;
        this._searchRegex = searchRegex;
        this._prevMatchStartIndex = -1;
        this._prevMatchLength = 0;
    }

    public function reset(lastIndex:Int):Void {
        this._searchRegex.lastIndex = lastIndex;
        this._prevMatchStartIndex = -1;
        this._prevMatchLength = 0;
    }

    public function next(text:String):Null<RegExpExecArray> {
        final textLength = text.length;

        var m:Null<RegExpExecArray>;
        do {
            if (this._prevMatchStartIndex + this._prevMatchLength == textLength) {
                // Reached the end of the line
                return null;
            }

            m = this._searchRegex.exec(text);
            if (m == null) {
                return null;
            }

            final matchStartIndex = m.index;
            final matchLength = m[0].length;
            if (matchStartIndex == this._prevMatchStartIndex && matchLength == this._prevMatchLength) {
                if (matchLength == 0) {
                    // the search result is an empty string and won't advance `regex.lastIndex`, so `regex.exec` will stuck here
                    // we attempt to recover from that by advancing by two if surrogate pair found and by one otherwise
                    if (Strings.getNextCodePoint(text, textLength, this._searchRegex.lastIndex) > 0xFFFF) {
                        this._searchRegex.lastIndex += 2;
                    }
                    else {
                        this._searchRegex.lastIndex += 1;
                    }
                    continue;
                }
                // Exit early if the regex matches the same range twice
                return null;
            }
            this._prevMatchStartIndex = matchStartIndex;
            this._prevMatchLength = matchLength;

            if (this._wordSeparators == null || isValidMatchOf(this._wordSeparators, text, textLength, matchStartIndex, matchLength)) {
                return m;
            }

        } while (m != null);

        return null;
    }

    static inline function isValidMatchOf(wordSeparators:WordCharacterClassifier, text:String, textLength:Int, matchStartIndex:Int, matchLength:Int):Bool {
        return TextModelSearch.isValidMatch(wordSeparators, text, textLength, matchStartIndex, matchLength);
    }

}
