// Ported from gpui-pre 0.3.10: src/gestures.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

using gpui.ScrollPhysics.ScrollPhysicsTools;

/**
 * A semantic event recognized from raw touches, ready to dispatch through
 * the window's existing input paths.
 */
enum RecognizedTouchGesture {

    /**
     * One step of a pan (or of its post-release momentum), delivered to
     * scroll listeners at the pan's starting position.
     */
    Scroll(event:ScrollEvent);

    /** A recognized tap, delivered as a synthesized mouse press and release. */
    Tap(down:MouseDownEvent, up:MouseUpEvent);

    TouchDrag(event:TouchDragEvent);

    LongPress(event:LongPressEvent);

}

private class ActiveTouch {

    public final id:TouchId;

    public final startPosition:Point;

    /** The latest raw position reported for this touch. */
    public var lastPosition:Point;

    /**
     * The position pan output has scrolled to so far. While panning this may
     * run ahead of the raw touch by the event's predicted position; the
     * release event targets the raw position again, so the total scrolled
     * distance always converges to the finger's actual travel.
     */
    public var emittedPosition:Point;

    /**
     * Retained across stationary samples so prediction corrections cannot
     * reverse a pan when integer browser coordinates repeat.
     */
    public var lastMovement:Point;

    public final velocityTracker:VelocityTracker;

    public function new(id:TouchId, position:Point, velocityTracker:VelocityTracker) {
        this.id = id;
        this.startPosition = position;
        this.lastPosition = position;
        this.emittedPosition = position;
        this.lastMovement = new Point(0, 0);
        this.velocityTracker = velocityTracker;
    }

}

private enum TouchGestureState {

    Idle;

    /**
     * The touch is still within `touchSlop` of where it started: it can still
     * resolve into either a tap or a pan.
     */
    Pending(touch:ActiveTouch, deadline:Float, longPressOffered:Bool, touchDragOffered:Bool);

    /**
     * The touch exceeded `touchSlop`: it is a pan until it ends, and its
     * movement flows out as scroll events.
     */
    Panning(touch:ActiveTouch, axis:Axis);

    /**
     * The touch caught a fling: it is a pan from its first pixel, and can
     * never be a tap, but its axis is its own, decided by its first movement.
     */
    Caught(touch:ActiveTouch);

    LongPressing(touch:ActiveTouch);

    TouchDragging(touch:ActiveTouch);

}

private class CompletedTap {

    public final position:Point;

    public final time:Float;

    public final count:Int;

    public function new(position:Point, time:Float, count:Int) {
        this.position = position;
        this.time = time;
        this.count = count;
    }

}

/**
 * One fling in progress. The trajectory is a closed-form curve of elapsed
 * time, so the fling is exactly frame-rate independent.
 */
private class Momentum {

    /** Where the pan started; synthesized scroll events keep hit-testing there. */
    public final position:Point;

    /** Unit vector of the release velocity (x, y). */
    public final directionX:Float;

    public final directionY:Float;

    /** Release speed in pixels per second. */
    public final speed:Float;

    public final startedAt:Float;

    public final duration:Float;

    /** Distance already emitted along the direction, in pixels. */
    public var emittedDistance:Float;

    public function new(position:Point, directionX:Float, directionY:Float, speed:Float, startedAt:Float, duration:Float, emittedDistance:Float) {
        this.position = position;
        this.directionX = directionX;
        this.directionY = directionY;
        this.speed = speed;
        this.startedAt = startedAt;
        this.duration = duration;
        this.emittedDistance = emittedDistance;
    }

}

/**
 * The portable recognizer behind raw touch input: it watches the
 * `TouchEvent` stream for one touch at a time and resolves it into either a
 * tap or a pan. Pans continue into post-release momentum when the touch lifts
 * at speed; the window drives that phase through `tickMomentum`.
 *
 * Taps are surfaced as synthesized mouse presses rather than
 * `ClickEvent.Touch`, which keeps every existing mouse-driven behavior (click
 * listeners, caret placement, double-tap selection) working. Pinch
 * recognition is not implemented (in GPUI either), and additional touches
 * are ignored while one is being recognized.
 *
 * Differences with GPUI: times are seconds read by the caller from the
 * executor clock (Rust reads `Instant::now()`); `handleEvent`,
 * `pendingLongPress` and `tickMomentum` take that time (Rust's `*_at`
 * variants). Points are immutable, so locked deltas are new points.
 */
class TouchGestureRecognizer {

    /** Ceiling on recognized fling velocity, in pixels per second (Flutter's `kMaxFlingVelocity`). */
    static inline final MAX_FLING_VELOCITY:Float = 8000.;

    /** How far back the release-velocity estimate looks (seconds). */
    public static inline final VELOCITY_WINDOW:Float = 0.1;

    /**
     * A pause between samples longer than this means the finger stopped
     * (seconds, Flutter's `kAssumePointerMoveStoppedMilliseconds`).
     */
    public static inline final VELOCITY_ASSUME_STOPPED_GAP:Float = 0.04;

    public static inline final VELOCITY_MAX_SAMPLES:Int = 20;

    final tuning:GestureTuning;

    var state:TouchGestureState = Idle;

    var momentum:Null<Momentum> = null;

    var lastTap:Null<CompletedTap> = null;

    public function new(tuning:GestureTuning) {
        this.tuning = tuning;
    }

    static inline function dominantAxis(delta:Point):Axis {
        return Math.abs(delta.x) <= Math.abs(delta.y) ? Vertical : Horizontal;
    }

    static inline function lockDeltaToAxis(delta:Point, axis:Axis):Point {
        return switch axis {
            case Vertical: new Point(0, delta.y);
            case Horizontal: new Point(delta.x, 0);
        }
    }

    static inline function movementsOppose(left:Point, right:Point):Bool {
        return left.x * right.x + left.y * right.y < 0.;
    }

    static function scrollEvent(position:Point, delta:Point, touchPhase:TouchPhase):ScrollEvent {
        return new ScrollEvent(position, ScrollDelta.Pixels(delta), Modifiers.none(), touchPhase, ScrollSource.Touch);
    }

    /**
     * Feeds one raw touch event at time `now` (seconds) and returns the
     * gestures it resolves (Rust `handle_event_at`).
     */
    public function handleEvent(event:TouchEvent, now:Float):Array<RecognizedTouchGesture> {
        final recognized:Array<RecognizedTouchGesture> = [];
        switch event.phase {
            case Started:
                var caughtFling = false;
                final momentum = this.momentum;
                if (momentum != null) {
                    this.momentum = null;
                    recognized.push(Scroll(scrollEvent(momentum.position, new Point(0, 0), Ended)));
                    caughtFling = true;
                }
                if (state.match(Idle)) {
                    final velocityTracker = new VelocityTracker();
                    velocityTracker.push(now, event.position);
                    final touch = new ActiveTouch(event.id, event.position, velocityTracker);
                    if (caughtFling) {
                        // A touch that catches a fling is a drag from the
                        // first pixel. It can also never be a tap; releasing
                        // it just leaves the content stopped. Which way it
                        // pans is its own to decide.
                        recognized.push(Scroll(scrollEvent(touch.startPosition, new Point(0, 0), Started)));
                        state = Caught(touch);
                    }
                    else {
                        state = Pending(touch, now + tuning.longPressDuration, false, false);
                    }
                }

            case Moved:
                final current = state;
                state = Idle;
                switch current {
                    case Pending(touch, deadline, longPressOffered, touchDragOffered) if (touch.id == event.id):
                        touch.velocityTracker.push(now, event.position);
                        touch.lastPosition = event.position;
                        final accumulated = event.position.sub(touch.startPosition);
                        if (accumulated.magnitude() > tuning.touchSlop) {
                            // Carry the full movement so far into the first
                            // scroll step: the content catches up to the
                            // finger instead of losing the slop distance.
                            var target = event.predictedPosition != null ? event.predictedPosition : event.position;
                            final axis = dominantAxis(accumulated);
                            var delta = lockDeltaToAxis(target.sub(touch.startPosition), axis);
                            touch.lastMovement = lockDeltaToAxis(accumulated, axis);
                            if (movementsOppose(delta, touch.lastMovement)) {
                                target = event.position;
                                delta = lockDeltaToAxis(accumulated, axis);
                            }
                            touch.emittedPosition = target;
                            recognized.push(Scroll(scrollEvent(touch.startPosition, delta, Started)));
                            state = Panning(touch, axis);
                        }
                        else {
                            state = Pending(touch, deadline, longPressOffered, touchDragOffered);
                        }

                    case Caught(touch) if (touch.id == event.id):
                        final accumulated = event.position.sub(touch.startPosition);
                        if (accumulated.isZero()) {
                            state = Caught(touch);
                        }
                        else {
                            // The first movement picks the axis; from here on
                            // this is an ordinary pan.
                            state = Panning(touch, dominantAxis(accumulated));
                            return handleEvent(event, now);
                        }

                    case Panning(touch, axis) if (touch.id == event.id):
                        final rawDelta = lockDeltaToAxis(event.position.sub(touch.lastPosition), axis);
                        if (!rawDelta.isZero()) {
                            touch.lastMovement = rawDelta;
                        }
                        touch.velocityTracker.push(now, event.position);
                        touch.lastPosition = event.position;
                        var target = event.predictedPosition != null ? event.predictedPosition : event.position;
                        var delta = lockDeltaToAxis(target.sub(touch.emittedPosition), axis);
                        // Prediction error must not reverse content while the
                        // raw touch still advances. Fall back to the raw
                        // position so a real finger reversal remains
                        // responsive.
                        if (movementsOppose(delta, touch.lastMovement)) {
                            target = event.position;
                            delta = lockDeltaToAxis(target.sub(touch.emittedPosition), axis);
                            if (movementsOppose(delta, touch.lastMovement)) {
                                target = touch.emittedPosition;
                                delta = new Point(0, 0);
                            }
                        }
                        touch.emittedPosition = target;
                        recognized.push(Scroll(scrollEvent(touch.startPosition, delta, Moved)));
                        state = Panning(touch, axis);

                    case LongPressing(touch) if (touch.id == event.id):
                        touch.lastPosition = event.position;
                        recognized.push(LongPress(new LongPressEvent(Moved, touch.startPosition, event.position)));
                        state = LongPressing(touch);

                    case TouchDragging(touch) if (touch.id == event.id):
                        touch.lastPosition = event.position;
                        recognized.push(TouchDrag(new TouchDragEvent(Moved, touch.startPosition, event.position)));
                        state = TouchDragging(touch);

                    case other:
                        state = other;
                }

            case Ended:
                final current = state;
                state = Idle;
                switch current {
                    case Pending(touch, _, _, _) if (touch.id == event.id):
                        final tap = lastTap;
                        final tapCount = if (tap != null
                            && now - tap.time <= tuning.multiTapInterval
                            && event.position.sub(tap.position).magnitude() <= tuning.multiTapSlop) {
                            tap.count + 1;
                        }
                        else {
                            1;
                        }
                        lastTap = new CompletedTap(event.position, now, tapCount);
                        recognized.push(Tap(
                            new MouseDownEvent(Left, event.position, Modifiers.none(), tapCount, false),
                            new MouseUpEvent(Left, event.position, Modifiers.none(), tapCount)
                        ));

                    case Caught(touch) if (touch.id == event.id):
                        // Never moved: the content it stopped stays where it is.
                        recognized.push(Scroll(scrollEvent(touch.startPosition, new Point(0, 0), Ended)));

                    case Panning(touch, axis) if (touch.id == event.id):
                        // The release deliberately contributes no velocity
                        // sample. But a release long after the last movement
                        // means the finger had already stopped, so nothing
                        // flings.
                        final latest = touch.velocityTracker.latestSampleTime();
                        final fingerStopped = latest == null || now - latest > VELOCITY_ASSUME_STOPPED_GAP;
                        var velocityX = 0.;
                        var velocityY = 0.;
                        if (!fingerStopped) {
                            final velocity = touch.velocityTracker.velocity();
                            velocityX = velocity.x;
                            velocityY = velocity.y;
                        }
                        switch axis {
                            case Vertical: velocityX = 0.;
                            case Horizontal: velocityY = 0.;
                        }
                        final speed = Math.sqrt(velocityX * velocityX + velocityY * velocityY);
                        var releaseDelta = lockDeltaToAxis(event.position.sub(touch.emittedPosition), axis);
                        if (speed >= tuning.minFlingVelocity) {
                            final directionX = velocityX / speed;
                            final directionY = velocityY / speed;
                            final speed = Math.min(speed, MAX_FLING_VELOCITY);
                            final duration = tuning.scrollPhysics.flingDuration(speed);
                            if (duration != 0.) {
                                final totalDistance = tuning.scrollPhysics.flingDistance(speed, duration);
                                // Prediction may have left the content ahead
                                // of the raw release position: fold that
                                // correction into the fling instead of
                                // snapping back.
                                final overshoot = -(releaseDelta.x * directionX + releaseDelta.y * directionY);
                                final emittedDistance = if (overshoot > 0. && overshoot < totalDistance) {
                                    releaseDelta = releaseDelta.add(new Point(directionX * overshoot, directionY * overshoot));
                                    overshoot;
                                }
                                else {
                                    0.;
                                }
                                momentum = new Momentum(touch.startPosition, directionX, directionY, speed, now, duration, emittedDistance);
                            }
                        }
                        recognized.push(Scroll(scrollEvent(touch.startPosition, releaseDelta, Ended)));

                    case LongPressing(touch) if (touch.id == event.id):
                        recognized.push(LongPress(new LongPressEvent(Ended, touch.startPosition, event.position)));

                    case TouchDragging(touch) if (touch.id == event.id):
                        recognized.push(TouchDrag(new TouchDragEvent(Ended, touch.startPosition, event.position)));

                    case other:
                        state = other;
                }

            case Cancelled:
                final current = state;
                state = Idle;
                switch current {
                    case Pending(touch, _, _, _) if (touch.id == event.id):
                    case Panning(touch, _) if (touch.id == event.id):
                        recognized.push(Scroll(scrollEvent(touch.startPosition, new Point(0, 0), Cancelled)));
                    case Caught(touch) if (touch.id == event.id):
                        recognized.push(Scroll(scrollEvent(touch.startPosition, new Point(0, 0), Cancelled)));
                    case LongPressing(touch) if (touch.id == event.id):
                        recognized.push(LongPress(new LongPressEvent(Cancelled, touch.startPosition, event.position)));
                    case TouchDragging(touch) if (touch.id == event.id):
                        recognized.push(TouchDrag(new TouchDragEvent(Cancelled, touch.startPosition, event.position)));
                    case other:
                        state = other;
                }
        }
        return recognized;
    }

    /**
     * The pending touch that has not been offered as a long press yet, and
     * the time left until its long press is due (seconds, at least 0), or
     * null.
     */
    public function pendingLongPress(now:Float):Null<{id:TouchId, remaining:Float}> {
        return switch state {
            case Pending(touch, deadline, false, _):
                {id: touch.id, remaining: Math.max(0., deadline - now)};
            case _:
                null;
        }
    }

    public function offerLongPress(id:TouchId):Null<RecognizedTouchGesture> {
        return switch state {
            case Pending(touch, deadline, longPressOffered, touchDragOffered):
                if (touch.id != id || longPressOffered) {
                    null;
                }
                else {
                    state = Pending(touch, deadline, true, touchDragOffered);
                    LongPress(new LongPressEvent(Started, touch.startPosition, touch.lastPosition));
                }
            case _:
                null;
        }
    }

    public function resolveLongPress(claimed:Bool):Void {
        if (!claimed)
            return;
        switch state {
            case Pending(touch, _, true, _):
                state = LongPressing(touch);
            case _:
        }
    }

    public function offerTouchDrag(id:TouchId):Null<RecognizedTouchGesture> {
        return switch state {
            case Pending(touch, deadline, longPressOffered, touchDragOffered):
                if (touch.id != id || touchDragOffered) {
                    null;
                }
                else {
                    state = Pending(touch, deadline, longPressOffered, true);
                    TouchDrag(new TouchDragEvent(Started, touch.startPosition, touch.lastPosition));
                }
            case _:
                null;
        }
    }

    public function resolveTouchDrag(claimed:Bool):Void {
        if (!claimed)
            return;
        switch state {
            case Pending(touch, _, _, true):
                state = TouchDragging(touch);
            case _:
        }
    }

    public inline function hasMomentum():Bool {
        return momentum != null;
    }

    /**
     * Advances post-fling momentum to time `now` (seconds), returning the
     * scroll step to dispatch, or null when no momentum is in progress. The
     * final step carries `TouchPhase.Ended` to close the synthetic scroll
     * stream.
     */
    public function tickMomentum(now:Float):Null<RecognizedTouchGesture> {
        final momentum = this.momentum;
        if (momentum == null)
            return null;
        final elapsed = Math.max(0., now - momentum.startedAt);
        final distance = tuning.scrollPhysics.flingDistance(momentum.speed, elapsed);
        // Prediction overshoot can start momentum ahead of its curve. Hold
        // that position until the curve catches up instead of stepping back.
        final step = Math.max(distance - momentum.emittedDistance, 0.);
        momentum.emittedDistance = Math.max(momentum.emittedDistance, distance);
        final delta = new Point(momentum.directionX * step, momentum.directionY * step);
        final position = momentum.position;
        if (elapsed >= momentum.duration) {
            this.momentum = null;
            return Scroll(scrollEvent(position, delta, Ended));
        }
        return Scroll(scrollEvent(position, delta, Moved));
    }

}

/**
 * Estimates the velocity a touch had at its newest sample.
 */
class VelocityTracker {

    final times:Array<Float> = [];

    final positions:Array<Point> = [];

    public function new() {}

    public function push(time:Float, position:Point):Void {
        times.push(time);
        positions.push(position);
        while (times.length > TouchGestureRecognizer.VELOCITY_MAX_SAMPLES) {
            times.shift();
            positions.shift();
        }
    }

    public function latestSampleTime():Null<Float> {
        return times.length > 0 ? times[times.length - 1] : null;
    }

    /**
     * The velocity at the newest sample, in pixels per second.
     *
     * Fits a second-degree polynomial by least squares over the trailing
     * velocity window and takes its derivative at the newest sample, like
     * Flutter's `VelocityTracker` and Android's `lsq2` strategy.
     */
    public function velocity():Point {
        if (times.length == 0)
            return new Point(0, 0);
        final newestTime = times[times.length - 1];
        final timesSeconds:Array<Float> = [];
        final horizontal:Array<Float> = [];
        final vertical:Array<Float> = [];
        var previousTime = newestTime;
        var i = times.length - 1;
        while (i >= 0) {
            final time = times[i];
            final age = newestTime - time;
            if (age > TouchGestureRecognizer.VELOCITY_WINDOW || previousTime - time > TouchGestureRecognizer.VELOCITY_ASSUME_STOPPED_GAP) {
                break;
            }
            previousTime = time;
            timesSeconds.push(-age);
            horizontal.push(positions[i].x);
            vertical.push(positions[i].y);
            i--;
        }

        inline function endpointEstimate(values:Array<Float>):Float {
            final elapsed = timesSeconds.length > 0 ? -timesSeconds[timesSeconds.length - 1] : 0.;
            return if (elapsed <= 2.220446049250313e-16) {
                0.;
            }
            else {
                ((values.length > 0 ? values[0] : 0.) - (values.length > 0 ? values[values.length - 1] : 0.)) / elapsed;
            }
        }
        if (timesSeconds.length < 3) {
            return new Point(endpointEstimate(horizontal), endpointEstimate(vertical));
        }
        final vx = quadraticVelocityAtNewest(timesSeconds, horizontal);
        final vy = quadraticVelocityAtNewest(timesSeconds, vertical);
        return new Point(vx != null ? vx : endpointEstimate(horizontal), vy != null ? vy : endpointEstimate(vertical));
    }

    /**
     * Least-squares fit of `value = a0 + a1*t + a2*t^2` returning `a1`, or
     * null when the samples are too degenerate to fit.
     */
    static function quadraticVelocityAtNewest(times:Array<Float>, values:Array<Float>):Null<Float> {
        final count:Float = times.length;
        var sumT1 = 0., sumT2 = 0., sumT3 = 0., sumT4 = 0.;
        var sumV = 0., sumVt = 0., sumVt2 = 0.;
        for (i in 0...times.length) {
            final time = times[i];
            final value = values[i];
            final timeSquared = time * time;
            sumT1 += time;
            sumT2 += timeSquared;
            sumT3 += timeSquared * time;
            sumT4 += timeSquared * timeSquared;
            sumV += value;
            sumVt += value * time;
            sumVt2 += value * timeSquared;
        }
        // Cramer's rule on the 3x3 normal equations, solved for the linear
        // coefficient only.
        final determinant = count * (sumT2 * sumT4 - sumT3 * sumT3)
            - sumT1 * (sumT1 * sumT4 - sumT3 * sumT2)
            + sumT2 * (sumT1 * sumT3 - sumT2 * sumT2);
        if (Math.abs(determinant) < 1e-12) {
            return null;
        }
        final linearDeterminant = count * (sumVt * sumT4 - sumT3 * sumVt2)
            - sumV * (sumT1 * sumT4 - sumT3 * sumT2)
            + sumT2 * (sumT1 * sumVt2 - sumVt * sumT2);
        return linearDeterminant / determinant;
    }

}
