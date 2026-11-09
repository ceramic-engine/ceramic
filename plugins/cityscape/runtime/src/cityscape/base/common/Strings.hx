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
