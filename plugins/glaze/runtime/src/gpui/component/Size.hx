// Ported from gpui-kit 0.8.1: crates/component/src/sizing.rs (Size)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.Edges;
import gpui.Pixels;

/**
 * A size for elements (default `Medium`).
 *
 * Not to be confused with `gpui.Size` (width and height): import it as
 * `gpui.component.Size` where both are needed. Methods are in `SizeTools`.
 */
@:using(gpui.component.Size.SizeTools)
enum Size {
    Size(size:Pixels);
    XSmall;
    Small;
    Medium;
    Large;
}

/**
 * Rust `impl Into<Size>`: a `Size`, or pixels for `Size.Size(px)`.
 */
abstract IntoSize(Size) from Size to Size {

    @:from static inline function fromPixels(value:Pixels):IntoSize {
        return Size(value);
    }

    @:from static inline function fromFloat(value:Float):IntoSize {
        return Size(value);
    }

    @:from static inline function fromInt(value:Int):IntoSize {
        return Size(value);
    }

}

/**
 * Methods of `Size`.
 */
class SizeTools {

    /**
     * The inset between an input's dropdown popup and its list rows.
     */
    public static inline final DROPDOWN_LIST_PADDING:Pixels = 4.;

    static function asF32(size:Size):Float {
        return switch size {
            case Size(value): value;
            case XSmall: 0.;
            case Small: 1.;
            case Medium: 2.;
            case Large: 3.;
        }
    }

    /**
     * Structural equality (`Size(px)` compares its pixels).
     */
    public static function equals(a:Size, b:Size):Bool {
        return switch [a, b] {
            case [Size(x), Size(y)]: x == y;
            case [Size(_), _] | [_, Size(_)]: false;
            case _: a == b;
        }
    }

    /**
     * Returns the size as a static string.
     */
    public static function asStr(size:Size):String {
        return switch size {
            case XSmall: 'xs';
            case Small: 'sm';
            case Medium: 'md';
            case Large: 'lg';
            case Size(_): 'custom';
        }
    }

    /**
     * Create a Size from a string: "xs" / "xsmall", "sm" / "small",
     * "md" / "medium", "lg" / "large" (case insensitive). Any other value
     * returns `Medium`.
     */
    public static function fromStr(size:String):Size {
        return switch size.toLowerCase() {
            case 'xs' | 'xsmall': XSmall;
            case 'sm' | 'small': Small;
            case 'md' | 'medium': Medium;
            case 'lg' | 'large': Large;
            case _: Medium;
        }
    }

    /**
     * Returns the height for table row.
     */
    public static function tableRowHeight(size:Size):Pixels {
        return switch size {
            case Size(value): value;
            case XSmall: 26.;
            case Small: 30.;
            case Large: 40.;
            case _: 32.;
        }
    }

    /**
     * Returns the padding for a table cell.
     */
    public static function tableCellPadding(size:Size):Edges {
        return switch size {
            case XSmall: new Edges(2., 4., 2., 4.);
            case Small: new Edges(3., 6., 3., 6.);
            case Large: new Edges(8., 12., 8., 12.);
            case _: new Edges(4., 8., 4., 8.);
        }
    }

    /**
     * Returns a smaller size.
     */
    public static function smaller(size:Size):Size {
        return switch size {
            case XSmall: XSmall;
            case Small: XSmall;
            case Medium: Small;
            case Large: Medium;
            case Size(value): Size(f32(value * f32(0.2)));
        }
    }

    /**
     * Returns a larger size.
     */
    public static function larger(size:Size):Size {
        return switch size {
            case XSmall: Small;
            case Small: Medium;
            case Medium: Large;
            case Large: Large;
            case Size(value): Size(f32(value * f32(1.2)));
        }
    }

    /**
     * Return the max size between two sizes.
     *
     * e.g. `XSmall.max(Small)` will return `XSmall`.
     */
    public static function max(self:Size, other:Size):Size {
        return switch [self, other] {
            case [Size(a), Size(b)]: Size(Math.min(a, b));
            case [Size(a), _]: Size(a);
            case [_, Size(b)]: Size(b);
            case [a, b] if (asF32(a) < asF32(b)): a;
            case _: other;
        }
    }

    /**
     * Return the min size between two sizes.
     *
     * e.g. `XSmall.min(Small)` will return `Small`.
     */
    public static function min(self:Size, other:Size):Size {
        return switch [self, other] {
            case [Size(a), Size(b)]: Size(Math.max(a, b));
            case [Size(a), _]: Size(a);
            case [_, Size(b)]: Size(b);
            case [a, b] if (asF32(a) > asF32(b)): a;
            case _: other;
        }
    }

    /**
     * Returns the horizontal input padding.
     */
    public static function inputPx(size:Size):Pixels {
        return switch size {
            case Large: 12.;
            case Medium: 10.;
            case Small: 8.;
            case XSmall: 4.;
            case _: 8.;
        }
    }

    /**
     * Returns the vertical input padding.
     */
    public static function inputPy(size:Size):Pixels {
        return switch size {
            case Large: 10.;
            case Medium: 8.;
            case Small: 2.;
            case XSmall: 0.;
            case _: 2.;
        }
    }

    /**
     * Returns the horizontal padding of a row in an input's dropdown list.
     *
     * The trigger insets its text by a 1px border plus `inputPx`; the popup
     * insets a row by `DROPDOWN_LIST_PADDING`. The row pads the difference, so
     * the chosen item's text lines up with the trigger's.
     */
    public static function listPx(size:Size):Pixels {
        return inputPx(size) + 1. - DROPDOWN_LIST_PADDING;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

}
