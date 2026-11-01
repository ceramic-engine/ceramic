// Ported from gpui-kit 0.8.1: crates/base/src/text/utils.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Image;
import gpui.ImageFormat;
import gpui.util.Utf8;

/**
 * The free functions of utils.rs, plus the Rust `str` methods the text
 * engine relies on (`trim`, `lines`, `get(range)`...), on UTF-8 byte
 * offsets like Rust.
 */
class TextUtils {

    static final NUMBERED_PREFIXES_1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    static final NUMBERED_PREFIXES_2 = 'abcdefghijklmnopqrstuvwxyz';

    static final BULLETS = ['•', '◦', '▪', '‣', '⁃'];

    static inline final U32_MAX:Float = 4294967295.;

    /**
     * Returns an ordered-list item's ordinal, defaulting omitted starts to
     * one. Saturates at `u32::MAX` like Rust (returned as a Float when it
     * does not fit an Int).
     */
    public static function orderedListOrdinal(start:Null<Int>, ix:Int):Float {
        final base:Float = start != null ? (start < 0 ? start + 4294967296. : start) : 1;
        final sum = base + ix;
        return sum > U32_MAX ? U32_MAX : sum;
    }

    /** Formats an ordinal returned by `orderedListOrdinal` (no `.0` suffix). */
    public static function ordinalString(ordinal:Float):String {
        if (ordinal <= 2147483647.)
            return Std.string(Std.int(ordinal));
        return haxe.Int64.toStr(haxe.Int64.fromFloat(ordinal));
    }

    /** Returns the prefix for a list item. */
    public static function listItemPrefix(ix:Int, start:Null<Int>, ordered:Bool, depth:Int):String {
        if (ordered) {
            final ordinal = orderedListOrdinal(start, ix);
            if (depth == 0 || start == 0) {
                return ordinalString(ordinal) + '. ';
            }

            final alphaIx = ordinal >= 1 ? ordinal - 1 : 0;
            if (depth == 1) {
                return NUMBERED_PREFIXES_1.charAt(Std.int(alphaIx % NUMBERED_PREFIXES_1.length)) + '. ';
            } else {
                return NUMBERED_PREFIXES_2.charAt(Std.int(alphaIx % NUMBERED_PREFIXES_2.length)) + '. ';
            }
        } else {
            final depth = depth < BULLETS.length - 1 ? depth : BULLETS.length - 1;
            final bullet = BULLETS[depth];
            return bullet + ' ';
        }
    }

    /**
     * Decodes a `data:` URL whose mime type names an image format GPUI can
     * decode. Anything else (another scheme, a non-image body, malformed
     * base64) yields `null`, and the caller keeps the URL URI-backed so
     * GPUI's own loader reports the failure.
     */
    public static function dataUrlImage(url:String):Null<Image> {
        final dataUrl = DataUrl.process(url);
        if (dataUrl == null)
            return null;
        final mime = dataUrl.mimeType();
        final format = ImageFormat.fromMimeType(mime.type + '/' + mime.subtype);
        if (format == null)
            return null;
        final bytes = dataUrl.decodeToBytes();
        if (bytes == null)
            return null;
        return Image.fromBytes(format, bytes);
    }

    // Rust `str` helpers (UTF-8 byte offsets)

    /** Length in UTF-8 bytes (Rust `str::len`). */
    public static inline function len(s:String):Int {
        return Utf8.byteLength(s);
    }

    /** Rust `&s[start..end]` (byte offsets on character boundaries). */
    public static inline function slice(s:String, start:Int, end:Int):String {
        return Utf8.substring(s, start, end);
    }

    /** Rust `&s[start..]`. */
    public static inline function sliceFrom(s:String, start:Int):String {
        return Utf8.substringFrom(s, start);
    }

    /**
     * Rust `s.get(start..end)`: `null` when the range is out of bounds or
     * not on character boundaries.
     */
    public static function byteSlice(s:String, start:Int, end:Int):Null<String> {
        if (start > end || end > len(s))
            return null;
        if (!Utf8.isCharBoundary(s, start) || !Utf8.isCharBoundary(s, end))
            return null;
        return slice(s, start, end);
    }

    /** Rust `str::trim` (Unicode white space). */
    public static function trim(s:String):String {
        return trimEnd(trimStart(s));
    }

    /** Rust `str::trim_start`. */
    public static function trimStart(s:String):String {
        var i = 0;
        final n = s.length;
        while (i < n) {
            final c = codePointAt(s, i);
            if (!Utf8.isWhitespace(c))
                break;
            i += c >= 0x10000 ? 2 : 1;
        }
        return i == 0 ? s : s.substr(i);
    }

    /** Rust `str::trim_end`. */
    public static function trimEnd(s:String):String {
        var i = s.length;
        while (i > 0) {
            var c = StringTools.fastCodeAt(s, i - 1);
            var w = 1;
            if (c >= 0xDC00 && c <= 0xDFFF && i >= 2) {
                c = codePointAt(s, i - 2);
                w = 2;
            }
            if (!Utf8.isWhitespace(c))
                break;
            i -= w;
        }
        return i == s.length ? s : s.substr(0, i);
    }

    /** Rust `str::trim_end_matches(ch)` for one character. */
    public static function trimEndMatches(s:String, ch:String):String {
        var end = s.length;
        final n = ch.length;
        while (end >= n && s.substr(end - n, n) == ch)
            end -= n;
        return end == s.length ? s : s.substr(0, end);
    }

    /** Rust `str::trim_start_matches(ch)` for one character. */
    public static function trimStartMatches(s:String, ch:String):String {
        var start = 0;
        final n = ch.length;
        while (start + n <= s.length && s.substr(start, n) == ch)
            start += n;
        return start == 0 ? s : s.substr(start);
    }

    /** Rust `str::trim_matches(ch)` for one character. */
    public static inline function trimMatches(s:String, ch:String):String {
        return trimEndMatches(trimStartMatches(s, ch), ch);
    }

    /**
     * Rust `str::lines`: split on `\n`, drop one `\r` before it, and no
     * trailing empty line.
     */
    public static function lines(s:String):Array<String> {
        if (s == '')
            return [];
        final parts = s.split('\n');
        if (parts[parts.length - 1] == '')
            parts.pop();
        for (i in 0...parts.length) {
            final line = parts[i];
            if (line.length > 0 && StringTools.fastCodeAt(line, line.length - 1) == '\r'.code)
                parts[i] = line.substr(0, line.length - 1);
        }
        return parts;
    }

    /** Rust `str::repeat`. */
    public static function repeat(s:String, count:Int):String {
        final buf = new StringBuf();
        for (_ in 0...count)
            buf.add(s);
        return buf.toString();
    }

    /** Rust `str::is_empty` after `trim`. */
    public static inline function isBlank(s:String):Bool {
        return trim(s) == '';
    }

    static inline function codePointAt(s:String, index:Int):Int {
        return ttf.Utf8.codePointAt(s, index);
    }

}
