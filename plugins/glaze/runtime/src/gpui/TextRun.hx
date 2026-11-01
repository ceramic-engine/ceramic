// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A styled run of text, for use in `TextLayout`.
 */
class TextRun {

    /** A number of utf8 bytes */
    public var len:Int;

    /** The font to use for this run. */
    public var font:Font;

    /** The color */
    public var color:Hsla;

    /** The background color (if any) */
    public var backgroundColor:Null<Hsla>;

    /** The underline style (if any) */
    public var underline:Null<UnderlineStyle>;

    /** The strikethrough style (if any) */
    public var strikethrough:Null<StrikethroughStyle>;

    public function new(len:Int = 0, ?font:Font, ?color:Hsla, ?backgroundColor:Hsla, ?underline:UnderlineStyle, ?strikethrough:StrikethroughStyle) {
        this.len = len;
        this.font = font != null ? font : Font.defaultValue();
        this.color = color != null ? color : new Hsla(0, 0, 0, 0);
        this.backgroundColor = backgroundColor;
        this.underline = underline;
        this.strikethrough = strikethrough;
    }

    public function clone():TextRun {
        return new TextRun(len, font, color, backgroundColor, underline, strikethrough);
    }

    /** A copy of this run with another length. */
    public function withLen(len:Int):TextRun {
        final result = clone();
        result.len = len;
        return result;
    }

    public function equals(other:TextRun):Bool {
        return other != null && len == other.len && font.equals(other.font) && color.equals(other.color)
            && TextRun.sameColor(backgroundColor, other.backgroundColor)
            && TextRun.sameUnderline(underline, other.underline)
            && TextRun.sameStrikethrough(strikethrough, other.strikethrough);
    }

    public static inline function sameColor(a:Null<Hsla>, b:Null<Hsla>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    public static inline function sameUnderline(a:Null<UnderlineStyle>, b:Null<UnderlineStyle>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    public static inline function sameStrikethrough(a:Null<StrikethroughStyle>, b:Null<StrikethroughStyle>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    public function toString():String {
        return 'TextRun(len=$len, font=$font, color=$color)';
    }

}
