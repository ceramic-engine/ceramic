// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The properties that can be applied to a strikethrough.
 */
class StrikethroughStyle {

    /** The thickness of the strikethrough. */
    public var thickness:Pixels;

    /** The color of the strikethrough. */
    public var color:Null<Hsla>;

    public function new(thickness:Pixels = 0, ?color:Hsla) {
        this.thickness = thickness;
        this.color = color;
    }

    public function clone():StrikethroughStyle {
        return new StrikethroughStyle(thickness, color);
    }

    public function equals(other:StrikethroughStyle):Bool {
        return other != null && thickness == other.thickness
            && (color == null ? other.color == null : color.equals(other.color));
    }

}
