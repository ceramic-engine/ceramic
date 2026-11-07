// Ported from gpui-kit 0.8.1: crates/base/src/input/base/blink_cursor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Context;
import glaze.Model;
import glaze.Pixels;
import glaze.Subscription;
import glaze.Task;
import glaze.Unit;
import glaze.kit.base.theme.Theme as BaseTheme;

/**
 * The caret blink of a focused input: an entity that toggles `visible` on
 * timers of the app's executor (so a test clock that never advances never
 * hides a caret).
 */
class BlinkCursor extends Model {

    /** 500 ms. */
    public static inline final INTERVAL:Float = 0.5;

    /** 300 ms. */
    public static inline final PAUSE_DELAY:Float = 0.3;

    public static inline final CURSOR_WIDTH:Pixels = 1.;

    var _visible:Bool = false;

    var paused:Bool = false;

    var epoch:Int = 0;

    var lastActivity:Null<Float> = null;

    var policy:CursorBlink;

    @:allow(tests)
    var _task:Task<Unit>;

    var _policySubscription:Subscription;

    public function new(cx:Context<BlinkCursor>) {
        super();
        policy = cursorBlink(cx.app);
        _task = Task.done();
        _policySubscription = cx.observeGlobal(BaseTheme, (this_, cx) -> {
            final policy = cursorBlink(cx.app);
            if (policy.equals(this_.policy)) {
                return;
            }
            this_.policy = policy;
            if (this_.lastActivity != null) {
                this_.epoch = this_.epoch + 1;
                this_.setVisible(true, cx);
                this_.schedule(cx);
            }
        });
    }

    /**
     * The policy of the Base theme (Rust `theme.cursor_blink`), normalized.
     */
    static function cursorBlink(cx:App):CursorBlink {
        final theme = cx.tryGlobal(BaseTheme);
        final policy = theme != null ? theme.cursorBlink : null;
        return (policy != null ? policy : CursorBlink.defaultValue()).normalized();
    }

    public function start(cx:Context<BlinkCursor>):Void {
        epoch = epoch + 1;
        lastActivity = cx.backgroundExecutor().now();
        paused = false;
        setVisible(true, cx);
        schedule(cx);
    }

    public function stop(cx:Context<BlinkCursor>):Void {
        epoch = epoch + 1;
        lastActivity = null;
        paused = false;
        replaceTask(Task.done());
        setVisible(false, cx);
    }

    public function pause(cx:Context<BlinkCursor>):Void {
        if (lastActivity == null) {
            return;
        }

        epoch = epoch + 1;
        lastActivity = cx.backgroundExecutor().now();
        paused = true;
        setVisible(true, cx);
        schedule(cx);
    }

    public inline function visible():Bool {
        return _visible;
    }

    function setVisible(visible:Bool, cx:Context<BlinkCursor>):Void {
        if (_visible != visible) {
            _visible = visible;
            cx.notify();
        }
    }

    /** Rust drops the previous task when it assigns `_task`: cancel it. */
    function replaceTask(task:Task<Unit>):Void {
        final previous = _task;
        _task = task;
        if (previous != null && previous != task) previous.cancel();
    }

    /**
     * The delay before the next toggle, or null when the caret should stay
     * visible. Durations are rounded to whole nanoseconds like Rust's
     * `Duration`, so that float sums of the test clock land on the same
     * boundaries.
     */
    function blinkDelay(cx:App):Null<Float> {
        if (lastActivity == null) return null;
        final interval = policy.interval();
        if (interval == null) return null;

        final elapsed = nanos(cx.backgroundExecutor().now() - lastActivity);
        final delay = if (paused && elapsed < nanos(PAUSE_DELAY)) {
            nanos(PAUSE_DELAY) - elapsed;
        }
        else {
            nanos(interval);
        }

        final timeout = policy.idleTimeout();
        if (timeout != null) {
            final timeout = nanos(timeout);
            if (elapsed >= timeout) return null;
            final remaining = timeout - elapsed;
            return seconds(delay < remaining ? delay : remaining);
        }
        return seconds(delay);
    }

    function schedule(cx:Context<BlinkCursor>):Void {
        replaceTask(Task.done());
        final delay = blinkDelay(cx.app);
        if (delay == null) {
            paused = false;
            setVisible(true, cx);
            return;
        }

        final epoch = this.epoch;
        final timer = cx.backgroundExecutor().timer(delay);
        replaceTask(cx.spawn((this_, acx) -> timer.then(_ -> {
            this_.tryUpdate(acx, (this_, cx) -> {
                if (epoch != this_.epoch) {
                    return;
                }

                if (this_.blinkDelay(cx.app) != null) {
                    this_.paused = false;
                    this_.setVisible(!this_._visible, cx);
                }
                this_.schedule(cx);
            });
        })));
    }

    static inline function nanos(seconds:Float):Float {
        return Math.fround(seconds * 1e9);
    }

    static inline function seconds(nanos:Float):Float {
        return nanos / 1e9;
    }

}
