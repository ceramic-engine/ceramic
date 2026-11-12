// Original code for Glaze (not a port): how kit scrollbars appear, disappear and react to hover.
package glaze.kit.base;

/**
 * How a scrollbar becomes visible and invisible (`ScrollbarAppearance.transition`).
 */
enum abstract ScrollbarTransition(Int) from Int to Int {

    /**
     * The scrollbar fades in and out in place, linearly, over the show and
     * hide durations (Glaze's default, 0.12 seconds each way).
     */
    var Fade = 0;

    /** The scrollbar appears and disappears at once, without animation. */
    var Instant = 1;

    /**
     * gpui-kit's choreography: fades in over 0.3 seconds (in `Hover` mode,
     * pointing at the hidden thumb also slides it in from the edge), and
     * slides out toward the edge while fading over 0.5 seconds.
     */
    var GpuiKit = 2;

}

/**
 * How kit scrollbars appear, disappear and react to hover (a Glaze setting;
 * see "Scrollbars" in the plugin README and DEV-023 in docs/DEVIATIONS.md).
 *
 * This is separate from the scrollbar mode (`ScrollbarMode`: when a
 * scrollbar is shown, on hover, while scrolling, always or never): the
 * appearance says how it shows and hides, and whether the thumb grows when
 * the pointer is over it or drags it.
 *
 * - `transition`: `Fade` (the default), `Instant` or `GpuiKit`.
 * - `showDuration` and `hideDuration`: seconds, for `Fade` and `GpuiKit`
 *   (null: the transition's own, 0.12 for `Fade`, 0.3 and 0.5 for
 *   `GpuiKit`). `withDuration(d)` sets both.
 * - `thumbGrowth`: whether the thumb widens when hovered or dragged
 *   (gpui-kit's 6 to 8 pixels, 2 pixels more than the resting width
 *   otherwise). Off by default: the thumb keeps its resting width and inset
 *   in every state, only its color changes.
 * - `thumbWidth`: the resting width of the thumb in pixels, 8 by default
 *   (Loreline Writer's scrollbars), still 4 pixels from the edge in the 16
 *   pixel band (`Scrollbar.width()`); null for gpui-kit's 6 pixels (8 when
 *   grown). Explicit `ScrollbarStyles` widths (the theme's on mobile, a
 *   scrollbar's own) still win.
 * - `thumbRadius`: the corner radius of the thumb, `FULL_RADIUS` by default
 *   (fully rounded: 4 pixels for an 8 pixel thumb, like Writer); null for
 *   the kit theme's `radius`, as in gpui-kit. A scrollbar's own
 *   `ScrollbarStyles` radius still wins, and a theme whose radius is zero
 *   still squares the thumb.
 *
 * The global default is the kit theme's `scrollbarAppearance`
 * (`Theme.setScrollbarAppearance(appearance, cx)` changes it at runtime),
 * itself `ScrollbarAppearance.defaultValue()` at startup, which the define
 * `glaze_scrollbar_appearance` (`fade`, `instant` or `gpuikit`) can change at
 * compile time. A scrollbar overrides it with `Scrollbar.appearance(...)`, a
 * `Scrollable` with `scrollbarAppearance(...)`.
 *
 * Values are immutable: the `with...` methods return a modified copy.
 */
class ScrollbarAppearance {

    /** The show and hide duration of `Fade`, in seconds. */
    public static inline final FADE_DURATION:Float = 0.12;

    /** gpui-kit's resting thumb width (`THUMB_WIDTH`, `scrollbar.rs:25`). */
    public static inline final GPUI_KIT_THUMB_WIDTH:Float = 6.;

    /** gpui-kit's hovered and dragged thumb width (`THUMB_ACTIVE_WIDTH`, `scrollbar.rs:29`). */
    public static inline final GPUI_KIT_GROWN_THUMB_WIDTH:Float = 8.;

    /** gpui-kit's show duration (`SCROLLBAR_ENTER`, 300 ms), in seconds. */
    public static inline final GPUI_KIT_SHOW_DURATION:Float = 0.3;

    /** gpui-kit's hide duration (`SCROLLBAR_EXIT`, 500 ms), in seconds. */
    public static inline final GPUI_KIT_HIDE_DURATION:Float = 0.5;

    /**
     * gpui-kit's thumb width transition (`SCROLLBAR_EXPAND`, 300 ms), used
     * when `thumbGrowth` is on (0 with `Instant`).
     */
    public static inline final GROWTH_DURATION:Float = 0.3;

    /** The default resting thumb width, in pixels (Loreline Writer's 8 pixel scrollbars). */
    public static inline final DEFAULT_THUMB_WIDTH:Float = 8.;

    /**
     * How much wider the thumb gets when hovered or dragged with
     * `thumbGrowth` and a `thumbWidth` (gpui-kit's 6 to 8 pixels).
     */
    public static inline final THUMB_GROWTH:Float = 2.;

    /** A radius that rounds the thumb fully (clamped to half its width). */
    public static inline final FULL_RADIUS:Float = 9999.;

    /** How the scrollbar shows and hides. */
    public var transition(default, null):ScrollbarTransition;

    /** Seconds to become fully visible, null for the transition's own. */
    public var showDuration(default, null):Null<Float>;

    /** Seconds to disappear once the idle hold ends, null for the transition's own. */
    public var hideDuration(default, null):Null<Float>;

    /** Whether the thumb widens when hovered or dragged. */
    public var thumbGrowth(default, null):Bool;

    /** The resting thumb width in pixels, null for gpui-kit's (6, 8 when grown). */
    public var thumbWidth(default, null):Null<Float> = DEFAULT_THUMB_WIDTH;

    /** The thumb's corner radius, null for the kit theme's `radius`. */
    public var thumbRadius(default, null):Null<Float> = FULL_RADIUS;

    /**
     * An appearance with the default thumb (`DEFAULT_THUMB_WIDTH`, fully
     * rounded); `withThumbWidth` and `withThumbRadius` change it.
     */
    public function new(transition:ScrollbarTransition = Fade, thumbGrowth:Bool = false, ?showDuration:Float, ?hideDuration:Float) {
        this.transition = transition;
        this.thumbGrowth = thumbGrowth;
        this.showDuration = showDuration;
        this.hideDuration = hideDuration;
    }

    function copy():ScrollbarAppearance {
        final result = new ScrollbarAppearance(transition, thumbGrowth, showDuration, hideDuration);
        result.thumbWidth = thumbWidth;
        result.thumbRadius = thumbRadius;
        return result;
    }

    /**
     * A quick fade in place (the default), `duration` seconds each way
     * (`FADE_DURATION` when null), no thumb growth, an 8 pixel fully rounded
     * thumb.
     */
    public static function fade(?duration:Float):ScrollbarAppearance {
        return new ScrollbarAppearance(Fade, false, duration, duration);
    }

    /** Shown and hidden at once, no thumb growth, an 8 pixel fully rounded thumb. */
    public static function instant():ScrollbarAppearance {
        return new ScrollbarAppearance(Instant, false);
    }

    /**
     * gpui-kit's behaviour: slide out while fading, thumb growth on hover,
     * gpui-kit's thumb (6 pixels, 8 when grown, the theme's radius).
     */
    public static function gpuiKit():ScrollbarAppearance {
        final result = new ScrollbarAppearance(GpuiKit, true);
        result.thumbWidth = null;
        result.thumbRadius = null;
        return result;
    }

    /**
     * The startup default: `fade()`, or the preset named by the define
     * `glaze_scrollbar_appearance` (`fade`, `instant`, `gpuikit`; the Glaze
     * golden uses `gpuikit`, to compare with the real gpui-kit).
     */
    public static function defaultValue():ScrollbarAppearance {
        #if glaze_scrollbar_appearance
        final value = haxe.macro.Compiler.getDefine('glaze_scrollbar_appearance');
        return switch value {
            case 'gpuikit' | 'gpui-kit' | 'gpui_kit': gpuiKit();
            case 'instant': instant();
            case _: fade();
        }
        #else
        return fade();
        #end
    }

    /** A copy with another transition (durations and growth kept). */
    public function withTransition(transition:ScrollbarTransition):ScrollbarAppearance {
        final result = copy();
        result.transition = transition;
        return result;
    }

    /** A copy with this show duration in seconds (null: the transition's own). */
    public function withShowDuration(duration:Null<Float>):ScrollbarAppearance {
        final result = copy();
        result.showDuration = duration;
        return result;
    }

    /** A copy with this hide duration in seconds (null: the transition's own). */
    public function withHideDuration(duration:Null<Float>):ScrollbarAppearance {
        final result = copy();
        result.hideDuration = duration;
        return result;
    }

    /** A copy with this show and hide duration in seconds (null: the transition's own). */
    public function withDuration(duration:Null<Float>):ScrollbarAppearance {
        final result = copy();
        result.showDuration = duration;
        result.hideDuration = duration;
        return result;
    }

    /** A copy with the thumb growth on hover and drag turned on or off. */
    public function withThumbGrowth(thumbGrowth:Bool):ScrollbarAppearance {
        final result = copy();
        result.thumbGrowth = thumbGrowth;
        return result;
    }

    /**
     * A copy with this resting thumb width in pixels (null: gpui-kit's 6
     * pixels, 8 when grown). It still sits 4 pixels from the edge: a width
     * above 8 (6 with growth) overflows the 16 pixel band unless the track
     * is widened (`ScrollbarStyles.track(t -> t.width(...))`).
     */
    public function withThumbWidth(width:Null<Float>):ScrollbarAppearance {
        final result = copy();
        result.thumbWidth = width;
        return result;
    }

    /**
     * A copy with this thumb corner radius (`FULL_RADIUS` rounds it fully;
     * null: the kit theme's `radius`).
     */
    public function withThumbRadius(radius:Null<Float>):ScrollbarAppearance {
        final result = copy();
        result.thumbRadius = radius;
        return result;
    }

    /** The resting thumb width in effect, in pixels. */
    public function resolvedThumbWidth():Float {
        return thumbWidth != null ? thumbWidth : GPUI_KIT_THUMB_WIDTH;
    }

    /** The hovered and dragged thumb width when it grows (`thumbGrowth`), in pixels. */
    public function resolvedGrownThumbWidth():Float {
        return thumbWidth != null ? thumbWidth + THUMB_GROWTH : GPUI_KIT_GROWN_THUMB_WIDTH;
    }

    /** The show duration in effect, in seconds (0 for `Instant`). */
    public function resolvedShowDuration():Float {
        return switch transition {
            case Instant: 0.;
            case GpuiKit: showDuration != null ? showDuration : GPUI_KIT_SHOW_DURATION;
            case _: showDuration != null ? showDuration : FADE_DURATION;
        }
    }

    /** The hide duration in effect, in seconds (0 for `Instant`). */
    public function resolvedHideDuration():Float {
        return switch transition {
            case Instant: 0.;
            case GpuiKit: hideDuration != null ? hideDuration : GPUI_KIT_HIDE_DURATION;
            case _: hideDuration != null ? hideDuration : FADE_DURATION;
        }
    }

    /** The thumb width transition in effect, in seconds. */
    public function resolvedGrowthDuration():Float {
        return thumbGrowth && transition != Instant ? GROWTH_DURATION : 0.;
    }

    public function equals(other:ScrollbarAppearance):Bool {
        return other != null
            && transition == other.transition
            && thumbGrowth == other.thumbGrowth
            && showDuration == other.showDuration
            && hideDuration == other.hideDuration
            && thumbWidth == other.thumbWidth
            && thumbRadius == other.thumbRadius;
    }

    public function toString():String {
        final name = switch transition {
            case Instant: 'Instant';
            case GpuiKit: 'GpuiKit';
            case _: 'Fade';
        }
        return 'ScrollbarAppearance($name, thumbGrowth: $thumbGrowth, show: ${resolvedShowDuration()}, hide: ${resolvedHideDuration()}, thumbWidth: $thumbWidth, thumbRadius: $thumbRadius)';
    }

}
