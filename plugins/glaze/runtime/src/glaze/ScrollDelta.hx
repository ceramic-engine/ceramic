// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The scroll delta for a scroll wheel event.
 */
@:using(gpui.ScrollDelta.ScrollDeltaTools)
enum ScrollDelta {

    /** An exact scroll delta in pixels. */
    Pixels(delta:Point);

    /** An inexact scroll delta in lines. */
    Lines(delta:Point);

}

class ScrollDeltaTools {

    /**
     * Returns true if this is a precise scroll delta in pixels.
     */
    public static function precise(delta:ScrollDelta):Bool {
        return switch delta {
            case Pixels(_): true;
            case Lines(_): false;
        }
    }

    /**
     * Converts this scroll event into exact pixels.
     */
    public static function pixelDelta(delta:ScrollDelta, lineHeight:Float):Point {
        return switch delta {
            case Pixels(d): d;
            case Lines(d): new Point(lineHeight * d.x, lineHeight * d.y);
        }
    }

    /**
     * Combines two scroll deltas into one.
     * If the signs of the deltas are the same (both positive or both negative),
     * the deltas are added together. If the signs are opposite, the second delta
     * (other) is used, effectively overriding the first delta.
     */
    public static function coalesce(delta:ScrollDelta, other:ScrollDelta):ScrollDelta {
        inline function combine(a:Float, b:Float):Float {
            return gpui.util.MathUtil.signum(a) == gpui.util.MathUtil.signum(b) ? a + b : b;
        }
        return switch [delta, other] {
            case [Pixels(a), Pixels(b)]: Pixels(new Point(combine(a.x, b.x), combine(a.y, b.y)));
            case [Lines(a), Lines(b)]: Lines(new Point(combine(a.x, b.x), combine(a.y, b.y)));
            case _: other;
        }
    }

}
