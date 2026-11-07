// Ported from gpui-kit 0.8.1: crates/base/src/text_boundary.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;
import gpui.util.Utf8;

/**
 * Word and line boundaries for double and triple clicks (Rust
 * `crate::text_boundary`, shared by the input engine and the selectable
 * text). Lives with the input engine, its first user in this port.
 *
 * Char iterators are functions returning the next code point, or -1 at the
 * end (Rust `impl Iterator<Item = char>`).
 */
class TextBoundary {

    static inline final KIND_WORD = 0;
    static inline final KIND_WHITESPACE = 1;
    static inline final KIND_NEWLINE = 2;
    static inline final KIND_OTHER = 3;

    /** Rust `CharacterKind::from(char)`. */
    static function characterKind(character:Int):Int {
        if (character == '_'.code
            || Utf8.isAsciiAlphanumeric(character)
            || (character >= 0x00C0 && character <= 0x024F)
            || (character >= 0x0400 && character <= 0x04FF)
            || (character >= 0x1E00 && character <= 0x1EFF)
            || (character >= 0x0300 && character <= 0x036F)) {
            return KIND_WORD;
        }
        else if (character == '\n'.code || character == '\r'.code) {
            return KIND_NEWLINE;
        }
        else if (Utf8.isWhitespace(character)) {
            return KIND_WHITESPACE;
        }
        else {
            return KIND_OTHER;
        }
    }

    /**
     * The range of the run of chars around `character` (at byte `offset`)
     * that connect with it: words with words, whitespace with whitespace, and
     * nothing else. At most 128 chars are looked at on each side.
     */
    public static function wordRangeFromChars(offset:Int, character:Int, previous:() -> Int, following:() -> Int):Range {
        final kind = characterKind(character);
        inline function connects(next:Int):Bool {
            final nextKind = characterKind(next);
            return (kind == KIND_WORD && nextKind == KIND_WORD) || (kind == KIND_WHITESPACE && nextKind == KIND_WHITESPACE);
        }
        var start = offset;
        var taken = 0;
        while (taken < 128) {
            final c = previous();
            if (c == -1 || !connects(c)) break;
            start -= Utf8.codePointLength(c);
            taken++;
        }
        var end = offset + Utf8.codePointLength(character);
        taken = 0;
        while (taken < 128) {
            final c = following();
            if (c == -1 || !connects(c)) break;
            end += Utf8.codePointLength(c);
            taken++;
        }
        return new Range(start, end);
    }

    /** The word range at a byte offset of a string. */
    public static function wordRangeAt(text:String, offset:Int):Null<Range> {
        final offset = clipOffsetLeft(text, offset);
        final chars = MaskPattern.MaskPatternTools.chars(Utf8.substringFrom(text, offset));
        if (chars.length == 0) {
            return null;
        }
        final character = chars[0];
        final before = MaskPattern.MaskPatternTools.chars(Utf8.substring(text, 0, offset));
        var back = before.length;
        var forward = 1;
        return wordRangeFromChars(offset, character, () -> back > 0 ? before[--back] : -1, () -> forward < chars.length ? chars[forward++] : -1);
    }

    /** The line range (without its `\n`) at a byte offset of a string. */
    public static function lineRangeAt(text:String, offset:Int):Range {
        final offset = clipOffsetLeft(text, offset);
        final head = Utf8.substring(text, 0, offset);
        final newline = head.lastIndexOf('\n');
        final start = newline == -1 ? 0 : Utf8.byteLength(head.substr(0, newline)) + 1;
        final tail = Utf8.substringFrom(text, offset);
        final next = tail.indexOf('\n');
        final end = next == -1 ? Utf8.byteLength(text) : offset + Utf8.byteLength(tail.substr(0, next));
        return new Range(start, end);
    }

    static function clipOffsetLeft(text:String, offset:Int):Int {
        final len = Utf8.byteLength(text);
        var offset = offset < len ? offset : len;
        while (!Utf8.isCharBoundary(text, offset)) {
            offset -= 1;
        }
        return offset;
    }

}
