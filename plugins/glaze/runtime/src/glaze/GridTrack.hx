// New code for Glaze: explicit grid track lists (CSS `grid-template-columns`
// and `grid-template-rows`), without equivalent in GPUI (gpui-pre 0.3.10 only
// has `repeat(n, minmax(_, 1fr))`, see `GridTemplate`). See NOTICE.md.
package glaze;

/**
 * The size of one column or row of a grid (a CSS track size).
 */
enum GridTrackSize {

    /** A fixed length, in pixels or rems (`140px`, `6rem`) */
    Fixed(length:AbsoluteLength);

    /** A fraction of the grid's size in that axis (`0.25` is `25%`) */
    Percent(fraction:Float);

    /** A share of the free space (`1fr`): CSS `minmax(auto, <flex>fr)` */
    Fr(flex:Float);

    /** `auto`: at least the min content of the items, grows to their max content, then stretches */
    Auto;

    /** `min-content`: the smallest size the items of the track accept */
    MinContent;

    /** `max-content`: the size the items of the track take without constraint */
    MaxContent;

    /**
     * `minmax(min, max)`. Like CSS, `min` is a length, a percentage, `auto`,
     * `min-content` or `max-content`, and `max` may also be a `fr`. A nested
     * `minmax` counts for its own side, and a `fr` minimum counts as `auto`.
     */
    MinMax(min:GridTrackSize, max:GridTrackSize);

}

/**
 * A grid track of `gridTemplateCols([...])` and `gridTemplateRows([...])`.
 * Lengths convert by themselves, the other sizes come from the helpers of
 * `Prelude` (or the static functions here):
 *
 * ```haxe
 * div().grid().gridTemplateCols([px(140), fr(1)])
 * div().grid().gridTemplateCols([rems(6), minmax(px(0), fr(1)), maxContent(), auto()])
 * ```
 */
abstract GridTrack(GridTrackSize) from GridTrackSize to GridTrackSize {

    @:from static inline function fromPixels(value:Pixels):GridTrack {
        return GridTrackSize.Fixed(AbsoluteLength.Pixels(value));
    }

    @:from static inline function fromRems(value:Rems):GridTrack {
        return GridTrackSize.Fixed(AbsoluteLength.Rems(value));
    }

    @:from static inline function fromAbsoluteLength(value:AbsoluteLength):GridTrack {
        return GridTrackSize.Fixed(value);
    }

    /** `relative(0.25)` is `25%` */
    @:from static function fromDefiniteLength(value:DefiniteLength):GridTrack {
        return switch value {
            case Absolute(length): GridTrackSize.Fixed(length);
            case Fraction(fraction): GridTrackSize.Percent(fraction);
        }
    }

    /** `auto()` is `auto` */
    @:from static function fromLength(value:Length):GridTrack {
        return switch value {
            case Definite(length): fromDefiniteLength(length);
            case Auto: GridTrackSize.Auto;
        }
    }

    public static inline function px(pixels:Float):GridTrack {
        return GridTrackSize.Fixed(AbsoluteLength.Pixels(pixels));
    }

    public static inline function rems(rems:Float):GridTrack {
        return GridTrackSize.Fixed(AbsoluteLength.Rems(rems));
    }

    public static inline function percent(fraction:Float):GridTrack {
        return GridTrackSize.Percent(fraction);
    }

    public static inline function fr(flex:Float):GridTrack {
        return GridTrackSize.Fr(flex);
    }

    public static inline function auto():GridTrack {
        return GridTrackSize.Auto;
    }

    public static inline function minContent():GridTrack {
        return GridTrackSize.MinContent;
    }

    public static inline function maxContent():GridTrack {
        return GridTrackSize.MaxContent;
    }

    public static inline function minmax(min:GridTrack, max:GridTrack):GridTrack {
        return GridTrackSize.MinMax(min, max);
    }

    public inline function equals(other:GridTrack):Bool {
        return Type.enumEq((this:GridTrackSize), (other:GridTrackSize));
    }

}
