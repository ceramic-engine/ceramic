// Ported from gpui-kit 0.8.1: crates/base/src/plot/mod.rs (PlotMotion)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

import glaze.kit.base.motion.Spring;
import glaze.kit.base.motion.Transition;

/**
 * The timing of a plot's motion: how its data marks appear when it is first
 * painted, how its hover progress fades in and out, and the spring a pointer
 * follows the hovered datum with.
 *
 * Base installs no motion of its own: every duration defaults to zero, so the
 * hover appears, fades and glides at once. Product timing belongs to the
 * styled layer, which projects it through `PlotTheme`.
 *
 * The builders return a modified copy, like Rust's consuming builders.
 */
class PlotMotion {

    var pointerValue:Spring;

    var enterValue:Transition;

    var exitValue:Transition;

    var appearValue:Transition;

    public function new() {
        pointerValue = new Spring(0);
        enterValue = new Transition(0);
        exitValue = new Transition(0);
        appearValue = new Transition(0);
    }

    function copy():PlotMotion {
        final motion = new PlotMotion();
        motion.pointerValue = pointerValue;
        motion.enterValue = enterValue;
        motion.exitValue = exitValue;
        motion.appearValue = appearValue;
        return motion;
    }

    /**
     * The spring a crosshair, highlight band or hover dot follows the hovered
     * datum with.
     */
    public function withPointer(pointer:Spring):PlotMotion {
        final motion = copy();
        motion.pointerValue = pointer;
        return motion;
    }

    /** How the hover fades in when the cursor lands on a datum. */
    public function withEnter(enter:Transition):PlotMotion {
        final motion = copy();
        motion.enterValue = enter;
        return motion;
    }

    /** How the hover fades out after the cursor leaves. */
    public function withExit(exit:Transition):PlotMotion {
        final motion = copy();
        motion.exitValue = exit;
        return motion;
    }

    /**
     * How a plot's data marks appear the first time it is painted; see
     * `PlotAppear`.
     */
    public function withAppear(appear:Transition):PlotMotion {
        final motion = copy();
        motion.appearValue = appear;
        return motion;
    }

    public inline function pointer():Spring {
        return pointerValue;
    }

    public inline function enter():Transition {
        return enterValue;
    }

    public inline function exit():Transition {
        return exitValue;
    }

    public inline function appear():Transition {
        return appearValue;
    }

}
