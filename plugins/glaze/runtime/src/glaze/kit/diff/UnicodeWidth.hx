// New code for the Haxe port of gpui-kit (no gpui-kit origin): stands for
// `unicode_width::UnicodeWidthStr::width` (unicode-width 0.2.2) in the diff.
// See NOTICE.md.
package gpui.component.diff;

/**
 * The display width of a string in terminal cells, as the diff uses it to
 * pick the widest lines before shaping them.
 *
 * Simplified from unicode-width: East Asian wide and fullwidth characters
 * (and emoji) take two cells, combining marks, zero-width characters and
 * controls none, everything else one. The diff only ranks candidates with
 * it; their widths come from shaping.
 */
class UnicodeWidth {

    public static function width(s:String):Int {
        var cells = 0;
        var i = 0;
        while (i < s.length) {
            final c = ttf.Utf8.codePointAt(s, i);
            i += c >= 0x10000 ? 2 : 1;
            cells += charWidth(c);
        }
        return cells;
    }

    static function charWidth(c:Int):Int {
        if (c < 0x20 || (c >= 0x7F && c < 0xA0))
            return 0;
        if (c < 0x300)
            return 1;
        if ((c >= 0x300 && c <= 0x36F) || (c >= 0x200B && c <= 0x200F) || (c >= 0x20D0 && c <= 0x20FF) || (c >= 0xFE00 && c <= 0xFE0F)
            || (c >= 0xFE20 && c <= 0xFE2F) || c == 0xFEFF || (c >= 0xE0000 && c <= 0xE0FFF))
            return 0;
        if ((c >= 0x1100 && c <= 0x115F) || (c >= 0x2E80 && c <= 0x303E) || (c >= 0x3041 && c <= 0x33FF) || (c >= 0x3400 && c <= 0x4DBF)
            || (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0xA000 && c <= 0xA4CF) || (c >= 0xAC00 && c <= 0xD7A3) || (c >= 0xF900 && c <= 0xFAFF)
            || (c >= 0xFE30 && c <= 0xFE4F) || (c >= 0xFF00 && c <= 0xFF60) || (c >= 0xFFE0 && c <= 0xFFE6) || (c >= 0x1F300 && c <= 0x1F64F)
            || (c >= 0x1F900 && c <= 0x1F9FF) || (c >= 0x20000 && c <= 0x3FFFD))
            return 2;
        return 1;
    }

}
