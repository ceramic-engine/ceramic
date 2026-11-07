// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * A color stop in a linear gradient.
 *
 * Immutable: every operation returns a new instance.
 */
class LinearColorStop {

    /**
     * The color of the color stop.
     */
    public final color:Hsla;

    /**
     * The position of the stop along the gradient, in the range 0.0 to 1.0.
     */
    public final percentage:Float;

    public inline function new(?color:Hsla, percentage:Float = 0) {

        this.color = color != null ? color : new Hsla();
        this.percentage = percentage;

    }

    /**
     * Returns a new color stop with the same position, and the color alpha
     * multiplied by `factor`.
     */
    public inline function opacity(factor:Float):LinearColorStop {

        return new LinearColorStop(color.opacity(factor), percentage);

    }

    /**
     * Structural equality.
     */
    public inline function equals(other:LinearColorStop):Bool {

        return other != null && percentage == other.percentage && color.equals(other.color);

    }

    public function toString():String {

        return 'LinearColorStop($color, $percentage)';

    }

}
