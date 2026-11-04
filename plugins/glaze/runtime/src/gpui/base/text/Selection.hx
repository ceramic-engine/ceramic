// Ported from gpui-kit 0.8.1: crates/base/src/text/selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;
import gpui.util.Utf8;

/** Rust `CharType`: how a char connects with its neighbours in a word selection. */
enum abstract CharType(Int) {
    /** a-z, A-Z, 0-9, _ */
    var Word = 0;
    /** '\t', ' ', '\u{00A0}' etc. */
    var Whitespace = 1;
    /** \n, \r */
    var Newline = 2;
    /** . , ; : ( ) [ ] { } ... or CJK characters: `汉`, `🎉` etc. */
    var Other = 3;

    /** Rust `impl From<char> for CharType`. */
    public static function from(c:Int):CharType {
        return if (Selection.isWordChar(c)) Word
        else if (c == '\n'.code || c == '\r'.code) Newline
        else if (Utf8.isWhitespace(c)) Whitespace
        else Other;
    }

    public inline function isConnectable(c:Int):Bool {
        final other = from(c);
        return (abstract == Word && other == Word) || (abstract == Whitespace && other == Whitespace);
    }
}

/**
 * Word ranges for double clicks in rich text (Rust `text::selection`).
 * Char iterators are functions returning the next code point, or -1 at the
 * end (Rust `impl Iterator<Item = char>`).
 */
class Selection {

    /** Implementation based on Zed's `line_wrapper.rs`. */
    public static function isWordChar(c:Int):Bool {
        return c == '_'.code
            // ASCII alphanumeric characters, for English, numbers: `Hello123`, etc.
            || Utf8.isAsciiAlphanumeric(c)
            // Latin script in Unicode for French, German, Spanish, etc.
            || (c >= 0x00C0 && c <= 0x00FF)
            || (c >= 0x0100 && c <= 0x017F)
            || (c >= 0x0180 && c <= 0x024F)
            // Cyrillic for Russian, Ukrainian, etc.
            || (c >= 0x0400 && c <= 0x04FF)
            // Vietnamese
            || (c >= 0x1E00 && c <= 0x1EFF)
            || (c >= 0x0300 && c <= 0x036F);
    }

    public static function wordRangeFromChars(offset:Int, c:Int, prevChars:() -> Int, nextChars:() -> Int):Range {
        final charType = CharType.from(c);
        var start = offset;
        var end = offset + Utf8.codePointLength(c);

        var taken = 0;
        while (taken < 128) {
            final prev = prevChars();
            if (prev == -1) break;
            taken++;
            if (charType.isConnectable(prev)) {
                start -= Utf8.codePointLength(prev);
            }
            else {
                break;
            }
        }

        taken = 0;
        while (taken < 128) {
            final next = nextChars();
            if (next == -1) break;
            taken++;
            if (charType.isConnectable(next)) {
                end += Utf8.codePointLength(next);
            }
            else {
                break;
            }
        }

        return new Range(start, end);
    }

    public static function wordRangeAt(text:String, offset:Int):Null<Range> {
        if (text.length == 0) {
            return null;
        }

        final offset = clipOffset(text, offset);
        final after = chars(Utf8.substringFrom(text, offset));
        if (after.length == 0) {
            return null;
        }
        final c = after[0];
        final before = chars(Utf8.substring(text, 0, offset));
        var back = before.length;
        var forward = 1;
        return wordRangeFromChars(offset, c, () -> back > 0 ? before[--back] : -1, () -> forward < after.length ? after[forward++] : -1);
    }

    static function clipOffset(text:String, offset:Int):Int {
        final len = Utf8.byteLength(text);
        final offset = offset < len ? offset : len;
        if (offset == len) {
            // The start of the last char.
            var ix = len;
            if (ix == 0) return 0;
            ix -= 1;
            while (ix > 0 && !Utf8.isCharBoundary(text, ix)) ix -= 1;
            return ix;
        }

        if (Utf8.isCharBoundary(text, offset)) {
            return offset;
        }
        else {
            // The last char boundary before `offset`.
            var ix = offset;
            while (ix > 0 && !Utf8.isCharBoundary(text, ix)) ix -= 1;
            return ix;
        }
    }

    static function chars(text:String):Array<Int> {
        final result:Array<Int> = [];
        final iter = new haxe.iterators.StringIteratorUnicode(text);
        for (c in iter) result.push(c);
        return result;
    }

}
