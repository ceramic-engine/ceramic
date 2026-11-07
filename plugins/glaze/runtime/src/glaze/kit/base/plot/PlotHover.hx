// Ported from gpui-kit 0.8.1: crates/base/src/plot/hover.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

import glaze.App;
import glaze.Pixels;
import glaze.Point;
import glaze.Window;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.Spring;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.base.theme.Theme;

/**
 * The datum a plot has under the pointer this frame, handed to
 * `Plot.updateHover`.
 *
 * Carries the `TooltipState` the cursor resolved to and how far the hover
 * has faded in. After the cursor leaves, the state lingers here while the
 * progress eases back to zero, so a hover-driven presentation can fade out
 * over the last datum instead of vanishing.
 *
 * Hover tracking shared by every plot: which datum the cursor is on, how far
 * its hover has faded in, and where a pointer following it has glided to.
 */
class PlotHover {

    final stateValue:TooltipState;

    final progressValue:Float;

    final hovered:Bool;

    @:allow(glaze.kit.base.plot)
    @:allow(tests)
    function new(state:TooltipState, progress:Float, hovered:Bool) {
        this.stateValue = state;
        this.progressValue = progress;
        this.hovered = hovered;
    }

    /**
     * The hovered datum: the one under the cursor, or the last one while the
     * hover fades out.
     */
    public inline function state():TooltipState {
        return stateValue;
    }

    /**
     * How far the hover has faded in, from `0` to `1`.
     */
    public inline function progress():Float {
        return progressValue;
    }

    /**
     * Whether the cursor is on the datum, as opposed to the state lingering
     * while its hover fades out.
     */
    public inline function isHovered():Bool {
        return hovered;
    }

    /**
     * Whether this is the first frame the cursor is on a datum: the hover has
     * not started fading in yet.
     */
    public inline function isEntering():Bool {
        return hovered && progressValue == 0.;
    }

    /**
     * Follow `target` on the pointer spring, adopting the target on the
     * entering frame instead of travelling from where the last hover ended.
     */
    public function glide(id:TransitionId, target:Pixels, window:Window, cx:App):Pixels {
        final policy = pointerSpring(cx).withTravel(!isEntering());
        return Motion.spring(id, target, policy, window, cx);
    }

    /**
     * The spring a hover pointer (the crosshair, highlight band or hover dot)
     * follows the hovered datum with: the active `PlotMotion`'s pointer.
     */
    public static function pointerSpring(cx:App):Spring {
        return Theme.global(cx).plot.motion().pointer();
    }

    /** The element-state key of a plot's `HoverMemory`, within the plot's scope. */
    static inline final HOVER_MEMORY:String = '__plot-hover';

    /**
     * Resolve the datum a plot shows this frame from the `live` state the
     * cursor resolved to. Called by `PlotElement` within the plot's element
     * scope; the returned cursor is the live one, or the last one while the
     * state lingers.
     */
    @:allow(glaze.kit.base.plot)
    static function trackHover(live:Null<TooltipState>, cursor:Null<Point>, window:Window, cx:App):Null<{hover:PlotHover, cursor:Point}> {
        final hovered = live != null;
        final memory = memoryState(window, cx);

        final motion = Theme.global(cx).plot.motion();
        final policy = hovered ? motion.enter() : motion.exit();
        // The progress fades a presentation, so an overshooting curve is clamped.
        final raw = Motion.transition(TransitionId.named(HOVER_MEMORY, 'progress'), hovered ? 1. : 0., policy, window, cx);
        final progress = raw < 0. ? 0. : (raw > 1. ? 1. : raw);

        if (live != null && cursor != null) {
            memory.state = live;
            memory.cursor = cursor;
        }
        memory.progress = progress;
        memory.entering = hovered && progress == 0.;
        if (!hovered && progress <= 0.) {
            memory.state = null;
        }

        final state = memory.state;
        if (state == null) {
            return null;
        }
        return {hover: new PlotHover(state, progress, hovered), cursor: memory.cursor};
    }

    static function memoryState(window:Window, cx:App):HoverMemory {
        final state:glaze.Window.StateModel<HoverMemory> = window.useKeyedState(HOVER_MEMORY, cx, _ -> new HoverMemory());
        return state.value;
    }

    /**
     * How far the enclosing plot's hover has faded in this frame, from `0`
     * to `1`, for an overlay a plot returns from `Plot.tooltip`, which
     * renders within the plot's element scope. Anywhere else it reads no
     * tracked hover and returns `1`.
     */
    public static function hoverProgress(window:Window, cx:App):Float {
        return memoryState(window, cx).progress;
    }

    /**
     * Whether this frame is the first the enclosing plot's cursor is on a
     * datum; see `isEntering`. Anywhere but a plot's overlay it returns
     * `false`.
     */
    public static function isHoverEntering(window:Window, cx:App):Bool {
        return memoryState(window, cx).entering;
    }

}

/**
 * The last datum the cursor resolved to, where the cursor was and how far
 * the hover has faded in, kept in element state.
 */
private class HoverMemory {

    public var state:Null<TooltipState> = null;

    public var cursor:Point = new Point(0, 0);

    /** An overlay rendered outside a plot's tracking is fully opaque. */
    public var progress:Float = 1.;

    public var entering:Bool = false;

    public function new() {}

}
