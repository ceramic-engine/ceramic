// Ported from gpui-kit 0.8.1: crates/base/src/input/base/blink_cursor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Application-wide caret visibility policy (read from the Base theme).
 *
 * The default blinks every 500 ms without an idle timeout. Durations are in
 * seconds (Rust `Duration`).
 */
class CursorBlink {

    final _interval:Float;

    final _idleTimeout:Null<Float>;

    function new(interval:Float, idleTimeout:Null<Float>) {
        this._interval = interval;
        this._idleTimeout = idleTimeout;
    }

    /** Keep the focused caret visible without a timer. */
    public static function steady():CursorBlink {
        return new CursorBlink(0, null);
    }

    /** Alternate visible and hidden phases of `interval` each; zero means steady. */
    public static function blinking(interval:Float):CursorBlink {
        return new CursorBlink(interval, null);
    }

    /**
     * Stop blinking, with the caret visible, once `timeout` has passed since
     * the last focus, edit or cursor movement. Returns a new policy.
     */
    public function withIdleTimeout(timeout:Float):CursorBlink {
        return new CursorBlink(_interval, timeout);
    }

    /** The duration of each visible or hidden phase, or null when steady. */
    public function interval():Null<Float> {
        return _interval != 0 ? _interval : null;
    }

    /** The time since the last activity after which blinking stops. */
    public function idleTimeout():Null<Float> {
        return interval() != null ? _idleTimeout : null;
    }

    /** Whether the focused caret stays visible without blinking. */
    public function isSteady():Bool {
        return _interval == 0;
    }

    /**
     * Collapse every steady spelling to one value, so a change between them
     * is not mistaken for a policy change.
     */
    @:allow(gpui.base.input, tests)
    function normalized():CursorBlink {
        return isSteady() ? steady() : this;
    }

    /** `CursorBlink::default()`: blinking every 500 ms. */
    public static function defaultValue():CursorBlink {
        return blinking(BlinkCursor.INTERVAL);
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<CursorBlink>):Bool {
        return other != null && other._interval == _interval && other._idleTimeout == _idleTimeout;
    }

    public function toString():String {
        return 'CursorBlink { interval: ' + _interval + ', idle_timeout: ' + _idleTimeout + ' }';
    }

}
