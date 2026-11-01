// Ported from gpui-kit 0.8.1: crates/base/src/auto_scroll.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.Bounds;
import gpui.Context;
import gpui.Point;
import gpui.Task;
import gpui.Unit;

/**
 * Manages timer-based auto-scrolling during drag interactions.
 *
 * Delta convention: positive moves toward the bottom and negative moves
 * toward the top.
 *
 * Differences with gpui-kit: the delta shared with the task is a plain
 * field (single threaded), and the loop is a chain of 16 ms timers owned by
 * the entity (cancelled by `stop` or a null delta, like dropping the Rust
 * task).
 */
class AutoScroll {

    /**
     * Shared with the timer loop. `null` is the stop signal; the loop exits
     * on its next tick.
     */
    var shared:Null<Float> = null;

    var task:Null<Task<Unit>> = null;

    /** Bumped when the loop is cancelled, so a pending tick stops. */
    var generation:Int = 0;

    /** Last drag position, available to the interaction that owns selection. */
    public var lastDragPosition:Null<Point> = null;

    public function new() {}

    /** Returns the current scroll delta. */
    public inline function delta():Null<Float> {
        return shared;
    }

    /** Computes the scroll delta for a pointer Y position within the viewport. */
    public static function computeDelta(y:Float, bounds:Bounds):Null<Float> {
        final MIN_SPEED = 12.0;
        final MAX_SPEED = 64.0;
        // Trigger starts this far inside the bounds so scrolling works even in
        // full-screen where the mouse can't travel far outside the element.
        final INNER_ZONE = 16.0;
        // Distance from the bounds edge to reach MAX_SPEED.
        // Total ramp = INNER_ZONE + OUTER_RAMP, giving a single smooth curve
        // with no flat sections or discontinuities.
        final OUTER_RAMP = 80.0;

        final bottomTrigger = bounds.bottom() - INNER_ZONE;
        final topTrigger = bounds.top() + INNER_ZONE;

        if (y > bottomTrigger) {
            final t = Math.min(f32((y - bottomTrigger) / (INNER_ZONE + OUTER_RAMP)), 1.0);
            return f32(MIN_SPEED + f32(t * (MAX_SPEED - MIN_SPEED)));
        }
        else if (y < topTrigger) {
            final t = Math.min(f32((topTrigger - y) / (INNER_ZONE + OUTER_RAMP)), 1.0);
            return -f32(MIN_SPEED + f32(t * (MAX_SPEED - MIN_SPEED)));
        }
        return null;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    /**
     * Updates the scroll delta and starts the timer loop when needed.
     *
     * `tick` is called each frame (~60 fps) with the current delta.
     * It should perform the actual scroll action for this entity.
     */
    public function set<T:gpui.Model>(delta:Null<Float>, cx:Context<T>, tick:(Float, T, Context<T>) -> Void):Void {
        final wasIdle = task == null;
        shared = delta;

        if (delta == null) {
            cancelTask();
            return;
        }

        if (wasIdle) {
            task = cx.spawn((weak, async) -> loop(weak, async, tick));
        }
    }

    function loop<T:gpui.Model>(weak:gpui.WeakEntity<T>, cx:gpui.AsyncApp, tick:(Float, T, Context<T>) -> Void):Task<Unit> {
        final done = new Task<Unit>();
        final generation = this.generation;
        function next():Void {
            cx.backgroundExecutor().timer(0.016).then(_ -> {
                if (generation != this.generation || done.isCancelled) {
                    return;
                }
                final delta = shared;
                if (delta == null || weak.upgrade() == null) {
                    done.resolve(Unit.unit);
                    return;
                }
                weak.update(cx, (state, cx) -> {
                    tick(delta, state, cx);
                    return null;
                });
                next();
            });
        }
        next();
        return done;
    }

    function cancelTask():Void {
        generation++;
        final task = this.task;
        this.task = null;
        if (task != null) {
            task.cancel();
        }
    }

    /** Returns whether automatic scrolling is active. */
    public inline function isActive():Bool {
        return delta() != null;
    }

    /** Stops automatic scrolling and clears the last drag position. */
    public function stop():Void {
        shared = null;
        cancelTask();
        lastDragPosition = null;
    }

}
