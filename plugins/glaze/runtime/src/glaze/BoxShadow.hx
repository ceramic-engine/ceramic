// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The possible values of the box-shadow property.
 *
 * Builder methods (`blurRadius`, `spreadRadius`, `inset`) set the field
 * and return the same instance (Rust consumes and returns `self`). The
 * `withX` prefix avoids the clash between builder and field names.
 */
class BoxShadow {

    /** What color should the shadow have? */
    public var color:Hsla;

    /** How should it be offset from its element? */
    public var offset:Point;

    /** How much should the shadow be blurred? */
    public var blurRadius:Pixels;

    /** How much should the shadow spread? */
    public var spreadRadius:Pixels;

    /** Whether this is an inset shadow (drawn inside the element's bounds). */
    public var inset:Bool;

    /**
     * Creates a new `BoxShadow` with the given offset and color, matching the order
     * of the CSS `box-shadow` property.
     */
    public function new(offsetX:Pixels, offsetY:Pixels, color:IntoHsla) {
        this.color = color;
        this.offset = new Point(offsetX, offsetY);
        this.blurRadius = 0;
        this.spreadRadius = 0;
        this.inset = false;
    }

    /** Sets the shadow blur radius. */
    public inline function withBlurRadius(blurRadius:Pixels):BoxShadow {
        this.blurRadius = blurRadius;
        return this;
    }

    /** Sets the shadow spread radius. */
    public inline function withSpreadRadius(spreadRadius:Pixels):BoxShadow {
        this.spreadRadius = spreadRadius;
        return this;
    }

    /** Marks the shadow as inset (drawn inside the element's bounds). */
    public inline function withInset():BoxShadow {
        this.inset = true;
        return this;
    }

    public function equals(other:BoxShadow):Bool {
        return other != null && color.equals(other.color) && offset.equals(other.offset)
            && blurRadius == other.blurRadius && spreadRadius == other.spreadRadius && inset == other.inset;
    }

}
