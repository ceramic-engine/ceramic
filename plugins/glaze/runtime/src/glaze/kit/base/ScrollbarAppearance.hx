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
 *   (gpui-kit's 6 to 8 pixels). Off by default: the thumb keeps its resting
 *   width and inset in every state, only its color changes.
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

    /** gpui-kit's show duration (`SCROLLBAR_ENTER`, 300 ms), in seconds. */
    public static inline final GPUI_KIT_SHOW_DURATION:Float = 0.3;

    /** gpui-kit's hide duration (`SCROLLBAR_EXIT`, 500 ms), in seconds. */
    public static inline final GPUI_KIT_HIDE_DURATION:Float = 0.5;

    /**
     * gpui-kit's thumb width transition (`SCROLLBAR_EXPAND`, 300 ms), used
     * when `thumbGrowth` is on (0 with `Instant`).
     */
    public static inline final GROWTH_DURATION:Float = 0.3;

    /** How the scrollbar shows and hides. */
    public var transition(default, null):ScrollbarTransition;

    /** Seconds to become fully visible, null for the transition's own. */
    public var showDuration(default, null):Null<Float>;

    /** Seconds to disappear once the idle hold ends, null for the transition's own. */
    public var hideDuration(default, null):Null<Float>;

    /** Whether the thumb widens when hovered or dragged. */
    public var thumbGrowth(default, null):Bool;

    public function new(transition:ScrollbarTransition = Fade, thumbGrowth:Bool = false, ?showDuration:Float, ?hideDuration:Float) {
        this.transition = transition;
        this.thumbGrowth = thumbGrowth;
        this.showDuration = showDuration;
        this.hideDuration = hideDuration;
    }

    /**
     * A quick fade in place (the default), `duration` seconds each way
     * (`FADE_DURATION` when null), no thumb growth.
     */
    public static function fade(?duration:Float):ScrollbarAppearance {
        return new ScrollbarAppearance(Fade, false, duration, duration);
    }

    /** Shown and hidden at once, no thumb growth. */
    public static function instant():ScrollbarAppearance {
        return new ScrollbarAppearance(Instant, false);
    }

    /** gpui-kit's behaviour: slide out while fading, thumb growth on hover. */
    public static function gpuiKit():ScrollbarAppearance {
        return new ScrollbarAppearance(GpuiKit, true);
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
        return new ScrollbarAppearance(transition, thumbGrowth, showDuration, hideDuration);
    }

    /** A copy with this show duration in seconds (null: the transition's own). */
    public function withShowDuration(duration:Null<Float>):ScrollbarAppearance {
        return new ScrollbarAppearance(transition, thumbGrowth, duration, hideDuration);
    }

    /** A copy with this hide duration in seconds (null: the transition's own). */
    public function withHideDuration(duration:Null<Float>):ScrollbarAppearance {
        return new ScrollbarAppearance(transition, thumbGrowth, showDuration, duration);
    }

    /** A copy with this show and hide duration in seconds (null: the transition's own). */
    public function withDuration(duration:Null<Float>):ScrollbarAppearance {
        return new ScrollbarAppearance(transition, thumbGrowth, duration, duration);
    }

    /** A copy with the thumb growth on hover and drag turned on or off. */
    public function withThumbGrowth(thumbGrowth:Bool):ScrollbarAppearance {
        return new ScrollbarAppearance(transition, thumbGrowth, showDuration, hideDuration);
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
            && hideDuration == other.hideDuration;
    }

    public function toString():String {
        final name = switch transition {
            case Instant: 'Instant';
            case GpuiKit: 'GpuiKit';
            case _: 'Fade';
        }
        return 'ScrollbarAppearance($name, thumbGrowth: $thumbGrowth, show: ${resolvedShowDuration()}, hide: ${resolvedHideDuration()})';
    }

}
