// Ported from vscode src/vs/base/common/filters.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import haxe.ds.Vector;

// Types of this module:
// - IFilter, IMatch
// - Filters (the module functions of filters.ts)
// - FuzzyScore, FuzzyScoreOptions, FuzzyScorer
// - Korean (the module functions of naturalLanguage/korean.ts, which only
//   filters.ts uses)

/**
 * Returns null if word doesn't match.
 */
typedef IFilter = (word:String, wordToMatchAgainst:String) -> Null<Array<IMatch>>;

typedef IMatch = {
    var start:Int;
    var end:Int;
}

/**
 * The module functions of filters.ts.
 *
 * Monaco's module level tables of `fuzzyScore` (`_table`, `_diag`,
 * `_arrows`, `_minWordMatchPos`, `_maxWordMatchPos`) are static scratch
 * buffers here too: they hold no state between two calls (every call writes
 * the cells it reads), so sharing them between editors is safe. They are
 * flat `Vector<Int>`s of `(_maxLen + 1) * (_maxLen + 1)` cells (row major).
 *
 * The regular expressions of `matchesFuzzy` are cached by pattern like
 * Monaco's `LRUCache` (10000 entries, the least recently used one is
 * dropped first). The cache only saves the creation of the regular
 * expressions, it changes no result.
 */
class Filters {

    // Combined filters

    /**
     * @returns A filter which combines the provided set
     * of filters with an or. The *first* filters that
     * matches defined the return value of the returned
     * filter.
     */
    public static function or(...filter:IFilter):IFilter {
        final filters = filter.toArray();
        return function(word:String, wordToMatchAgainst:String):Null<Array<IMatch>> {
            for (i in 0...filters.length) {
                final match = filters[i](word, wordToMatchAgainst);
                if (match != null) {
                    return match;
                }
            }
            return null;
        };
    }

    // Prefix

    public static function matchesStrictPrefix(word:String, wordToMatchAgainst:String):Null<Array<IMatch>> {
        return _matchesPrefix(false, word, wordToMatchAgainst);
    }

    public static function matchesPrefix(word:String, wordToMatchAgainst:String):Null<Array<IMatch>> {
        return _matchesPrefix(true, word, wordToMatchAgainst);
    }

    static function _matchesPrefix(ignoreCase:Bool, word:String, wordToMatchAgainst:String):Null<Array<IMatch>> {
        if (wordToMatchAgainst == null || wordToMatchAgainst.length == 0 || wordToMatchAgainst.length < word.length) {
            return null;
        }

        var matches:Bool;
        if (ignoreCase) {
            matches = Strings.startsWithIgnoreCase(wordToMatchAgainst, word);
        }
        else {
            matches = wordToMatchAgainst.indexOf(word) == 0;
        }

        if (!matches) {
            return null;
        }

        return word.length > 0 ? [{start: 0, end: word.length}] : [];
    }

    // Contiguous Substring

    public static function matchesContiguousSubString(word:String, wordToMatchAgainst:String):Null<Array<IMatch>> {
        final index = wordToMatchAgainst.toLowerCase().indexOf(word.toLowerCase());
        if (index == -1) {
            return null;
        }

        return [{start: index, end: index + word.length}];
    }

    // Substring

    public static function matchesSubString(word:String, wordToMatchAgainst:String):Null<Array<IMatch>> {
        return _matchesSubString(word.toLowerCase(), wordToMatchAgainst.toLowerCase(), 0, 0);
    }

    static function _matchesSubString(word:String, wordToMatchAgainst:String, i:Int, j:Int):Null<Array<IMatch>> {
        if (i == word.length) {
            return [];
        }
        else if (j == wordToMatchAgainst.length) {
            return null;
        }
        else {
            if (StringTools.fastCodeAt(word, i) == StringTools.fastCodeAt(wordToMatchAgainst, j)) {
                final result = _matchesSubString(word, wordToMatchAgainst, i + 1, j + 1);
                if (result != null) {
                    return join({start: j, end: j + 1}, result);
                }
                return null;
            }

            return _matchesSubString(word, wordToMatchAgainst, i, j + 1);
        }
    }

    // CamelCase

    static inline function isLower(code:Int):Bool {
        return (CharCode.a:Int) <= code && code <= (CharCode.z:Int);
    }

    public static inline function isUpper(code:Int):Bool {
        return (CharCode.A:Int) <= code && code <= (CharCode.Z:Int);
    }

    static inline function isNumber(code:Int):Bool {
        return (CharCode.Digit0:Int) <= code && code <= (CharCode.Digit9:Int);
    }

    static inline function isWhitespace(code:Int):Bool {
        return (
            code == CharCode.Space
            || code == CharCode.Tab
            || code == CharCode.LineFeed
            || code == CharCode.CarriageReturn
        );
    }

    /**
     * Monaco's `wordSeparators` set: these are chosen as natural word
     * separators based on writen text. It is a subset of the word separators
     * used by the monaco editor (`'()[]{}<>`\'"-/;:,.?!'`).
     */
    static function isWordSeparatorChar(code:Int):Bool {
        return switch code {
            case '('.code | ')'.code | '['.code | ']'.code | '{'.code | '}'.code | '<'.code | '>'.code | '`'.code | "'".code | '"'.code | '-'.code | '/'.code | ';'.code | ':'.code | ','.code | '.'.code | '?'.code | '!'.code: true;
            case _: false;
        }
    }

    static inline function isWordSeparator(code:Int):Bool {
        return isWhitespace(code) || isWordSeparatorChar(code);
    }

    static inline function charactersMatch(codeA:Int, codeB:Int):Bool {
        return (codeA == codeB) || (isWordSeparator(codeA) && isWordSeparator(codeB));
    }

    static final alternateCharsCache:Map<Int, Null<Array<Int>>> = new Map();

    /**
     * Gets alternative codes to the character code passed in. This comes in the
     * form of an array of character codes, all of which must match _in order_ to
     * successfully match.
     *
     * @param code The character code to check.
     */
    static function getAlternateCodes(code:Int):Null<Array<Int>> {
        if (alternateCharsCache.exists(code)) {
            return alternateCharsCache.get(code);
        }

        // NOTE: This function is written in such a way that it can be extended in
        // the future, but right now the return type takes into account it's only
        // supported by a single "alt codes provider".
        // `ArrayLike<ArrayLike<number>>` is a more appropriate type if changed.
        var result:Null<Array<Int>> = null;
        final codes = Korean.getKoreanAltChars(code);
        if (codes != null) {
            result = codes;
        }

        alternateCharsCache.set(code, result);
        return result;
    }

    static inline function isAlphanumeric(code:Int):Bool {
        return isLower(code) || isUpper(code) || isNumber(code);
    }

    static function join(head:IMatch, tail:Array<IMatch>):Array<IMatch> {
        if (tail.length == 0) {
            tail = [head];
        }
        else if (head.end == tail[0].start) {
            tail[0].start = head.start;
        }
        else {
            tail.unshift(head);
        }
        return tail;
    }

    static function nextAnchor(camelCaseWord:String, start:Int):Int {
        for (i in start...camelCaseWord.length) {
            final c = StringTools.fastCodeAt(camelCaseWord, i);
            if (isUpper(c) || isNumber(c) || (i > 0 && !isAlphanumeric(StringTools.fastCodeAt(camelCaseWord, i - 1)))) {
                return i;
            }
        }
        return camelCaseWord.length;
    }

    /**
     * `word[i] !== camelCaseWord[j].toLowerCase()`, without a string for
     * ASCII characters.
     */
    static function camelCaseCharDiffers(word:String, i:Int, camelCaseWord:String, j:Int):Bool {
        final a = StringTools.fastCodeAt(word, i);
        final b = StringTools.fastCodeAt(camelCaseWord, j);
        if (b < 128) {
            return a != (isUpper(b) ? b + 32 : b);
        }
        return word.charAt(i) != camelCaseWord.charAt(j).toLowerCase();
    }

    static function _matchesCamelCase(word:String, camelCaseWord:String, i:Int, j:Int):Null<Array<IMatch>> {
        if (i == word.length) {
            return [];
        }
        else if (j == camelCaseWord.length) {
            return null;
        }
        else if (camelCaseCharDiffers(word, i, camelCaseWord, j)) {
            return null;
        }
        else {
            var result:Null<Array<IMatch>> = null;
            var nextUpperIndex = j + 1;
            result = _matchesCamelCase(word, camelCaseWord, i + 1, j + 1);
            while (result == null && (nextUpperIndex = nextAnchor(camelCaseWord, nextUpperIndex)) < camelCaseWord.length) {
                result = _matchesCamelCase(word, camelCaseWord, i + 1, nextUpperIndex);
                nextUpperIndex++;
            }
            return result == null ? null : join({start: j, end: j + 1}, result);
        }
    }

    // Heuristic to avoid computing camel case matcher for words that don't
    // look like camelCaseWords. Monaco's `analyzeCamelCaseWord` returns an
    // `ICamelCaseAnalysis` object; the four percentages are passed to
    // `isUpperCaseWord` and `isCamelCaseWord` directly here (no object).

    static inline function isUpperCaseWord(upperPercent:Float, lowerPercent:Float):Bool {
        return lowerPercent == 0 && upperPercent > 0.6;
    }

    static inline function isCamelCaseWord(upperPercent:Float, lowerPercent:Float, alphaPercent:Float, numericPercent:Float):Bool {
        return lowerPercent > 0.2 && upperPercent < 0.8 && alphaPercent > 0.6 && numericPercent < 0.2;
    }

    // Heuristic to avoid computing camel case matcher for words that don't
    // look like camel case patterns.
    static function isCamelCasePattern(word:String):Bool {
        var upper = 0, lower = 0, code = 0, whitespace = 0;

        for (i in 0...word.length) {
            code = StringTools.fastCodeAt(word, i);

            if (isUpper(code)) { upper++; }
            if (isLower(code)) { lower++; }
            if (isWhitespace(code)) { whitespace++; }
        }

        if ((upper == 0 || lower == 0) && whitespace == 0) {
            return word.length <= 30;
        }
        else {
            return upper <= 5;
        }
    }

    public static function matchesCamelCase(word:String, camelCaseWord:String):Null<Array<IMatch>> {
        if (camelCaseWord == null || camelCaseWord.length == 0) {
            return null;
        }

        camelCaseWord = trimJs(camelCaseWord);

        if (camelCaseWord.length == 0) {
            return null;
        }

        if (!isCamelCasePattern(word)) {
            return null;
        }

        // TODO: Consider removing this check
        if (camelCaseWord.length > 60) {
            camelCaseWord = camelCaseWord.substring(0, 60);
        }

        // analyzeCamelCaseWord(camelCaseWord)
        var upper = 0, lower = 0, alpha = 0, numeric = 0, code = 0;
        for (i in 0...camelCaseWord.length) {
            code = StringTools.fastCodeAt(camelCaseWord, i);

            if (isUpper(code)) { upper++; }
            if (isLower(code)) { lower++; }
            if (isAlphanumeric(code)) { alpha++; }
            if (isNumber(code)) { numeric++; }
        }
        final upperPercent = upper / camelCaseWord.length;
        final lowerPercent = lower / camelCaseWord.length;
        final alphaPercent = alpha / camelCaseWord.length;
        final numericPercent = numeric / camelCaseWord.length;

        if (!isCamelCaseWord(upperPercent, lowerPercent, alphaPercent, numericPercent)) {
            if (!isUpperCaseWord(upperPercent, lowerPercent)) {
                return null;
            }

            camelCaseWord = camelCaseWord.toLowerCase();
        }

        var result:Null<Array<IMatch>> = null;
        var i = 0;

        word = word.toLowerCase();
        while (i < camelCaseWord.length && (result = _matchesCamelCase(word, camelCaseWord, 0, i)) == null) {
            i = nextAnchor(camelCaseWord, i + 1);
        }

        return result;
    }

    /**
     * JavaScript's `String.prototype.trim` (JavaScript's whitespace set).
     */
    static function trimJs(value:String):String {
        var start = 0;
        var end = value.length;
        while (start < end && Strings.isJsWhitespace(StringTools.fastCodeAt(value, start))) {
            start++;
        }
        while (end > start && Strings.isJsWhitespace(StringTools.fastCodeAt(value, end - 1))) {
            end--;
        }
        return (start == 0 && end == value.length) ? value : value.substring(start, end);
    }

    // Matches beginning of words supporting non-ASCII languages
    // If `contiguous` is true then matches word with beginnings of the words in the target. E.g. "pul" will match "Git: Pull"
    // Otherwise also matches sub string of the word with beginnings of the words in the target. E.g. "gp" or "g p" will match "Git: Pull"
    // Useful in cases where the target is words (e.g. command labels)

    public static function matchesWords(word:String, target:String, contiguous:Bool = false):Null<Array<IMatch>> {
        if (target == null || target.length == 0) {
            return null;
        }

        var result:Null<Array<IMatch>> = null;
        var targetIndex = 0;

        word = word.toLowerCase();
        target = target.toLowerCase();
        while (targetIndex < target.length) {
            result = _matchesWords(word, target, 0, targetIndex, contiguous);
            if (result != null) {
                break;
            }
            targetIndex = nextWord(target, targetIndex + 1);
        }

        return result;
    }

    /**
     * `value.charCodeAt(index)`, -1 when out of range (JavaScript's `NaN`,
     * which equals no character code).
     */
    static inline function codeAtOrNaN(value:String, index:Int):Int {
        return (index >= 0 && index < value.length) ? StringTools.fastCodeAt(value, index) : -1;
    }

    static function _matchesWords(word:String, target:String, wordIndex:Int, targetIndex:Int, contiguous:Bool):Null<Array<IMatch>> {
        var targetIndexOffset = 0;

        if (wordIndex == word.length) {
            return [];
        }
        else if (targetIndex == target.length) {
            return null;
        }
        else if (!charactersMatch(StringTools.fastCodeAt(word, wordIndex), StringTools.fastCodeAt(target, targetIndex))) {
            // Verify alternate characters before exiting
            final altChars = getAlternateCodes(StringTools.fastCodeAt(word, wordIndex));
            if (altChars == null) {
                return null;
            }
            for (k in 0...altChars.length) {
                if (!charactersMatch(altChars[k], codeAtOrNaN(target, targetIndex + k))) {
                    return null;
                }
            }
            targetIndexOffset += altChars.length - 1;
        }

        var result:Null<Array<IMatch>> = null;
        var nextWordIndex = targetIndex + targetIndexOffset + 1;
        result = _matchesWords(word, target, wordIndex + 1, nextWordIndex, contiguous);
        if (!contiguous) {
            while (result == null && (nextWordIndex = nextWord(target, nextWordIndex)) < target.length) {
                result = _matchesWords(word, target, wordIndex + 1, nextWordIndex, contiguous);
                nextWordIndex++;
            }
        }

        if (result == null) {
            return null;
        }

        // If the characters don't exactly match, then they must be word separators (see charactersMatch(...)).
        // We don't want to include this in the matches but we don't want to throw the target out all together so we return `result`.
        if (StringTools.fastCodeAt(word, wordIndex) != StringTools.fastCodeAt(target, targetIndex)) {
            // Verify alternate characters before exiting
            final altChars = getAlternateCodes(StringTools.fastCodeAt(word, wordIndex));
            if (altChars == null) {
                return result;
            }
            for (k in 0...altChars.length) {
                if (altChars[k] != codeAtOrNaN(target, targetIndex + k)) {
                    return result;
                }
            }
        }

        return join({start: targetIndex, end: targetIndex + targetIndexOffset + 1}, result);
    }

    static function nextWord(word:String, start:Int):Int {
        for (i in start...word.length) {
            if (isWordSeparator(StringTools.fastCodeAt(word, i)) ||
                (i > 0 && isWordSeparator(StringTools.fastCodeAt(word, i - 1)))) {
                return i;
            }
        }
        return word.length;
    }

    // Fuzzy

    static var _fuzzyContiguousFilter:Null<IFilter> = null;
    static var _fuzzySeparateFilter:Null<IFilter> = null;

    static function fuzzyContiguousFilter():IFilter {
        if (_fuzzyContiguousFilter == null) {
            _fuzzyContiguousFilter = or(matchesPrefix, matchesCamelCase, matchesContiguousSubString);
        }
        return _fuzzyContiguousFilter;
    }

    static function fuzzySeparateFilter():IFilter {
        if (_fuzzySeparateFilter == null) {
            _fuzzySeparateFilter = or(matchesPrefix, matchesCamelCase, matchesSubString);
        }
        return _fuzzySeparateFilter;
    }

    /**
     * Monaco's `fuzzyRegExpCache` (`LRUCache<string, RegExp>(10000)`).
     */
    static final fuzzyRegExpCache = new FuzzyRegExpCache(10000); // bounded to 10000 elements

    public static function matchesFuzzy(word:Null<String>, wordToMatchAgainst:Null<String>, enableSeparateSubstringMatching:Bool = false):Null<Array<IMatch>> {
        if (word == null || wordToMatchAgainst == null) {
            return null; // return early for invalid input
        }

        // Form RegExp for wildcard matches
        var regexp = fuzzyRegExpCache.get(word);
        if (regexp == null) {
            regexp = new RegExp(Strings.convertSimple2RegExpPattern(word), 'i');
            fuzzyRegExpCache.set(word, regexp);
        }

        // RegExp Filter
        final match = regexp.exec(wordToMatchAgainst);
        if (match != null) {
            return [{start: match.index, end: match.index + match[0].length}];
        }

        // Default Filter
        return enableSeparateSubstringMatching ? fuzzySeparateFilter()(word, wordToMatchAgainst) : fuzzyContiguousFilter()(word, wordToMatchAgainst);
    }

    /**
     * Match pattern against word in a fuzzy way. As in IntelliSense and faster and more
     * powerful than `matchesFuzzy`
     */
    public static function matchesFuzzy2(pattern:String, word:String):Null<Array<IMatch>> {
        final score = fuzzyScore(pattern, pattern.toLowerCase(), 0, word, word.toLowerCase(), 0, FuzzyScoreOptions.weakAndBoost);
        return score != null ? createMatches(score) : null;
    }

    public static function anyScore(pattern:String, lowPattern:String, patternPos:Int, word:String, lowWord:String, wordPos:Int):FuzzyScore {
        final max = (pattern.length < 13 ? pattern.length : 13);
        while (patternPos < max) {
            final result = fuzzyScore(pattern, lowPattern, patternPos, word, lowWord, wordPos, FuzzyScoreOptions.weakAndBoost);
            if (result != null) {
                return result;
            }
            patternPos++;
        }
        return new FuzzyScore(0, wordPos);
    }

    //#region --- fuzzyScore ---

    public static function createMatches(score:Null<FuzzyScore>):Array<IMatch> {
        if (score == null) {
            return [];
        }
        final res:Array<IMatch> = [];
        final wordPos = score[1];
        var i = score.length - 1;
        while (i > 1) {
            final pos = score[i] + wordPos;
            final last = res.length > 0 ? res[res.length - 1] : null;
            if (last != null && last.end == pos) {
                last.end = pos + 1;
            }
            else {
                res.push({start: pos, end: pos + 1});
            }
            i--;
        }
        return res;
    }

    static inline final _maxLen = 128;

    /**
     * The row length of the flat tables (`_maxLen + 1` columns).
     */
    static inline final _rowLen = _maxLen + 1;

    static function initTable():Vector<Int> {
        final table = new Vector<Int>(_rowLen * _rowLen);
        for (i in 0...table.length) {
            table[i] = 0;
        }
        return table;
    }

    static function initArr(maxLen:Int):Vector<Int> {
        final row = new Vector<Int>(maxLen + 1);
        for (i in 0...row.length) {
            row[i] = 0;
        }
        return row;
    }

    static final _minWordMatchPos = initArr(2 * _maxLen); // min word position for a certain pattern position
    static final _maxWordMatchPos = initArr(2 * _maxLen); // max word position for a certain pattern position
    static final _diag = initTable(); // the length of a contiguous diagonal match
    static final _table = initTable();
    static final _arrows = initTable(); // Arrow values
    static inline final _debug = false;

    /**
     * Monaco's `hasStrongFirstMatch` array of one boolean, the out argument
     * of `_doScore`.
     */
    static var _hasStrongFirstMatch = false;

    /**
     * `Number.MIN_SAFE_INTEGER` as the score of a position that does not
     * match. Monaco never keeps such a score in its table (a cell can always
     * be reached from the left there); a smaller magnitude keeps the sums of
     * two of them inside 32 bit integers while still being below any real
     * score.
     */
    static inline final MIN_SAFE_INTEGER = -(1 << 28);

    static function printTable(table:Vector<Int>, pattern:String, patternLen:Int, word:String, wordLen:Int):String {
        function pad(s:String, n:Int, pad = ' ') {
            while (s.length < n) {
                s = pad + s;
            }
            return s;
        }
        var ret = ' |   |' + [for (i in 0...word.length) pad(word.charAt(i), 3)].join('|') + '\n';

        for (i in 0...patternLen + 1) {
            if (i == 0) {
                ret += ' |';
            }
            else {
                ret += pattern.charAt(i - 1) + '|';
            }
            ret += [for (j in 0...wordLen + 1) pad(Std.string(table[i * _rowLen + j]), 3)].join('|') + '\n';
        }
        return ret;
    }

    static function printTables(pattern:String, patternStart:Int, word:String, wordStart:Int):Void {
        pattern = pattern.substr(patternStart);
        word = word.substr(wordStart);
        haxe.Log.trace(printTable(_table, pattern, pattern.length, word, word.length), null);
        haxe.Log.trace(printTable(_arrows, pattern, pattern.length, word, word.length), null);
        haxe.Log.trace(printTable(_diag, pattern, pattern.length, word, word.length), null);
    }

    static function isSeparatorAtPos(value:String, index:Int):Bool {
        if (index < 0 || index >= value.length) {
            return false;
        }
        final code = Strings.getNextCodePoint(value, value.length, index);
        switch code {
            case CharCode.Underline | CharCode.Dash | CharCode.Period | CharCode.Space | CharCode.Slash | CharCode.Backslash
                | CharCode.SingleQuote | CharCode.DoubleQuote | CharCode.Colon | CharCode.DollarSign | CharCode.LessThan
                | CharCode.GreaterThan | CharCode.OpenParen | CharCode.CloseParen | CharCode.OpenSquareBracket
                | CharCode.CloseSquareBracket | CharCode.OpenCurlyBrace | CharCode.CloseCurlyBrace:
                return true;
            default:
                if (Strings.isEmojiImprecise(code)) {
                    return true;
                }
                return false;
        }
    }

    static function isWhitespaceAtPos(value:String, index:Int):Bool {
        if (index < 0 || index >= value.length) {
            return false;
        }
        final code = StringTools.fastCodeAt(value, index);
        return switch code {
            case CharCode.Space | CharCode.Tab: true;
            default: false;
        }
    }

    /**
     * `word[pos] !== wordLow[pos]` (`undefined` out of range).
     */
    static inline function isUpperCaseAtPos(pos:Int, word:String, wordLow:String):Bool {
        return codeAtOrNaN(word, pos) != codeAtOrNaN(wordLow, pos);
    }

    public static function isPatternInWord(patternLow:String, patternPos:Int, patternLen:Int, wordLow:String, wordPos:Int, wordLen:Int, fillMinWordPosArr:Bool = false):Bool {
        while (patternPos < patternLen && wordPos < wordLen) {
            if (codeAtOrNaN(patternLow, patternPos) == codeAtOrNaN(wordLow, wordPos)) {
                if (fillMinWordPosArr) {
                    // Remember the min word position for each pattern position
                    _minWordMatchPos[patternPos] = wordPos;
                }
                patternPos += 1;
            }
            wordPos += 1;
        }
        return patternPos == patternLen; // pattern must be exhausted
    }

    public static function fuzzyScore(pattern:String, patternLow:String, patternStart:Int, word:String, wordLow:String, wordStart:Int, ?options:FuzzyScoreOptions):Null<FuzzyScore> {
        if (options == null) {
            options = FuzzyScoreOptions.defaultOptions;
        }

        final patternLen = pattern.length > _maxLen ? _maxLen : pattern.length;
        final wordLen = word.length > _maxLen ? _maxLen : word.length;

        if (patternStart >= patternLen || wordStart >= wordLen || (patternLen - patternStart) > (wordLen - wordStart)) {
            return null;
        }

        // Run a simple check if the characters of pattern occur
        // (in order) at all in word. If that isn't the case we
        // stop because no match will be possible
        if (!isPatternInWord(patternLow, patternStart, patternLen, wordLow, wordStart, wordLen, true)) {
            return null;
        }

        // Find the max matching word position for each pattern position
        // NOTE: the min matching word position was filled in above, in the `isPatternInWord` call
        _fillInMaxWordMatchPos(patternLen, wordLen, patternStart, wordStart, patternLow, wordLow);

        var row:Int = 1;
        var column:Int = 1;
        var patternPos = patternStart;
        var wordPos = wordStart;

        _hasStrongFirstMatch = false;

        final _table = Filters._table;
        final _diag = Filters._diag;
        final _arrows = Filters._arrows;

        // There will be a match, fill in tables
        row = 1;
        patternPos = patternStart;
        while (patternPos < patternLen) {

            // Reduce search space to possible matching word positions and to possible access from next row
            final minWordMatchPos = _minWordMatchPos[patternPos];
            final maxWordMatchPos = _maxWordMatchPos[patternPos];
            final nextMaxWordMatchPos = (patternPos + 1 < patternLen ? _maxWordMatchPos[patternPos + 1] : wordLen);

            final rowIndex = row * _rowLen;
            final prevRowIndex = rowIndex - _rowLen;

            column = minWordMatchPos - wordStart + 1;
            wordPos = minWordMatchPos;
            while (wordPos < nextMaxWordMatchPos) {

                var score = MIN_SAFE_INTEGER;
                var canComeDiag = false;

                if (wordPos <= maxWordMatchPos) {
                    score = _doScore(
                        pattern, patternLow, patternPos, patternStart,
                        word, wordLow, wordPos, wordLen, wordStart,
                        _diag[prevRowIndex + column - 1] == 0
                    );
                }

                var diagScore = 0;
                // Monaco compares with Number.MAX_SAFE_INTEGER here, which
                // a score never is: the diagonal is always possible.
                if (score != 0x7FFFFFFF) {
                    canComeDiag = true;
                    diagScore = score + _table[prevRowIndex + column - 1];
                }

                final canComeLeft = wordPos > minWordMatchPos;
                final leftScore = canComeLeft ? _table[rowIndex + column - 1] + (_diag[rowIndex + column - 1] > 0 ? -5 : 0) : 0; // penalty for a gap start

                final canComeLeftLeft = wordPos > minWordMatchPos + 1 && _diag[rowIndex + column - 1] > 0;
                final leftLeftScore = canComeLeftLeft ? _table[rowIndex + column - 2] + (_diag[rowIndex + column - 2] > 0 ? -5 : 0) : 0; // penalty for a gap start

                if (canComeLeftLeft && (!canComeLeft || leftLeftScore >= leftScore) && (!canComeDiag || leftLeftScore >= diagScore)) {
                    // always prefer choosing left left to jump over a diagonal because that means a match is earlier in the word
                    _table[rowIndex + column] = leftLeftScore;
                    _arrows[rowIndex + column] = Arrow.LeftLeft;
                    _diag[rowIndex + column] = 0;
                }
                else if (canComeLeft && (!canComeDiag || leftScore >= diagScore)) {
                    // always prefer choosing left since that means a match is earlier in the word
                    _table[rowIndex + column] = leftScore;
                    _arrows[rowIndex + column] = Arrow.Left;
                    _diag[rowIndex + column] = 0;
                }
                else if (canComeDiag) {
                    _table[rowIndex + column] = diagScore;
                    _arrows[rowIndex + column] = Arrow.Diag;
                    _diag[rowIndex + column] = _diag[prevRowIndex + column - 1] + 1;
                }
                else {
                    throw 'not possible';
                }

                column++;
                wordPos++;
            }

            row++;
            patternPos++;
        }

        if (_debug) {
            printTables(pattern, patternStart, word, wordStart);
        }

        if (!_hasStrongFirstMatch && !options.firstMatchCanBeWeak) {
            return null;
        }

        row--;
        column--;

        final result = new FuzzyScore(_table[row * _rowLen + column], wordStart);

        var backwardsDiagLength = 0;
        var maxMatchColumn = 0;

        while (row >= 1) {
            // Find the column where we go diagonally up
            var diagColumn = column;
            do {
                final arrow = _arrows[row * _rowLen + diagColumn];
                if (arrow == Arrow.LeftLeft) {
                    diagColumn = diagColumn - 2;
                }
                else if (arrow == Arrow.Left) {
                    diagColumn = diagColumn - 1;
                }
                else {
                    // found the diagonal
                    break;
                }
            } while (diagColumn >= 1);

            // Overturn the "forwards" decision if keeping the "backwards" diagonal would give a better match
            if (
                backwardsDiagLength > 1 // only if we would have a contiguous match of 3 characters
                && codeAtOrNaN(patternLow, patternStart + row - 1) == codeAtOrNaN(wordLow, wordStart + column - 1) // only if we can do a contiguous match diagonally
                && !isUpperCaseAtPos(diagColumn + wordStart - 1, word, wordLow) // only if the forwards chose diagonal is not an uppercase
                && backwardsDiagLength + 1 > _diagAt(row, diagColumn) // only if our contiguous match would be longer than the "forwards" contiguous match
            ) {
                diagColumn = column;
            }

            if (diagColumn == column) {
                // this is a contiguous match
                backwardsDiagLength++;
            }
            else {
                backwardsDiagLength = 1;
            }

            if (maxMatchColumn == 0) {
                // remember the last matched column
                maxMatchColumn = diagColumn;
            }

            row--;
            column = diagColumn - 1;
            result.push(column);
        }

        if (wordLen - wordStart == patternLen && options.boostFullMatch) {
            // the word matches the pattern with all characters!
            // giving the score a total match boost (to come up ahead other words)
            result[0] += 2;
        }

        // Add 1 penalty for each skipped character in the word
        final skippedCharsCount = maxMatchColumn - patternLen;
        result[0] -= skippedCharsCount;

        return result;
    }

    /**
     * `_diag[row][column]`: a column below 0 is `undefined` in Monaco, and
     * a comparison with it is false (`NaN`). Only the caller's `>` reads it,
     * so the value returned there keeps that comparison false.
     */
    static inline function _diagAt(row:Int, column:Int):Int {
        return column >= 0 ? _diag[row * _rowLen + column] : 0x3FFFFFFF;
    }

    static function _fillInMaxWordMatchPos(patternLen:Int, wordLen:Int, patternStart:Int, wordStart:Int, patternLow:String, wordLow:String):Void {
        var patternPos = patternLen - 1;
        var wordPos = wordLen - 1;
        while (patternPos >= patternStart && wordPos >= wordStart) {
            if (codeAtOrNaN(patternLow, patternPos) == codeAtOrNaN(wordLow, wordPos)) {
                _maxWordMatchPos[patternPos] = wordPos;
                patternPos--;
            }
            wordPos--;
        }
    }

    static function _doScore(
        pattern:String, patternLow:String, patternPos:Int, patternStart:Int,
        word:String, wordLow:String, wordPos:Int, wordLen:Int, wordStart:Int,
        newMatchStart:Bool
    ):Int {
        if (codeAtOrNaN(patternLow, patternPos) != codeAtOrNaN(wordLow, wordPos)) {
            return MIN_SAFE_INTEGER;
        }

        var score = 1;
        var isGapLocation = false;
        if (wordPos == (patternPos - patternStart)) {
            // common prefix: `foobar <-> foobaz`
            //                            ^^^^^
            score = codeAtOrNaN(pattern, patternPos) == codeAtOrNaN(word, wordPos) ? 7 : 5;

        }
        else if (isUpperCaseAtPos(wordPos, word, wordLow) && (wordPos == 0 || !isUpperCaseAtPos(wordPos - 1, word, wordLow))) {
            // hitting upper-case: `foo <-> forOthers`
            //                              ^^ ^
            score = codeAtOrNaN(pattern, patternPos) == codeAtOrNaN(word, wordPos) ? 7 : 5;
            isGapLocation = true;

        }
        else if (isSeparatorAtPos(wordLow, wordPos) && (wordPos == 0 || !isSeparatorAtPos(wordLow, wordPos - 1))) {
            // hitting a separator: `. <-> foo.bar`
            //                                ^
            score = 5;

        }
        else if (isSeparatorAtPos(wordLow, wordPos - 1) || isWhitespaceAtPos(wordLow, wordPos - 1)) {
            // post separator: `foo <-> bar_foo`
            //                              ^^^
            score = 5;
            isGapLocation = true;
        }

        if (score > 1 && patternPos == patternStart) {
            _hasStrongFirstMatch = true;
        }

        if (!isGapLocation) {
            isGapLocation = isUpperCaseAtPos(wordPos, word, wordLow) || isSeparatorAtPos(wordLow, wordPos - 1) || isWhitespaceAtPos(wordLow, wordPos - 1);
        }

        //
        if (patternPos == patternStart) { // first character in pattern
            if (wordPos > wordStart) {
                // the first pattern character would match a word character that is not at the word start
                // so introduce a penalty to account for the gap preceding this match
                score -= isGapLocation ? 3 : 5;
            }
        }
        else {
            if (newMatchStart) {
                // this would be the beginning of a new match (i.e. there would be a gap before this location)
                score += isGapLocation ? 2 : 0;
            }
            else {
                // this is part of a contiguous match, so give it a slight bonus, but do so only if it would not be a preferred gap location
                score += isGapLocation ? 0 : 1;
            }
        }

        if (wordPos + 1 == wordLen) {
            // we always penalize gaps, but this gives unfair advantages to a match that would match the last character in the word
            // so pretend there is a gap after the last character in the word to normalize things
            score -= isGapLocation ? 3 : 5;
        }

        return score;
    }

    //#endregion


    //#region --- graceful ---

    public static function fuzzyScoreGracefulAggressive(pattern:String, lowPattern:String, patternPos:Int, word:String, lowWord:String, wordPos:Int, ?options:FuzzyScoreOptions):Null<FuzzyScore> {
        return fuzzyScoreWithPermutations(pattern, lowPattern, patternPos, word, lowWord, wordPos, true, options);
    }

    public static function fuzzyScoreGraceful(pattern:String, lowPattern:String, patternPos:Int, word:String, lowWord:String, wordPos:Int, ?options:FuzzyScoreOptions):Null<FuzzyScore> {
        return fuzzyScoreWithPermutations(pattern, lowPattern, patternPos, word, lowWord, wordPos, false, options);
    }

    static function fuzzyScoreWithPermutations(pattern:String, lowPattern:String, patternPos:Int, word:String, lowWord:String, wordPos:Int, aggressive:Bool, ?options:FuzzyScoreOptions):Null<FuzzyScore> {
        var top = fuzzyScore(pattern, lowPattern, patternPos, word, lowWord, wordPos, options);

        if (top != null && !aggressive) {
            // when using the original pattern yield a result we`
            // return it unless we are aggressive and try to find
            // a better alignment, e.g. `cno` -> `^co^ns^ole` or `^c^o^nsole`.
            return top;
        }

        if (pattern.length >= 3) {
            // When the pattern is long enough then try a few (max 7)
            // permutations of the pattern to find a better match. The
            // permutations only swap neighbouring characters, e.g
            // `cnoso` becomes `conso`, `cnsoo`, `cnoos`.
            final tries = (7 < pattern.length - 1 ? 7 : pattern.length - 1);
            var movingPatternPos = patternPos + 1;
            while (movingPatternPos < tries) {
                final newPattern = nextTypoPermutation(pattern, movingPatternPos);
                if (newPattern != null) {
                    final candidate = fuzzyScore(newPattern, newPattern.toLowerCase(), patternPos, word, lowWord, wordPos, options);
                    if (candidate != null) {
                        candidate[0] -= 3; // permutation penalty
                        if (top == null || candidate[0] > top[0]) {
                            top = candidate;
                        }
                    }
                }
                movingPatternPos++;
            }
        }

        return top;
    }

    static function nextTypoPermutation(pattern:String, patternPos:Int):Null<String> {

        if (patternPos + 1 >= pattern.length) {
            return null;
        }

        final swap1 = StringTools.fastCodeAt(pattern, patternPos);
        final swap2 = StringTools.fastCodeAt(pattern, patternPos + 1);

        if (swap1 == swap2) {
            return null;
        }

        return pattern.substring(0, patternPos)
            + pattern.charAt(patternPos + 1)
            + pattern.charAt(patternPos)
            + pattern.substring(patternPos + 2);
    }

    //#endregion

}

private enum abstract Arrow(Int) from Int to Int {
    var Diag = 1;
    var Left = 2;
    var LeftLeft = 3;
}

/**
 * An array representing a fuzzy match (Monaco's tuple, the same numbers at
 * the same indices):
 *
 * 0. the score
 * 1. the offset at which matching started
 * 2. `<match_pos_N>`
 * 3. `<match_pos_1>`
 * 4. `<match_pos_0>` etc
 *
 * `score[0]` and `score.score`, `score[1]` and `score.wordStart` are the
 * same; `score[i]` for `i >= 2` are the match positions (relative to
 * `wordStart`, last match first), `score.length` is `2 +` their count.
 */
abstract FuzzyScore(Array<Int>) {

    /**
     * No matches and value `-100`. Shared, like Monaco's: never modify it.
     */
    public static final Default:FuzzyScore = new FuzzyScore(-100, 0);

    public static function isDefault(?score:FuzzyScore):Bool {
        return score == null || (score.length == 2 && score[0] == -100 && score[1] == 0);
    }

    /**
     * `[score, wordStart]`, without matches.
     */
    public inline function new(score:Int, wordStart:Int) {
        this = [score, wordStart];
    }

    /**
     * Monaco's tuple as an array (`[score, wordStart, ...matches]`).
     */
    public static inline function fromArray(array:Array<Int>):FuzzyScore {
        return cast array;
    }

    /**
     * The underlying array (`[score, wordStart, ...matches]`, not a copy).
     */
    public inline function toArray():Array<Int> {
        return this;
    }

    public var score(get, set):Int;
    inline function get_score():Int {
        return this[0];
    }
    inline function set_score(value:Int):Int {
        return this[0] = value;
    }

    public var wordStart(get, never):Int;
    inline function get_wordStart():Int {
        return this[1];
    }

    public var length(get, never):Int;
    inline function get_length():Int {
        return this.length;
    }

    @:arrayAccess inline function get(index:Int):Int {
        return this[index];
    }

    @:arrayAccess inline function set(index:Int, value:Int):Int {
        return this[index] = value;
    }

    /**
     * Appends a match position.
     */
    public inline function push(matchPos:Int):Void {
        this.push(matchPos);
    }

}

/**
 * Monaco's `FuzzyScoreOptions` (an abstract class with two readonly fields,
 * used as an object literal): a struct init class, so that
 * `{firstMatchCanBeWeak: true, boostFullMatch: true}` works where a
 * `FuzzyScoreOptions` is expected.
 */
@:structInit
class FuzzyScoreOptions {

    /**
     * `FuzzyScoreOptions.default` in Monaco (`default` is a Haxe keyword).
     */
    public static final defaultOptions:FuzzyScoreOptions = {boostFullMatch: true, firstMatchCanBeWeak: false};

    /**
     * `{ firstMatchCanBeWeak: true, boostFullMatch: true }`, the options of
     * `matchesFuzzy2` and `anyScore` (shared instead of a literal per call).
     */
    @:noCompletion public static final weakAndBoost:FuzzyScoreOptions = {firstMatchCanBeWeak: true, boostFullMatch: true};

    public final firstMatchCanBeWeak:Bool;

    public final boostFullMatch:Bool;

    public function new(firstMatchCanBeWeak:Bool, boostFullMatch:Bool) {
        this.firstMatchCanBeWeak = firstMatchCanBeWeak;
        this.boostFullMatch = boostFullMatch;
    }

}

typedef FuzzyScorer = (pattern:String, lowPattern:String, patternPos:Int, word:String, lowWord:String, wordPos:Int, ?options:FuzzyScoreOptions) -> Null<FuzzyScore>;

/**
 * Monaco's `LRUCache<string, RegExp>` of `matchesFuzzy`: the least
 * recently used entry is dropped when the cache is over its limit.
 */
private class FuzzyRegExpCache {

    final limit:Int;

    final values:Map<String, RegExp> = new Map();

    final stamps:Map<String, Int> = new Map();

    var size:Int = 0;

    var clock:Int = 0;

    public function new(limit:Int) {
        this.limit = limit;
    }

    public function get(key:String):Null<RegExp> {
        final value = values.get(key);
        if (value != null) {
            stamps.set(key, ++clock);
        }
        return value;
    }

    public function set(key:String, value:RegExp):Void {
        if (!values.exists(key)) {
            size++;
        }
        values.set(key, value);
        stamps.set(key, ++clock);
        if (size > limit) {
            var oldestKey:Null<String> = null;
            var oldestStamp = 0;
            for (k => stamp in stamps) {
                if (oldestKey == null || stamp < oldestStamp) {
                    oldestKey = k;
                    oldestStamp = stamp;
                }
            }
            if (oldestKey != null) {
                values.remove(oldestKey);
                stamps.remove(oldestKey);
                size--;
            }
        }
    }

}

/**
 * The module functions of vscode src/vs/base/common/naturalLanguage/korean.ts
 * (only filters.ts uses them).
 *
 * Gets alternative Korean characters for the character code. This will
 * return the ascii character code(s) that a Hangul character may have been
 * input with using a qwerty layout.
 *
 * This only aims to cover modern (not archaic) Hangul syllables.
 */
class Korean {

    /**
     * @param code The character code to get alternate characters for
     */
    public static function getKoreanAltChars(code:Int):Null<Array<Int>> {
        final result = disassembleKorean(code);
        if (result && codeBufferLength > 0) {
            return [for (i in 0...codeBufferLength) codeBuffer[i]];
        }
        return null;
    }

    // Scratch buffer of `disassembleKorean` (read right after it).
    static var codeBufferLength = 0;
    static final codeBuffer = new Vector<Int>(10);

    /**
     * Fills `codeBuffer`; Monaco returns `codeBuffer.subarray(0, codeBufferLength)`
     * or `undefined`, this returns whether a subarray would be returned.
     */
    static function disassembleKorean(code:Int):Bool {
        codeBufferLength = 0;

        // Initial consonants
        getCodesFromArray(code, modernConsonants, HangulRangeStartCode.InitialConsonant);
        if (codeBufferLength > 0) {
            return true;
        }

        // Vowels
        getCodesFromArray(code, modernVowels, HangulRangeStartCode.Vowel);
        if (codeBufferLength > 0) {
            return true;
        }

        // Final consonants
        getCodesFromArray(code, modernFinalConsonants, HangulRangeStartCode.FinalConsonant);
        if (codeBufferLength > 0) {
            return true;
        }

        // Hangul Compatibility Jamo
        getCodesFromArray(code, compatibilityJamo, HangulRangeStartCode.CompatibilityJamo);
        if (codeBufferLength > 0) {
            return true;
        }

        // Hangul Syllables
        if (code >= 0xAC00 && code <= 0xD7A3) {
            final hangulIndex = code - 0xAC00;
            final vowelAndFinalConsonantProduct = hangulIndex % 588;

            // 0-based starting at 0x1100
            final initialConsonantIndex = Std.int(hangulIndex / 588);
            // 0-based starting at 0x1161
            final vowelIndex = Std.int(vowelAndFinalConsonantProduct / 28);
            // 0-based starting at 0x11A8
            // Subtract 1 as the standard algorithm uses the 0 index to represent no
            // final consonant
            final finalConsonantIndex = vowelAndFinalConsonantProduct % 28 - 1;

            if (initialConsonantIndex < modernConsonants.length) {
                getCodesFromArray(initialConsonantIndex, modernConsonants, 0);
            }
            else if (HangulRangeStartCode.InitialConsonant + initialConsonantIndex - HangulRangeStartCode.CompatibilityJamo < compatibilityJamo.length) {
                getCodesFromArray(HangulRangeStartCode.InitialConsonant + initialConsonantIndex, compatibilityJamo, HangulRangeStartCode.CompatibilityJamo);
            }

            if (vowelIndex < modernVowels.length) {
                getCodesFromArray(vowelIndex, modernVowels, 0);
            }
            else if (HangulRangeStartCode.Vowel + vowelIndex - HangulRangeStartCode.CompatibilityJamo < compatibilityJamo.length) {
                getCodesFromArray(HangulRangeStartCode.Vowel + vowelIndex - HangulRangeStartCode.CompatibilityJamo, compatibilityJamo, HangulRangeStartCode.CompatibilityJamo);
            }

            if (finalConsonantIndex >= 0) {
                if (finalConsonantIndex < modernFinalConsonants.length) {
                    getCodesFromArray(finalConsonantIndex, modernFinalConsonants, 0);
                }
                else if (HangulRangeStartCode.FinalConsonant + finalConsonantIndex - HangulRangeStartCode.CompatibilityJamo < compatibilityJamo.length) {
                    getCodesFromArray(HangulRangeStartCode.FinalConsonant + finalConsonantIndex - HangulRangeStartCode.CompatibilityJamo, compatibilityJamo, HangulRangeStartCode.CompatibilityJamo);
                }
            }

            if (codeBufferLength > 0) {
                return true;
            }
        }
        return false;
    }

    static function getCodesFromArray(code:Int, array:Array<Int>, arrayStartIndex:Int):Void {
        // Verify the code is within the array's range
        if (code >= arrayStartIndex && code < arrayStartIndex + array.length) {
            addCodesToBuffer(array[code - arrayStartIndex]);
        }
    }

    static function addCodesToBuffer(codes:Int):Void {
        // NUL is ignored, this is used for archaic characters to avoid using a Map
        // for the data
        if (codes == 0) {
            return;
        }
        // Number stored in format: OptionalThirdCode << 16 | OptionalSecondCode << 8 | Code
        codeBuffer[codeBufferLength++] = codes & 0xFF;
        if ((codes >> 8) != 0) {
            codeBuffer[codeBufferLength++] = (codes >> 8) & 0xFF;
        }
        if ((codes >> 16) != 0) {
            codeBuffer[codeBufferLength++] = (codes >> 16) & 0xFF;
        }
    }

    static inline function combo(first:Int, second:Int):Int {
        return second << 8 | first;
    }

    /**
     * Hangul Jamo - Modern consonants #1 (range U+1100..U+1112).
     */
    static final modernConsonants:Array<Int> = [
        'r'.code, // U+3131
        'R'.code, // U+3132
        's'.code, // U+3134
        'e'.code, // U+3137
        'E'.code, // U+3138
        'f'.code, // U+3139
        'a'.code, // U+3141
        'q'.code, // U+3142
        'Q'.code, // U+3143
        't'.code, // U+3145
        'T'.code, // U+3146
        'd'.code, // U+3147
        'w'.code, // U+3148
        'W'.code, // U+3149
        'c'.code, // U+314A
        'z'.code, // U+314B
        'x'.code, // U+314C
        'v'.code, // U+314D
        'g'.code, // U+314E
    ];

    /**
     * Hangul Jamo - Modern Vowels (range U+1161..U+1175).
     */
    static final modernVowels:Array<Int> = [
        'k'.code,              // U+314F
        'o'.code,              // U+3150
        'i'.code,              // U+3151
        'O'.code,              // U+3152
        'j'.code,              // U+3153
        'p'.code,              // U+3154
        'u'.code,              // U+3155
        'P'.code,              // U+3156
        'h'.code,              // U+3157
        combo('h'.code, 'k'.code), // U+3158
        combo('h'.code, 'o'.code), // U+3159
        combo('h'.code, 'l'.code), // U+315A
        'y'.code,              // U+315B
        'n'.code,              // U+315C
        combo('n'.code, 'j'.code), // U+315D
        combo('n'.code, 'p'.code), // U+315E
        combo('n'.code, 'l'.code), // U+315F
        'b'.code,              // U+3160
        'm'.code,              // U+3161
        combo('m'.code, 'l'.code), // U+3162
        'l'.code,              // U+3163
    ];

    /**
     * Hangul Jamo - Modern Consonants #2 (range U+11A8..U+11C2).
     */
    static final modernFinalConsonants:Array<Int> = [
        'r'.code,              // U+3131
        'R'.code,              // U+3132
        combo('r'.code, 't'.code), // U+3133
        's'.code,              // U+3134
        combo('s'.code, 'w'.code), // U+3135
        combo('s'.code, 'g'.code), // U+3136
        'e'.code,              // U+3137
        'f'.code,              // U+3139
        combo('f'.code, 'r'.code), // U+313A
        combo('f'.code, 'a'.code), // U+313B
        combo('f'.code, 'q'.code), // U+313C
        combo('f'.code, 't'.code), // U+313D
        combo('f'.code, 'x'.code), // U+313E
        combo('f'.code, 'v'.code), // U+313F
        combo('f'.code, 'g'.code), // U+3140
        'a'.code,              // U+3141
        'q'.code,              // U+3142
        combo('q'.code, 't'.code), // U+3144
        't'.code,              // U+3145
        'T'.code,              // U+3146
        'd'.code,              // U+3147
        'w'.code,              // U+3148
        'c'.code,              // U+314A
        'z'.code,              // U+314B
        'x'.code,              // U+314C
        'v'.code,              // U+314D
        'g'.code,              // U+314E
    ];

    /**
     * Hangul Compatibility Jamo (range U+3131..U+318F). This range includes
     * archaic jamo which we don't consider: everything after the Hangul
     * Filler (U+3164) is left out.
     */
    static final compatibilityJamo:Array<Int> = [
        'r'.code,              // U+3131
        'R'.code,              // U+3132
        combo('r'.code, 't'.code), // U+3133
        's'.code,              // U+3134
        combo('s'.code, 'w'.code), // U+3135
        combo('s'.code, 'g'.code), // U+3136
        'e'.code,              // U+3137
        'E'.code,              // U+3138
        'f'.code,              // U+3139
        combo('f'.code, 'r'.code), // U+313A
        combo('f'.code, 'a'.code), // U+313B
        combo('f'.code, 'q'.code), // U+313C
        combo('f'.code, 't'.code), // U+313D
        combo('f'.code, 'x'.code), // U+313E
        combo('f'.code, 'v'.code), // U+313F
        combo('f'.code, 'g'.code), // U+3140
        'a'.code,              // U+3141
        'q'.code,              // U+3142
        'Q'.code,              // U+3143
        combo('q'.code, 't'.code), // U+3144
        't'.code,              // U+3145
        'T'.code,              // U+3146
        'd'.code,              // U+3147
        'w'.code,              // U+3148
        'W'.code,              // U+3149
        'c'.code,              // U+314A
        'z'.code,              // U+314B
        'x'.code,              // U+314C
        'v'.code,              // U+314D
        'g'.code,              // U+314E
        'k'.code,              // U+314F
        'o'.code,              // U+3150
        'i'.code,              // U+3151
        'O'.code,              // U+3152
        'j'.code,              // U+3153
        'p'.code,              // U+3154
        'u'.code,              // U+3155
        'P'.code,              // U+3156
        'h'.code,              // U+3157
        combo('h'.code, 'k'.code), // U+3158
        combo('h'.code, 'o'.code), // U+3159
        combo('h'.code, 'l'.code), // U+315A
        'y'.code,              // U+315B
        'n'.code,              // U+315C
        combo('n'.code, 'j'.code), // U+315D
        combo('n'.code, 'p'.code), // U+315E
        combo('n'.code, 'l'.code), // U+315F
        'b'.code,              // U+3160
        'm'.code,              // U+3161
        combo('m'.code, 'l'.code), // U+3162
        'l'.code,              // U+3163
        // HF: Hangul Filler (everything after this is archaic)
    ];

}

private enum abstract HangulRangeStartCode(Int) from Int to Int {
    var InitialConsonant = 0x1100;
    var Vowel = 0x1161;
    var FinalConsonant = 0x11A8;
    var CompatibilityJamo = 0x3131;
}
