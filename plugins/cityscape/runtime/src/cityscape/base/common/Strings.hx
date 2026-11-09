// Ported from vscode src/vs/base/common/strings.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of strings.ts. Only what the ported code needs so far;
 * add functions here as modules need them, keeping Monaco's names.
 *
 * Strings are Haxe `String`s indexed in UTF-16 code units, like JavaScript.
 * The regular expressions of strings.ts that only test character ranges are
 * written as loops over the code units, which give the same answers on every
 * target.
 */
class Strings {

    /**
     * Whether `charCode` is a UTF-16 high (leading) surrogate.
     */
    public static inline function isHighSurrogate(charCode:Int):Bool {
        return (0xD800 <= charCode && charCode <= 0xDBFF);
    }

    /**
     * Whether `charCode` is a UTF-16 low (trailing) surrogate.
     */
    public static inline function isLowSurrogate(charCode:Int):Bool {
        return (0xDC00 <= charCode && charCode <= 0xDFFF);
    }

    /**
     * The code point of a surrogate pair.
     */
    public static inline function computeCodePoint(highSurrogate:Int, lowSurrogate:Int):Int {
        return ((highSurrogate - 0xD800) << 10) + (lowSurrogate - 0xDC00) + 0x10000;
    }

    /**
     * Returns true if `str` contains only basic ASCII characters in the range
     * 32 - 126 (including 32 and 126) or \n, \r, \t
     * (`/^[\t\n\r\x20-\x7E]*$/`).
     */
    public static function isBasicASCII(str:String):Bool {
        for (i in 0...str.length) {
            final c = StringTools.fastCodeAt(str, i);
            if (!(c == CharCode.Tab || c == CharCode.LineFeed || c == CharCode.CarriageReturn || (c >= 0x20 && c <= 0x7E))) {
                return false;
            }
        }
        return true;
    }

    /**
     * Returns true if `str` contains any Unicode character that is classified
     * as "R" or "AL" (the code unit ranges of Monaco's generated `CONTAINS_RTL`
     * regular expression).
     */
    public static function containsRTL(str:String):Bool {
        final len = str.length;
        var i = 0;
        while (i < len) {
            final c = StringTools.fastCodeAt(str, i);
            if (isRTLBmp(c)) {
                return true;
            }
            if (i + 1 < len && (c == 0xD802 || c == 0xD803 || c == 0xD83A || c == 0xD83B)) {
                final d = StringTools.fastCodeAt(str, i + 1);
                if (isRTLAstral(c, d)) {
                    return true;
                }
            }
            i++;
        }
        return false;
    }

    static function isRTLBmp(c:Int):Bool {
        if (c < 0x05BE)
            return false;
        return c == 0x05BE || c == 0x05C0 || c == 0x05C3 || c == 0x05C6 || (c >= 0x05D0 && c <= 0x05F4) || c == 0x0608
            || c == 0x060B || c == 0x060D || (c >= 0x061B && c <= 0x064A) || (c >= 0x066D && c <= 0x066F) || (c >= 0x0671 && c <= 0x06D5)
            || c == 0x06E5 || c == 0x06E6 || c == 0x06EE || c == 0x06EF || (c >= 0x06FA && c <= 0x0710) || (c >= 0x0712 && c <= 0x072F)
            || (c >= 0x074D && c <= 0x07A5) || (c >= 0x07B1 && c <= 0x07EA) || c == 0x07F4 || c == 0x07F5 || (c >= 0x07FA && c <= 0x0815)
            || c == 0x081A || c == 0x0824 || c == 0x0828 || (c >= 0x0830 && c <= 0x0858) || (c >= 0x085E && c <= 0x088E)
            || (c >= 0x08A0 && c <= 0x08C9) || c == 0x200F || c == 0xFB1D || (c >= 0xFB1F && c <= 0xFB28) || (c >= 0xFB2A && c <= 0xFD3D)
            || (c >= 0xFD50 && c <= 0xFDC7) || (c >= 0xFDF0 && c <= 0xFDFC) || (c >= 0xFE70 && c <= 0xFEFC);
    }

    static function isRTLAstral(high:Int, d:Int):Bool {
        return switch high {
            case 0xD802:
                (d >= 0xDC00 && d <= 0xDD1B) || (d >= 0xDD20 && d <= 0xDE00) || (d >= 0xDE10 && d <= 0xDE35) || (d >= 0xDE40 && d <= 0xDEE4)
                    || (d >= 0xDEEB && d <= 0xDF35) || (d >= 0xDF40 && d <= 0xDFFF);
            case 0xD803:
                (d >= 0xDC00 && d <= 0xDD23) || (d >= 0xDE80 && d <= 0xDEA9) || (d >= 0xDEAD && d <= 0xDF45) || (d >= 0xDF51 && d <= 0xDF81)
                    || (d >= 0xDF86 && d <= 0xDFF6);
            case 0xD83A:
                (d >= 0xDC00 && d <= 0xDCCF) || (d >= 0xDD00 && d <= 0xDD43) || (d >= 0xDD4B && d <= 0xDFFF);
            case 0xD83B:
                (d >= 0xDC00 && d <= 0xDEBB);
            case _:
                false;
        }
    }

    /**
     * Returns true if `str` contains unusual line terminators, like LS or PS
     * (`/[  ]/`).
     */
    public static function containsUnusualLineTerminators(str:String):Bool {
        for (i in 0...str.length) {
            final c = StringTools.fastCodeAt(str, i);
            if (c == 0x2028 || c == 0x2029) {
                return true;
            }
        }
        return false;
    }

    /**
     * The source of Monaco's `UNUSUAL_LINE_TERMINATORS` regular expression
     * (`/[  ]/`): LINE SEPARATOR (LS) or PARAGRAPH SEPARATOR (PS).
     */
    public static inline final UNUSUAL_LINE_TERMINATORS_SOURCE = '[\\u2028\\u2029]';

    /**
     * `String.fromCharCode(CharCode.UTF8_BOM)`.
     */
    public static final UTF8_BOM_CHARACTER:String = String.fromCharCode(CharCode.UTF8_BOM);

    public static function startsWithUTF8BOM(str:Null<String>):Bool {
        return (str != null && str.length > 0 && StringTools.fastCodeAt(str, 0) == CharCode.UTF8_BOM);
    }

    public static function stripUTF8BOM(str:String):String {
        return startsWithUTF8BOM(str) ? str.substr(1) : str;
    }

    /**
     * True when `str` is null, empty or only whitespace (`str.trim()` is
     * empty, with JavaScript's whitespace set).
     */
    public static function isFalsyOrWhitespace(str:Null<String>):Bool {
        if (str == null || str.length == 0) {
            return true;
        }
        for (i in 0...str.length) {
            if (!isJsWhitespace(StringTools.fastCodeAt(str, i))) {
                return false;
            }
        }
        return true;
    }

    /**
     * Whether `c` is a whitespace or line terminator for JavaScript's
     * `String.prototype.trim` and the `\s` class of regular expressions.
     */
    public static function isJsWhitespace(c:Int):Bool {
        return switch c {
            case 0x09 | 0x0A | 0x0B | 0x0C | 0x0D | 0x20 | 0xA0 | 0x1680 | 0x2028 | 0x2029 | 0x202F | 0x205F | 0x3000 | 0xFEFF: true;
            case _: (c >= 0x2000 && c <= 0x200A);
        }
    }

    /**
     * Escapes regular expression characters in a given string
     * (`value.replace(/[\\\{\}\*\+\?\|\^\$\.\[\]\(\)]/g, '\\$&')`).
     */
    public static function escapeRegExpCharacters(value:String):String {
        final buf = new StringBuf();
        for (i in 0...value.length) {
            final c = StringTools.fastCodeAt(value, i);
            switch c {
                case '\\'.code | '{'.code | '}'.code | '*'.code | '+'.code | '?'.code | '|'.code | '^'.code | '$'.code | '.'.code | '['.code | ']'.code | '('.code | ')'.code:
                    buf.addChar('\\'.code);
                case _:
            }
            buf.addChar(c);
        }
        return buf.toString();
    }

    /**
     * Counts how often `substr` occurs inside `value`.
     */
    public static function count(value:String, substr:String):Int {
        var result = 0;
        var index = value.indexOf(substr);
        while (index != -1) {
            result++;
            index = value.indexOf(substr, index + substr.length);
        }
        return result;
    }

    /**
     * Creates the regular expression of a search (`strings.createRegExp`).
     * Throws when `searchString` is empty or is not a valid regular
     * expression.
     */
    public static function createRegExp(searchString:String, isRegex:Bool, ?options:RegExpOptions):RegExp {
        if (searchString == null || searchString.length == 0) {
            throw 'Cannot create regex from empty string';
        }
        if (options == null) {
            options = {};
        }
        if (!isRegex) {
            searchString = escapeRegExpCharacters(searchString);
        }
        if (options.wholeWord == true) {
            // `/\B/.test(c)` is true when the character is not a word character
            if (!isNotWordBoundaryChar(searchString.charAt(0))) {
                searchString = '\\b' + searchString;
            }
            if (!isNotWordBoundaryChar(searchString.charAt(searchString.length - 1))) {
                searchString = searchString + '\\b';
            }
        }
        var modifiers = '';
        if (options.global == true) {
            modifiers += 'g';
        }
        if (options.matchCase != true) {
            modifiers += 'i';
        }
        if (options.multiline == true) {
            modifiers += 'm';
        }
        if (options.unicode == true) {
            modifiers += 'u';
        }

        return new RegExp(searchString, modifiers);
    }

    /**
     * `/\B/.test(c)` on a one character string: true when the character is
     * not an ASCII word character (`[A-Za-z0-9_]`), or when it is empty.
     */
    static function isNotWordBoundaryChar(c:String):Bool {
        if (c.length == 0) {
            return true;
        }
        return !RegExp.isAsciiWordChar(StringTools.fastCodeAt(c, 0));
    }

    public static function regExpLeadsToEndlessLoop(regexp:RegExp):Bool {
        // Exit early if it's one of these special cases which are meant to match
        // against an empty string
        if (regexp.source == '^' || regexp.source == '^$' || regexp.source == '$' || regexp.source == '^\\s*$') {
            return false;
        }

        // We check against an empty string. If the regular expression doesn't advance
        // (e.g. ends in an endless loop) it will match an empty string.
        final match = regexp.exec('');
        return (match != null && regexp.lastIndex == 0);
    }

    /**
     * `str.split(/\r\n|\r|\n/)`.
     */
    public static function splitLines(str:String):Array<String> {
        final result:Array<String> = [];
        var start = 0;
        var i = 0;
        final len = str.length;
        while (i < len) {
            final c = StringTools.fastCodeAt(str, i);
            if (c == CharCode.CarriageReturn) {
                result.push(str.substring(start, i));
                if (i + 1 < len && StringTools.fastCodeAt(str, i + 1) == CharCode.LineFeed) {
                    i++;
                }
                start = i + 1;
            }
            else if (c == CharCode.LineFeed) {
                result.push(str.substring(start, i));
                start = i + 1;
            }
            i++;
        }
        result.push(str.substring(start, len));
        return result;
    }

    /**
     * `str.replace(/\r\n|\r|\n/g, eol)`.
     */
    public static function replaceLineBreaks(str:String, eol:String):String {
        final len = str.length;
        var i = 0;
        // Most strings have nothing to replace (or are already normalized)
        var buf:Null<StringBuf> = null;
        var start = 0;
        while (i < len) {
            final c = StringTools.fastCodeAt(str, i);
            if (c == CharCode.CarriageReturn || c == CharCode.LineFeed) {
                var end = i + 1;
                if (c == CharCode.CarriageReturn && end < len && StringTools.fastCodeAt(str, end) == CharCode.LineFeed) {
                    end++;
                }
                final same = (end - i == eol.length) && (eol.length == 1 ? StringTools.fastCodeAt(eol, 0) == c : c == CharCode.CarriageReturn);
                if (!same) {
                    if (buf == null) {
                        buf = new StringBuf();
                    }
                    buf.addSub(str, start, i - start);
                    buf.add(eol);
                    start = end;
                }
                i = end;
                continue;
            }
            i++;
        }
        if (buf == null) {
            return str;
        }
        buf.addSub(str, start, len - start);
        return buf.toString();
    }

    /**
     * `str.replace(/(\r\n|\r|\n)$/, '')`: removes one trailing line break.
     */
    public static function removeTrailingLineBreak(str:String):String {
        final len = str.length;
        if (len == 0) {
            return str;
        }
        final last = StringTools.fastCodeAt(str, len - 1);
        if (last == CharCode.LineFeed) {
            if (len >= 2 && StringTools.fastCodeAt(str, len - 2) == CharCode.CarriageReturn) {
                return str.substring(0, len - 2);
            }
            return str.substring(0, len - 1);
        }
        if (last == CharCode.CarriageReturn) {
            return str.substring(0, len - 1);
        }
        return str;
    }

    /**
     * Returns first index of the string that is not whitespace.
     * If string is empty or contains only whitespaces, returns -1
     */
    public static function firstNonWhitespaceIndex(str:String):Int {
        for (i in 0...str.length) {
            final chCode = StringTools.fastCodeAt(str, i);
            if (chCode != CharCode.Space && chCode != CharCode.Tab) {
                return i;
            }
        }
        return -1;
    }

    /**
     * Returns the leading whitespace of the string.
     * If the string contains only whitespaces, returns entire string
     */
    public static function getLeadingWhitespace(str:String, start:Int = 0, end:Int = -1):String {
        if (end == -1) {
            end = str.length;
        }
        for (i in start...end) {
            final chCode = StringTools.fastCodeAt(str, i);
            if (chCode != CharCode.Space && chCode != CharCode.Tab) {
                return str.substring(start, i);
            }
        }
        return str.substring(start, end);
    }

    /**
     * Returns last index of the string that is not whitespace.
     * If string is empty or contains only whitespaces, returns -1
     * (`startIndex` defaults to `str.length - 1`).
     */
    public static function lastNonWhitespaceIndex(str:String, ?startIndex:Int):Int {
        var i:Int = (startIndex == null ? str.length - 1 : startIndex);
        while (i >= 0) {
            final chCode = StringTools.fastCodeAt(str, i);
            if (chCode != CharCode.Space && chCode != CharCode.Tab) {
                return i;
            }
            i--;
        }
        return -1;
    }

    /**
     * get the code point that begins at offset `offset`
     * (`NaN` in JavaScript when out of range, -1 here).
     */
    public static function getNextCodePoint(str:String, len:Int, offset:Int):Int {
        if (offset < 0 || offset >= len) {
            return -1;
        }
        final charCode = StringTools.fastCodeAt(str, offset);
        if (isHighSurrogate(charCode) && offset + 1 < len) {
            final nextCharCode = StringTools.fastCodeAt(str, offset + 1);
            if (isLowSurrogate(nextCharCode)) {
                return computeCodePoint(charCode, nextCharCode);
            }
        }
        return charCode;
    }

    // Added with the cursor (step 3, worker cs3-cursor): graphemes and
    // character classes of strings.ts

    /**
     * get the code point that ends right before offset `offset`
     * (`NaN` in JavaScript when out of range, -1 here).
     */
    public static function getPrevCodePoint(str:String, offset:Int):Int {
        if (offset < 1 || offset > str.length) {
            return -1;
        }
        final charCode = StringTools.fastCodeAt(str, offset - 1);
        if (isLowSurrogate(charCode) && offset > 1) {
            final prevCharCode = StringTools.fastCodeAt(str, offset - 2);
            if (isHighSurrogate(prevCharCode)) {
                return computeCodePoint(prevCharCode, charCode);
            }
        }
        return charCode;
    }

    /**
     * The length (in UTF-16 code units) of the grapheme cluster starting at
     * `initialOffset`.
     */
    public static function nextCharLength(str:String, initialOffset:Int):Int {
        final iterator = new GraphemeIterator(str, initialOffset);
        return iterator.nextGraphemeLength();
    }

    /**
     * The length (in UTF-16 code units) of the grapheme cluster ending at
     * `initialOffset`.
     */
    public static function prevCharLength(str:String, initialOffset:Int):Int {
        final iterator = new GraphemeIterator(str, initialOffset);
        return iterator.prevGraphemeLength();
    }

    /**
     * The `[start, end]` offsets of the grapheme cluster containing `offset`.
     */
    public static function getCharContainingOffset(str:String, offset:Int):Array<Int> {
        if (offset > 0 && isLowSurrogate(StringTools.fastCodeAt(str, offset))) {
            offset--;
        }
        final endOffset = offset + nextCharLength(str, offset);
        final startOffset = endOffset - prevCharLength(str, endOffset);
        return [startOffset, endOffset];
    }

    /**
     * The number of grapheme clusters of `str`.
     */
    public static function charCount(str:String):Int {
        final iterator = new GraphemeIterator(str);
        var length = 0;
        while (!iterator.eol()) {
            length++;
            iterator.nextGraphemeLength();
        }
        return length;
    }

    public static inline function isAsciiDigit(code:Int):Bool {
        return code >= (CharCode.Digit0 : Int) && code <= (CharCode.Digit9 : Int);
    }

    public static inline function isLowerAsciiLetter(code:Int):Bool {
        return code >= (CharCode.a : Int) && code <= (CharCode.z : Int);
    }

    public static inline function isUpperAsciiLetter(code:Int):Bool {
        return code >= (CharCode.A : Int) && code <= (CharCode.Z : Int);
    }

    public static function getGraphemeBreakType(codePoint:Int):GraphemeBreakType {
        final graphemeBreakTree = GraphemeBreakTree.getInstance();
        return graphemeBreakTree.getGraphemeBreakType(codePoint);
    }

    @:allow(cityscape.base.common.GraphemeIterator)
    static function breakBetweenGraphemeBreakType(breakTypeA:GraphemeBreakType, breakTypeB:GraphemeBreakType):Bool {
        // http://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundary_Rules

        // !!! Let's make the common case a bit faster
        if (breakTypeA == GraphemeBreakType.Other) {
            // see https://www.unicode.org/Public/13.0.0/ucd/auxiliary/GraphemeBreakTest-13.0.0d10.html#table
            return (breakTypeB != GraphemeBreakType.Extend && breakTypeB != GraphemeBreakType.SpacingMark);
        }

        // Do not break between a CR and LF. Otherwise, break before and after controls.
        // GB3                                        CR x LF
        // GB4                       (Control | CR | LF) /
        // GB5                                           / (Control | CR | LF)
        if (breakTypeA == GraphemeBreakType.CR) {
            if (breakTypeB == GraphemeBreakType.LF) {
                return false; // GB3
            }
        }
        if (breakTypeA == GraphemeBreakType.Control || breakTypeA == GraphemeBreakType.CR || breakTypeA == GraphemeBreakType.LF) {
            return true; // GB4
        }
        if (breakTypeB == GraphemeBreakType.Control || breakTypeB == GraphemeBreakType.CR || breakTypeB == GraphemeBreakType.LF) {
            return true; // GB5
        }

        // Do not break Hangul syllable sequences.
        // GB6                                         L x (L | V | LV | LVT)
        // GB7                                  (LV | V) x (V | T)
        // GB8                                 (LVT | T) x T
        if (breakTypeA == GraphemeBreakType.L) {
            if (breakTypeB == GraphemeBreakType.L || breakTypeB == GraphemeBreakType.V || breakTypeB == GraphemeBreakType.LV || breakTypeB == GraphemeBreakType.LVT) {
                return false; // GB6
            }
        }
        if (breakTypeA == GraphemeBreakType.LV || breakTypeA == GraphemeBreakType.V) {
            if (breakTypeB == GraphemeBreakType.V || breakTypeB == GraphemeBreakType.T) {
                return false; // GB7
            }
        }
        if (breakTypeA == GraphemeBreakType.LVT || breakTypeA == GraphemeBreakType.T) {
            if (breakTypeB == GraphemeBreakType.T) {
                return false; // GB8
            }
        }

        // Do not break before extending characters or ZWJ.
        // GB9                                           x (Extend | ZWJ)
        if (breakTypeB == GraphemeBreakType.Extend || breakTypeB == GraphemeBreakType.ZWJ) {
            return false; // GB9
        }

        // The GB9a and GB9b rules only apply to extended grapheme clusters:
        // Do not break before SpacingMarks, or after Prepend characters.
        // GB9a                                          x SpacingMark
        // GB9b                                  Prepend x
        if (breakTypeB == GraphemeBreakType.SpacingMark) {
            return false; // GB9a
        }
        if (breakTypeA == GraphemeBreakType.Prepend) {
            return false; // GB9b
        }

        // Do not break within emoji modifier sequences or emoji zwj sequences.
        // GB11    \p{Extended_Pictographic} Extend* ZWJ x \p{Extended_Pictographic}
        if (breakTypeA == GraphemeBreakType.ZWJ && breakTypeB == GraphemeBreakType.Extended_Pictographic) {
            // Note: we are not implementing the rule entirely here to avoid introducing states
            return false; // GB11
        }

        // GB12                          sot (RI RI)* RI x RI
        // GB13                        [^RI] (RI RI)* RI x RI
        if (breakTypeA == GraphemeBreakType.Regional_Indicator && breakTypeB == GraphemeBreakType.Regional_Indicator) {
            // Note: we are not implementing the rule entirely here to avoid introducing states
            return false; // GB12 & GB13
        }

        // GB999                                     Any / Any
        return true;
    }

    /**
     * Computes the offset after performing a left delete on the given string,
     * while considering unicode grapheme/emoji rules.
     */
    public static function getLeftDeleteOffset(offset:Int, str:String):Int {
        if (offset == 0) {
            return 0;
        }

        // Try to delete emoji part.
        final emojiOffset = getOffsetBeforeLastEmojiComponent(offset, str);
        if (emojiOffset != null) {
            return emojiOffset;
        }

        // Otherwise, just skip a single code point.
        final iterator = new CodePointIterator(str, offset);
        iterator.prevCodePoint();
        return iterator.offset;
    }

    static function getOffsetBeforeLastEmojiComponent(initialOffset:Int, str:String):Null<Int> {
        // See https://www.unicode.org/reports/tr51/tr51-14.html#EBNF_and_Regex for the
        // structure of emojis.
        final iterator = new CodePointIterator(str, initialOffset);
        var codePoint = iterator.prevCodePoint();

        // Skip modifiers
        while ((isEmojiModifier(codePoint) || codePoint == EMOJI_VARIANT_SELECTOR || codePoint == ENCLOSING_KEY_CAP)) {
            if (iterator.offset == 0) {
                // Cannot skip modifier, no preceding emoji base.
                return null;
            }
            codePoint = iterator.prevCodePoint();
        }

        // Expect base emoji
        if (!isEmojiImprecise(codePoint)) {
            // Unexpected code point, not a valid emoji.
            return null;
        }

        var resultOffset = iterator.offset;

        if (resultOffset > 0) {
            // Skip optional ZWJ code points that combine multiple emojis.
            // In theory, we should check if that ZWJ actually combines multiple emojis
            // to prevent deleting ZWJs in situations we didn't account for.
            final optionalZwjCodePoint = iterator.prevCodePoint();
            if (optionalZwjCodePoint == ZWJ) {
                resultOffset = iterator.offset;
            }
        }

        return resultOffset;
    }

    static inline function isEmojiModifier(codePoint:Int):Bool {
        return 0x1F3FB <= codePoint && codePoint <= 0x1F3FF;
    }

    // strings.ts `CodePoint`
    static inline final ZWJ = 0x200D;
    /**
     * Variation Selector-16 (VS16)
     */
    static inline final EMOJI_VARIANT_SELECTOR = 0xFE0F;
    /**
     * Combining Enclosing Keycap
     */
    static inline final ENCLOSING_KEY_CAP = 0x20E3;

    /**
     * Escapes the characters of an HTML attribute value.
     */
    public static function htmlAttributeEncodeValue(value:String):String {
        final buf = new StringBuf();
        for (i in 0...value.length) {
            final c = StringTools.fastCodeAt(value, i);
            switch c {
                case '<'.code: buf.add('&lt;');
                case '>'.code: buf.add('&gt;');
                case '"'.code: buf.add('&quot;');
                case '\''.code: buf.add('&apos;');
                case '&'.code: buf.add('&amp;');
                case _: buf.addChar(c);
            }
        }
        return buf.toString();
    }

    /**
     * A one character hash of `n` (`a`-`z`, `A`-`Z`, `0`-`9` and then longer
     * strings).
     */
    public static function singleLetterHash(n:Int):String {
        final LETTERS_CNT = ('Z'.code - 'A'.code + 1);

        n = n % (2 * LETTERS_CNT);

        if (n < LETTERS_CNT) {
            return String.fromCharCode('a'.code + n);
        }

        return String.fromCharCode('A'.code + n - LETTERS_CNT);
    }

    // Added with the view (step 2, worker cs2-view)

    /**
     * A cheap trick to better support wrapping of wide characters: treat
     * them as 2 columns (CJK blocks, Hangul syllables, fullwidth forms).
     */
    public static inline function isFullWidthCharacter(charCode:Int):Bool {
        return (
            (charCode >= 0x2E80 && charCode <= 0xD7AF)
            || (charCode >= 0xF900 && charCode <= 0xFAFF)
            || (charCode >= 0xFF01 && charCode <= 0xFF5E)
        );
    }

    /**
     * A fast function (therefore imprecise) to check if code points are emojis.
     */
    public static function isEmojiImprecise(x:Int):Bool {
        return (
            (x >= 0x1F1E6 && x <= 0x1F1FF) || (x == 8986) || (x == 8987) || (x == 9200)
            || (x == 9203) || (x >= 9728 && x <= 10175) || (x == 11088) || (x == 11093)
            || (x >= 127744 && x <= 128591) || (x >= 128640 && x <= 128764)
            || (x >= 128992 && x <= 129008) || (x >= 129280 && x <= 129535)
            || (x >= 129648 && x <= 129782)
        );
    }

    /**
     * @returns the length of the common prefix of the two strings.
     */
    public static function commonPrefixLength(a:String, b:String):Int {
        final len = (a.length < b.length ? a.length : b.length);
        for (i in 0...len) {
            if (StringTools.fastCodeAt(a, i) != StringTools.fastCodeAt(b, i)) {
                return i;
            }
        }
        return len;
    }

    /**
     * @returns the length of the common suffix of the two strings.
     */
    public static function commonSuffixLength(a:String, b:String):Int {
        final len = (a.length < b.length ? a.length : b.length);
        final aLastIndex = a.length - 1;
        final bLastIndex = b.length - 1;
        for (i in 0...len) {
            if (StringTools.fastCodeAt(a, aLastIndex - i) != StringTools.fastCodeAt(b, bLastIndex - i)) {
                return i;
            }
        }
        return len;
    }

    // Added with the filters (step 5, worker cs4-lang): helpers of
    // filters.ts

    /**
     * `pattern.replace(/[\-\\\{\}\+\?\|\^\$\.\,\[\]\(\)\#\s]/g, '\\$&').replace(/[\*]/g, '.*')`,
     * written as a loop (`\s` is JavaScript's whitespace set).
     */
    public static function convertSimple2RegExpPattern(pattern:String):String {
        final buf = new StringBuf();
        for (i in 0...pattern.length) {
            final c = StringTools.fastCodeAt(pattern, i);
            switch c {
                case '-'.code | '\\'.code | '{'.code | '}'.code | '+'.code | '?'.code | '|'.code | '^'.code | '$'.code | '.'.code | ','.code | '['.code | ']'.code | '('.code | ')'.code | '#'.code:
                    buf.addChar('\\'.code);
                    buf.addChar(c);
                case '*'.code:
                    buf.add('.*');
                case _:
                    if (isJsWhitespace(c)) {
                        buf.addChar('\\'.code);
                    }
                    buf.addChar(c);
            }
        }
        return buf.toString();
    }

    public static function compareSubstring(a:String, b:String, aStart:Int = 0, ?aEnd:Int, bStart:Int = 0, ?bEnd:Int):Int {
        if (aEnd == null) {
            aEnd = a.length;
        }
        if (bEnd == null) {
            bEnd = b.length;
        }
        while (aStart < aEnd && bStart < bEnd) {
            final codeA = StringTools.fastCodeAt(a, aStart);
            final codeB = StringTools.fastCodeAt(b, bStart);
            if (codeA < codeB) {
                return -1;
            }
            else if (codeA > codeB) {
                return 1;
            }
            aStart++;
            bStart++;
        }
        final aLen = aEnd - aStart;
        final bLen = bEnd - bStart;
        if (aLen < bLen) {
            return -1;
        }
        else if (aLen > bLen) {
            return 1;
        }
        return 0;
    }

    public static function compareIgnoreCase(a:String, b:String):Int {
        return compareSubstringIgnoreCase(a, b, 0, a.length, 0, b.length);
    }

    public static function compareSubstringIgnoreCase(a:String, b:String, aStart:Int = 0, ?aEnd:Int, bStart:Int = 0, ?bEnd:Int):Int {
        if (aEnd == null) {
            aEnd = a.length;
        }
        if (bEnd == null) {
            bEnd = b.length;
        }
        while (aStart < aEnd && bStart < bEnd) {

            var codeA = StringTools.fastCodeAt(a, aStart);
            var codeB = StringTools.fastCodeAt(b, bStart);

            if (codeA == codeB) {
                // equal
                aStart++;
                bStart++;
                continue;
            }

            if (codeA >= 128 || codeB >= 128) {
                // not ASCII letters -> fallback to lower-casing strings
                return compareSubstring(a.toLowerCase(), b.toLowerCase(), aStart, aEnd, bStart, bEnd);
            }

            // mapper lower-case ascii letter onto upper-case varinats
            // [97-122] (lower ascii) --> [65-90] (upper ascii)
            if (isLowerAsciiLetter(codeA)) {
                codeA -= 32;
            }
            if (isLowerAsciiLetter(codeB)) {
                codeB -= 32;
            }

            // compare both code points
            final diff = codeA - codeB;
            if (diff == 0) {
                aStart++;
                bStart++;
                continue;
            }

            return diff;
        }

        final aLen = aEnd - aStart;
        final bLen = bEnd - bStart;

        if (aLen < bLen) {
            return -1;
        }
        else if (aLen > bLen) {
            return 1;
        }

        return 0;
    }

    public static function startsWithIgnoreCase(str:String, candidate:String):Bool {
        final candidateLength = candidate.length;
        if (candidate.length > str.length) {
            return false;
        }

        return compareSubstringIgnoreCase(str, candidate, 0, candidateLength) == 0;
    }

}

/**
 * Options of `Strings.createRegExp`.
 */
typedef RegExpOptions = {
    @:optional var matchCase:Bool;
    @:optional var wholeWord:Bool;
    @:optional var multiline:Bool;
    @:optional var global:Bool;
    @:optional var unicode:Bool;
}

/**
 * Iterates over the code points of a string (UTF-16 offsets).
 */
class CodePointIterator {

    final _str:String;
    final _len:Int;
    var _offset:Int;

    public var offset(get, never):Int;
    inline function get_offset():Int {
        return this._offset;
    }

    public function new(str:String, offset:Int = 0) {
        this._str = str;
        this._len = str.length;
        this._offset = offset;
    }

    public function setOffset(offset:Int):Void {
        this._offset = offset;
    }

    public function prevCodePoint():Int {
        final codePoint = Strings.getPrevCodePoint(this._str, this._offset);
        this._offset -= (codePoint >= 0x10000 /* Constants.UNICODE_SUPPLEMENTARY_PLANE_BEGIN */ ? 2 : 1);
        return codePoint;
    }

    public function nextCodePoint():Int {
        final codePoint = Strings.getNextCodePoint(this._str, this._len, this._offset);
        this._offset += (codePoint >= 0x10000 /* Constants.UNICODE_SUPPLEMENTARY_PLANE_BEGIN */ ? 2 : 1);
        return codePoint;
    }

    public function eol():Bool {
        return (this._offset >= this._len);
    }

}

/**
 * Iterates over the grapheme clusters of a string (UTF-16 offsets), with
 * Monaco's pairwise rules (`breakBetweenGraphemeBreakType`).
 */
class GraphemeIterator {

    final _iterator:CodePointIterator;

    public var offset(get, never):Int;
    inline function get_offset():Int {
        return this._iterator.offset;
    }

    public function new(str:String, offset:Int = 0) {
        this._iterator = new CodePointIterator(str, offset);
    }

    public function nextGraphemeLength():Int {
        final graphemeBreakTree = GraphemeBreakTree.getInstance();
        final iterator = this._iterator;
        final initialOffset = iterator.offset;

        var graphemeBreakType = graphemeBreakTree.getGraphemeBreakType(iterator.nextCodePoint());
        while (!iterator.eol()) {
            final offset = iterator.offset;
            final nextGraphemeBreakType = graphemeBreakTree.getGraphemeBreakType(iterator.nextCodePoint());
            if (Strings.breakBetweenGraphemeBreakType(graphemeBreakType, nextGraphemeBreakType)) {
                // move iterator back
                iterator.setOffset(offset);
                break;
            }
            graphemeBreakType = nextGraphemeBreakType;
        }
        return (iterator.offset - initialOffset);
    }

    public function prevGraphemeLength():Int {
        final graphemeBreakTree = GraphemeBreakTree.getInstance();
        final iterator = this._iterator;
        final initialOffset = iterator.offset;

        var graphemeBreakType = graphemeBreakTree.getGraphemeBreakType(iterator.prevCodePoint());
        while (iterator.offset > 0) {
            final offset = iterator.offset;
            final prevGraphemeBreakType = graphemeBreakTree.getGraphemeBreakType(iterator.prevCodePoint());
            if (Strings.breakBetweenGraphemeBreakType(prevGraphemeBreakType, graphemeBreakType)) {
                // move iterator back
                iterator.setOffset(offset);
                break;
            }
            graphemeBreakType = prevGraphemeBreakType;
        }
        return (initialOffset - iterator.offset);
    }

    public function eol():Bool {
        return this._iterator.eol();
    }

}

enum abstract GraphemeBreakType(Int) from Int to Int {
    var Other = 0;
    var Prepend = 1;
    var CR = 2;
    var LF = 3;
    var Control = 4;
    var Extend = 5;
    var Regional_Indicator = 6;
    var SpacingMark = 7;
    var L = 8;
    var V = 9;
    var T = 10;
    var LV = 11;
    var LVT = 12;
    var ZWJ = 13;
    var Extended_Pictographic = 14;
}

/**
 * The grapheme break property of a code point, from Monaco's table
 * (`GraphemeBreakData`). The table is immutable: one instance is shared.
 */
class GraphemeBreakTree {

    static var _INSTANCE:Null<GraphemeBreakTree> = null;

    public static function getInstance():GraphemeBreakTree {
        if (_INSTANCE == null) {
            _INSTANCE = new GraphemeBreakTree();
        }
        return _INSTANCE;
    }

    final _data:Array<Int>;

    function new() {
        this._data = GraphemeBreakData.getGraphemeBreakRawData();
    }

    public function getGraphemeBreakType(codePoint:Int):GraphemeBreakType {
        // !!! Let's make 7bit ASCII a bit faster: 0..31
        if (codePoint < 32) {
            if (codePoint == CharCode.LineFeed) {
                return GraphemeBreakType.LF;
            }
            if (codePoint == CharCode.CarriageReturn) {
                return GraphemeBreakType.CR;
            }
            return GraphemeBreakType.Control;
        }
        // !!! Let's make 7bit ASCII a bit faster: 32..126
        if (codePoint < 127) {
            return GraphemeBreakType.Other;
        }

        final data = this._data;
        final nodeCount = Std.int(data.length / 3);
        var nodeIndex = 1;
        while (nodeIndex <= nodeCount) {
            if (codePoint < data[3 * nodeIndex]) {
                // go left
                nodeIndex = 2 * nodeIndex;
            }
            else if (codePoint > data[3 * nodeIndex + 1]) {
                // go right
                nodeIndex = 2 * nodeIndex + 1;
            }
            else {
                // hit
                return data[3 * nodeIndex + 2];
            }
        }

        return GraphemeBreakType.Other;
    }

}
