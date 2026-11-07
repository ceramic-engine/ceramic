// Ported from gpui-kit 0.8.1: crates/base/src/overscroll.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.TouchPhase;
import glaze.kit.base.ScrollBounce.Physics;
import glaze.kit.base.ScrollBounce.ScrollBounceMotion;
import glaze.kit.base.motion.MotionTime;

/**
 * Boundary displacement shared by inputs and scroll viewports.
 *
 * Viewport owners keep their logical scroll position clamped and apply this
 * displacement only to content geometry. Inputs drive it directly, while
 * `ScrollBounce` can own a list or scroll area's vertical wheel handling.
 *
 * Times are `Float` seconds (`cx.backgroundExecutor().now()`), compared as
 * whole nanoseconds like Rust's `Instant` and `Duration`.
 */
@:allow(glaze.kit.base)
class Overscroll {

    /**
     * A pause without packets that ends a gesture (250 ms).
     *
     * Momentum arrives once per frame with no phase of its own, and some precise
     * scrolling devices send no phases, so a pause marks the end of their stream.
     * `ScrollBounce` waits the same time for the same reason.
     */
    public static inline final GESTURE_GAP:Float = 0.25;

    /**
     * The fraction of the text's speed the edge carries when the text runs into
     * it or a finger lets go of it. Measured on `NSScrollView`, and the same as
     * WebKit's rubber-band amplitude: a fling arriving at 5000 px/s throws the
     * edge about 45 px out, 80 ms before it turns back.
     */
    static inline final CARRY:Float = 0.31;

    /**
     * A finger that sends nothing for this long before lifting has stopped:
     * it lets go of the edge with no speed (50 ms).
     */
    static inline final STILL:Float = 0.05;

    /** The interval assumed for the first packet of a stream. */
    static inline final FRAME:Float = 1. / 60.;

    /**
     * How far back the stream's speed is read (50 ms). Packets carry no
     * timestamp, so a frame that takes long hands over several at once; read
     * over a span, their distance still spreads over the time they took,
     * instead of each one arriving at once and reading as a huge speed.
     */
    static inline final SPEED_SPAN:Float = 0.05;

    /**
     * The most a packet's unused part can be and still be rounding. Far from
     * its start an `f32` offset cannot hold every fraction, so text that used a
     * whole packet can report a hair more or less, which is not an edge.
     */
    static inline final ROUNDING:Float = 0.01;

    var physics:Physics = new Physics();

    /** In nanoseconds, or `null`. */
    var sampledAt:Null<Float> = null;

    /** In nanoseconds, or `null`. */
    var lastPacketAt:Null<Float> = null;

    /** When the stream last moved (nanoseconds), and how fast, in pixels per second. */
    var movedAt:Null<Float> = null;

    var velocity:Float = 0.;

    /**
     * The packets that moved within the last `SPEED_SPAN` (times in
     * nanoseconds and deltas), and the one before them, which marks where
     * the span starts.
     */
    var moveTimes:Array<Float> = [];

    var moveDeltas:Array<Float> = [];

    /** A finger rests on the trackpad but has not moved since it touched. */
    var resting:Bool = false;

    /**
     * The edge already answered the rest of this gesture: a fling ran into
     * it, or a finger let go of it stretched. The momentum that follows
     * still scrolls the text back from the edge, but no longer moves the
     * edge.
     */
    var spent:Bool = false;

    public function new() {}

    public function setMotion(motion:ScrollBounceMotion):Void {
        physics.setMotion(motion);
    }

    /** How far the text is drawn from where it scrolled to. */
    public function offset():Float {
        return physics.offset();
    }

    /** A new gesture starts: it may stretch the edge again. */
    function startGesture():Void {
        spent = false;
        velocity = 0.;
        moveTimes.resize(0);
        moveDeltas.resize(0);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    static inline function since(now:Float, at:Float):Float {
        return now > at ? now - at : 0.;
    }

    /**
     * Track the stream's speed from packets that moved: the distance they
     * covered over the time since the span started.
     */
    function sample(dy:Float, now:Float):Void {
        if (dy == 0.) {
            return;
        }
        if (moveDeltas.length > 0 && moveDeltas[moveDeltas.length - 1] * dy < 0.) {
            moveTimes.resize(0);
            moveDeltas.resize(0);
        }
        moveTimes.push(now);
        moveDeltas.push(dy);
        final span = MotionTime.nanos(SPEED_SPAN);
        var start = 0;
        var i = moveTimes.length - 1;
        while (i >= 0) {
            if (since(now, moveTimes[i]) > span) {
                start = i;
                break;
            }
            i--;
        }
        if (start > 0) {
            moveTimes.splice(0, start);
            moveDeltas.splice(0, start);
        }
        final first = moveTimes[0];
        final seconds = MotionTime.asSecsF32(since(now, first));
        if (seconds > 0. && moveDeltas.length > 1) {
            var sum = 0.;
            for (j in 1...moveDeltas.length) sum = f32(sum + moveDeltas[j]);
            velocity = f32(sum / seconds);
        }
        else {
            // The first packet, or several handed over at once.
            var sum = 0.;
            for (d in moveDeltas) sum = f32(sum + d);
            velocity = f32(sum / f32(FRAME));
        }
        movedAt = now;
    }

    /**
     * Handle one vertical packet of `dy` over a viewport `extent` tall, at
     * `now` (seconds). `scroll` moves the text by a delta and returns how
     * much of it the text used. Returns whether the stretch changed.
     */
    public function packet(dy:Float, phase:TouchPhase, extent:Float, nowSeconds:Float, scroll:(Float) -> Float):Bool {
        final now = MotionTime.nanos(nowSeconds);
        final before = offset();
        var thrown = false;
        final last = lastPacketAt;
        lastPacketAt = now;
        final gap:Null<Float> = last != null && since(now, last) < MotionTime.nanos(GESTURE_GAP) ? since(now, last) : null;
        // A finger resting on the trackpad sends nothing, however long it
        // holds the edge; only its own `Ended` lets go. A pause ends the
        // other streams.
        if (gap == null && !physics.isDragging()) {
            startGesture();
            movedAt = null;
        }
        sample(dy, now);
        if (phase == Started) {
            // Grab the edge, a returning one included, where it is.
            physics.begin(extent);
            spent = false;
            resting = dy == 0.;
        }
        else if (dy != 0.) {
            resting = false;
        }
        else if (resting && physics.isDragging()) {
            // A finger that touches and lifts without moving cancels its
            // gesture, and GPUI reports the cancel as a move of nothing: it
            // lets go of the edge where it held it.
            resting = false;
            physics.letGo(0.);
            spent = offset() != 0.;
            if (spent) {
                sampledAt = now;
            }
            return physics.isMoving();
        }
        if (physics.isDragging()) {
            // A stretched edge takes the packet first; only what crosses back
            // over the edge scrolls the text.
            final rest = offset() != 0. ? physics.pull(dy) : dy;
            if (rest != 0.) {
                final unused = f32(rest - scroll(rest));
                if (Math.abs(unused) > ROUNDING) {
                    physics.pull(unused);
                }
            }
            if (phase == Ended || phase == Cancelled) {
                final moving = movedAt != null && since(now, movedAt) < MotionTime.nanos(STILL);
                // Only an edge held past its end carries the finger's speed.
                // Let go within the text, the momentum that follows scrolls
                // it, and throws the edge only if it runs into it.
                final velocity = moving && offset() != 0. ? this.velocity : 0.;
                physics.letGo(f32(velocity * CARRY));
                thrown = true;
                spent = offset() != 0.;
            }
        }
        else if (spent) {
            // Momentum after the edge answered: back into the text it
            // scrolls; against the edge it has nothing left to move.
            scroll(dy);
        }
        else {
            // Momentum or phaseless precise scrolling: it scrolls the text,
            // and when the text runs into the edge it throws the edge as
            // fast as it arrived, once.
            final unused = f32(dy - scroll(dy));
            if (Math.abs(unused) > ROUNDING) {
                physics.letGo(f32(velocity * CARRY));
                thrown = true;
                spent = true;
            }
        }
        final changed = (thrown && physics.isMoving()) || offset() != before;
        // Start the clock when the edge starts moving, and again when it is
        // let go, however long it was held; a packet that arrives while it
        // moves must not lose the time since the last frame.
        if (thrown || (changed && sampledAt == null)) {
            sampledAt = now;
        }
        return changed;
    }

    /** Advance the return to `now` (seconds). Returns whether it is still moving. */
    public function step(nowSeconds:Float):Bool {
        final now = MotionTime.nanos(nowSeconds);
        final last = sampledAt;
        sampledAt = now;
        final elapsed = last == null ? 0. : MotionTime.asSecsF32(since(now, last));
        final moving = physics.step(elapsed);
        if (!moving) {
            sampledAt = null;
        }
        return moving;
    }

    /** Drop any stretch at once, as when bouncing is turned off. */
    public function reset():Void {
        physics.reset();
        sampledAt = null;
        lastPacketAt = null;
        movedAt = null;
        velocity = 0.;
        moveTimes = [];
        moveDeltas = [];
        resting = false;
        spent = false;
    }

}
