package glaze.util;

/**
 * UTF-8 helpers for the text system.
 *
 * GPUI indexes text with UTF-8 byte offsets (`TextRun.len`, glyph indices,
 * ranges, selections), while Haxe strings are indexed by UTF-16 code units
 * (JS, hxcpp). The port keeps byte offsets everywhere and converts at the
 * boundaries with these helpers. Code point decoding is shared with the
 * `ttf` library (`ttf.Utf8`).
 *
 * `Utf8Text` decodes a string once (code points plus the byte offset of
 * each) for code that needs many lookups by byte offset.
 */
class Utf8 {

    /** Number of UTF-8 bytes used to encode a code point. */
    public static inline function codePointLength(c:Int):Int {
        return c < 0x80 ? 1 : (c < 0x800 ? 2 : (c < 0x10000 ? 3 : 4));
    }

    /** Length of a string in UTF-8 bytes. */
    public static inline function byteLength(s:String):Int {
        return ttf.Utf8.byteLength(s);
    }

    /**
     * Decodes a string into code points and their UTF-8 byte offsets
     * (arrays are reused, only grown). Returns the number of code points.
     */
    public static inline function decode(s:String, codePoints:Array<Int>, byteOffsets:Array<Int>):Int {
        return ttf.Utf8.decode(s, codePoints, byteOffsets);
    }

    /** Converts a UTF-8 byte offset into a UTF-16 index of `s`. */
    public static inline function byteOffsetToIndex(s:String, byteOffset:Int):Int {
        return ttf.Utf8.byteOffsetToIndex(s, byteOffset);
    }

    /** Converts a UTF-16 index of `s` into a UTF-8 byte offset. */
    public static inline function indexToByteOffset(s:String, index:Int):Int {
        return ttf.Utf8.indexToByteOffset(s, index);
    }

    /**
     * Substring between two UTF-8 byte offsets (Rust `&s[start..end]`).
     */
    public static function substring(s:String, start:Int, end:Int):String {
        if (start >= end)
            return '';
        if (isAscii(s))
            return s.substring(start, end);
        final from = byteOffsetToIndex(s, start);
        final to = byteOffsetToIndex(s, end);
        return s.substring(from, to);
    }

    /** Substring from a UTF-8 byte offset to the end (Rust `&s[start..]`). */
    public static inline function substringFrom(s:String, start:Int):String {
        return isAscii(s) ? s.substr(start) : s.substr(byteOffsetToIndex(s, start));
    }

    /** True if every character of `s` is ASCII (byte offsets are then string indices). */
    public static function isAscii(s:String):Bool {
        for (i in 0...s.length) {
            if (StringTools.fastCodeAt(s, i) >= 0x80)
                return false;
        }
        return true;
    }

    /**
     * Code point starting at the given UTF-8 byte offset, or -1 if the
     * offset is out of range or not on a character boundary.
     */
    public static function codePointAtByte(s:String, byteOffset:Int):Int {
        var offset = 0;
        var i = 0;
        final len = s.length;
        while (i < len) {
            final cp = ttf.Utf8.codePointAt(s, i);
            if (offset == byteOffset)
                return cp;
            if (offset > byteOffset)
                return -1;
            offset += codePointLength(cp);
            i += cp >= 0x10000 ? 2 : 1;
        }
        return -1;
    }

    /** True if `byteOffset` is on a character boundary (Rust `str::is_char_boundary`). */
    public static function isCharBoundary(s:String, byteOffset:Int):Bool {
        if (byteOffset == 0)
            return true;
        var offset = 0;
        var i = 0;
        final len = s.length;
        while (i < len) {
            final cp = ttf.Utf8.codePointAt(s, i);
            if (offset == byteOffset)
                return true;
            if (offset > byteOffset)
                return false;
            offset += codePointLength(cp);
            i += cp >= 0x10000 ? 2 : 1;
        }
        return offset == byteOffset;
    }

    /**
     * Smallest character boundary greater than or equal to `byteOffset`
     * (Rust `str::ceil_char_boundary`).
     */
    public static function ceilCharBoundary(s:String, byteOffset:Int):Int {
        var offset = 0;
        var i = 0;
        final len = s.length;
        while (i < len) {
            if (offset >= byteOffset)
                return offset;
            final cp = ttf.Utf8.codePointAt(s, i);
            offset += codePointLength(cp);
            i += cp >= 0x10000 ? 2 : 1;
        }
        return offset;
    }

    /** String made of a single code point. */
    public static inline function fromCodePoint(c:Int):String {
        return String.fromCharCode(c);
    }

    /** Rust `char::is_whitespace` (Unicode `White_Space` property). */
    public static function isWhitespace(c:Int):Bool {
        return (c >= 0x09 && c <= 0x0D) || c == 0x20 || c == 0x85 || c == 0xA0 || c == 0x1680
            || (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F
            || c == 0x205F || c == 0x3000;
    }

    /** Rust `char::is_ascii_punctuation`. */
    public static inline function isAsciiPunctuation(c:Int):Bool {
        return (c >= 0x21 && c <= 0x2F) || (c >= 0x3A && c <= 0x40) || (c >= 0x5B && c <= 0x60) || (c >= 0x7B && c <= 0x7E);
    }

    /** Rust `char::is_ascii_alphanumeric`. */
    public static inline function isAsciiAlphanumeric(c:Int):Bool {
        return (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
    }

    /** Rust `char::len_utf16`. */
    public static inline function utf16Length(c:Int):Int {
        return c >= 0x10000 ? 2 : 1;
    }

}

/**
 * A string decoded once into code points and UTF-8 byte offsets, for
 * repeated lookups by byte offset.
 */
class Utf8Text {

    public var text(default, null):String;

    /** Code points */
    public final codePoints:Array<Int> = [];

    /** UTF-8 byte offset of each code point */
    public final byteOffsets:Array<Int> = [];

    /** Number of code points */
    public var count(default, null):Int = 0;

    /** Length in UTF-8 bytes */
    public var byteLength(default, null):Int = 0;

    public function new(?text:String) {
        if (text != null)
            reset(text);
    }

    public function reset(text:String):Utf8Text {
        this.text = text;
        count = Utf8.decode(text, codePoints, byteOffsets);
        byteLength = count > 0 ? byteOffsets[count - 1] + Utf8.codePointLength(codePoints[count - 1]) : 0;
        return this;
    }

    /**
     * Index of the code point starting at `byteOffset`, or of the code point
     * containing it. Returns `count` past the end.
     */
    public function indexAtByte(byteOffset:Int):Int {
        var lo = 0;
        var hi = count;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (byteOffsets[mid] <= byteOffset)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo - 1 < 0 ? (count > 0 ? 0 : count) : (byteOffset >= byteLength ? count : lo - 1);
    }

    /** Code point at `byteOffset` (the one containing it), or -1 past the end. */
    public inline function codePointAtByte(byteOffset:Int):Int {
        final index = indexAtByte(byteOffset);
        return index < count ? codePoints[index] : -1;
    }

}
