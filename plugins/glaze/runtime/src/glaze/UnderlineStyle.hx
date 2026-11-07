// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The properties that can be applied to an underline.
 */
class UnderlineStyle {

    /** The thickness of the underline. */
    public var thickness:Pixels;

    /** The color of the underline. */
    public var color:Null<Hsla>;

    /** Whether the underline should be wavy, like in a spell checker. */
    public var wavy:Bool;

    public function new(thickness:Pixels = 0, ?color:Hsla, wavy:Bool = false) {
        this.thickness = thickness;
        this.color = color;
        this.wavy = wavy;
    }

    public function clone():UnderlineStyle {
        return new UnderlineStyle(thickness, color, wavy);
    }

    public function equals(other:UnderlineStyle):Bool {
        return other != null && thickness == other.thickness && wavy == other.wavy
            && (color == null ? other.color == null : color.equals(other.color));
    }

}
