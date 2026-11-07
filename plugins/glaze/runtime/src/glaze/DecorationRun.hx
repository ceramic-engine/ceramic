// Ported from gpui-pre 0.3.10: src/text_system/line.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Set the text decoration for a run of text.
 */
class DecorationRun {

    /** The length of the run in utf-8 bytes. */
    public var len:Int;

    /** The color for this run */
    public var color:Hsla;

    /** The background color for this run */
    public var backgroundColor:Null<Hsla>;

    /** The underline style for this run */
    public var underline:Null<UnderlineStyle>;

    /** The strikethrough style for this run */
    public var strikethrough:Null<StrikethroughStyle>;

    public function new(len:Int, color:Hsla, ?backgroundColor:Hsla, ?underline:UnderlineStyle, ?strikethrough:StrikethroughStyle) {
        this.len = len;
        this.color = color;
        this.backgroundColor = backgroundColor;
        this.underline = underline;
        this.strikethrough = strikethrough;
    }

    public function clone():DecorationRun {
        return new DecorationRun(len, color, backgroundColor, underline, strikethrough);
    }

    /** A copy with another length */
    public function withLen(len:Int):DecorationRun {
        final result = clone();
        result.len = len;
        return result;
    }

    public function toString():String {
        return 'DecorationRun($len, $color)';
    }

}
