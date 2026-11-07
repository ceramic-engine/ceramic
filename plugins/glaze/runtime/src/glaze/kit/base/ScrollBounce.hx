// Ported from gpui-kit 0.8.1: crates/base/src/scroll_bounce.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.ContentMask;
import gpui.DispatchPhase;
import gpui.Element;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.GlobalElementId;
import gpui.Hitbox;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.OngoingScroll;
import gpui.Point;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.TouchPhase;
import gpui.Window;
import gpui.base.Scrollbar.ScrollbarHandle;
import gpui.base.motion.MotionTime;

/**
 * Motion tokens for `ScrollBounce`: how far a drag stretches the viewport
 * past an edge, and how quickly a released edge returns.
 *
 * Base plays the stretch and the return; the feel belongs to the caller.
 * The default is tuned to feel like a `UIScrollView` bounce on iOS and
 * Android, and like an `NSScrollView` bounce elsewhere. Durations are in
 * seconds.
 */
class ScrollBounceMotion {

    var _tracking:Float;

    var _response:Float;

    var _maxStretch:Null<Float>;

    /**
     * Tuned to feel like a `UIScrollView` bounce on touch platforms; these
     * are not UIKit constants. Elsewhere the input is a trackpad, whose
     * accelerated deltas run far past a finger's travel, so the default is
     * fitted to an `NSScrollView` measured on macOS: the stretch follows
     * about 0.075 of the travel, the return decays at 12.5 per second, and
     * the edge stops 36 px out.
     */
    public function new() {
        #if (ios || android)
        _tracking = 0.55;
        _response = 0.524;
        _maxStretch = null;
        #else
        _tracking = 0.075;
        // 2π / 12.5
        _response = 0.502655;
        _maxStretch = 36.;
        #end
    }

    function copy():ScrollBounceMotion {
        final result = new ScrollBounceMotion();
        result._tracking = _tracking;
        result._response = _response;
        result._maxStretch = _maxStretch;
        return result;
    }

    /**
     * Fraction of finger travel the stretched edge follows at first.
     *
     * Throws when `tracking` is not finite or not positive.
     */
    public function withTracking(tracking:Float):ScrollBounceMotion {
        if (!(Math.isFinite(tracking) && tracking > 0.)) {
            throw 'scroll bounce tracking must be finite and positive';
        }
        final result = copy();
        result._tracking = tracking;
        return result;
    }

    /**
     * Time scale of the return once the finger lifts, in seconds: the period
     * one full oscillation would take without damping. The return is
     * critically damped, so it never crosses the edge. A zero response snaps
     * the edge back on the spot.
     */
    public function withResponse(response:Float):ScrollBounceMotion {
        final result = copy();
        result._response = response;
        return result;
    }

    /**
     * The farthest the edge goes past its end, in pixels, whether stretched
     * or thrown by a fling. The stretch eases into it rather than stopping
     * at it.
     *
     * Throws when `maxStretch` is not finite or not positive.
     */
    public function withMaxStretch(maxStretch:Float):ScrollBounceMotion {
        if (!(Math.isFinite(maxStretch) && maxStretch > 0.)) {
            throw 'scroll bounce max stretch must be finite and positive';
        }
        final result = copy();
        result._maxStretch = maxStretch;
        return result;
    }

    /** Fraction of finger travel the stretched edge follows at first. */
    public inline function tracking():Float {
        return _tracking;
    }

    /** Time scale of the return once the finger lifts. */
    public inline function response():Float {
        return _response;
    }

    /**
     * The farthest the edge goes past its end, or `null` when only the
     * viewport height bounds it.
     */
    public inline function maxStretch():Null<Float> {
        return _maxStretch;
    }

    /** Undamped angular frequency of the return, or `null` when it snaps. */
    @:allow(gpui.base)
    function omega():Null<Float> {
        final seconds = MotionTime.asSecsF32(MotionTime.nanos(_response));
        return seconds > 0. ? f32(f32(Math.PI * 2) / seconds) : null;
    }

    public function equals(other:ScrollBounceMotion):Bool {
        return _tracking == other._tracking && _response == other._response && _maxStretch == other._maxStretch;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

}

/**
 * The stretch past an edge and its return, shared with the input's own
 * scrolling. `f32` math like the original.
 */
@:allow(gpui.base)
class Physics {

    var position:Float = 0.;

    var velocity:Float = 0.;

    var dragging:Bool = false;

    var suppressMomentum:Bool = false;

    var extent:Float = 0.;

    var motion:ScrollBounceMotion = new ScrollBounceMotion();

    public function new() {}

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    static inline function signum(value:Float):Float {
        return gpui.util.MathUtil.signum(value);
    }

    public function setMotion(motion:ScrollBounceMotion):Void {
        this.motion = motion;
    }

    public function reset():Void {
        position = 0.;
        velocity = 0.;
        dragging = false;
        suppressMomentum = false;
        extent = 0.;
    }

    public inline function isDragging():Bool {
        return dragging;
    }

    /** Whether a released edge is still on its way. */
    public function isMoving():Bool {
        return !dragging && (position != 0. || velocity != 0.);
    }

    public function offset():Float {
        if (dragging) {
            final d = Math.max(extent, 1.);
            final tracking = motion.tracking();
            final stretch = f32(f32(position * tracking) / f32(1. + f32(f32(tracking * Math.abs(position)) / d)));
            final max = motion.maxStretch();
            // Follows the stretch closely at first, then eases into the limit.
            if (max != null) {
                return f32(max * f32(tanh(f32(stretch / max))));
            }
            return stretch;
        }
        return position;
    }

    static function tanh(x:Float):Float {
        if (x > 20) return 1.;
        if (x < -20) return -1.;
        final e = Math.exp(2 * x);
        return (e - 1) / (e + 1);
    }

    static function atanh(x:Float):Float {
        return 0.5 * Math.log((1 + x) / (1 - x));
    }

    public function begin(extent:Float):Void {
        final offset = this.offset();
        // A displaced edge keeps the extent it was stretched under. The
        // rubber-band curve saturates at the extent, so re-reading a viewport
        // that shrank mid-return (rotation, keyboard) could not place the
        // finger where the edge is: it would snap, then need a long pull back.
        if (offset == 0. || this.extent <= 0.) {
            this.extent = Math.max(extent, 1.);
        }
        // Invert the curves so grabbing a returning edge is continuous.
        final max = motion.maxStretch();
        final stretch = if (max != null) {
            var ratio = f32(offset / max);
            ratio = ratio < -0.999 ? -0.999 : (ratio > 0.999 ? 0.999 : ratio);
            f32(max * f32(atanh(ratio)));
        }
        else {
            offset;
        }
        final tracking = motion.tracking();
        position = f32(stretch / f32(tracking * Math.max(f32(1. - f32(Math.abs(stretch) / this.extent)), 0.01)));
        velocity = 0.;
        dragging = true;
        suppressMomentum = false;
    }

    /** Apply finger displacement. Return the part that crosses back into the list. */
    public function pull(delta:Float):Float {
        final previous = position;
        final next = f32(previous + delta);
        if (previous != 0. && signum(previous) != signum(next)) {
            position = 0.;
            return next;
        }
        position = next;
        return 0.;
    }

    public function release():Void {
        position = offset();
        dragging = false;
        if (position != 0.) {
            suppressMomentum = true;
        }
    }

    /**
     * Let go of the edge the way AppKit does: from wherever it is, it
     * returns at full speed, and it carries `velocity` outward on the way.
     * Its path is `(x + velocity * t) * e^(-ωt)`, so an edge at rest is
     * thrown out and back, and an edge let go while still being pushed
     * returns a little later. It never crosses the boundary: velocity
     * pointing back inward is dropped.
     */
    public function letGo(velocity:Float):Void {
        position = offset();
        dragging = false;
        final omega = motion.omega();
        if (omega == null) {
            position = 0.;
            this.velocity = 0.;
            return;
        }
        var outward = position * velocity >= 0. ? velocity : 0.;
        final max = motion.maxStretch();
        if (max != null) {
            outward = f32(signum(outward) * limitThrow(Math.abs(position), Math.abs(outward), omega, max));
        }
        this.velocity = f32(outward - f32(omega * position));
    }

    /**
     * The largest outward speed, at most `speed`, that lets an edge at
     * `position` go no farther out than `max`.
     *
     * The edge then follows `(position + speed * t) * e^(-ωt)`, which peaks at
     * `speed / ω * e^(ω * position / speed - 1)` when the speed is enough to
     * carry it outward at all.
     */
    static function limitThrow(position:Float, speed:Float, omega:Float, max:Float):Float {
        inline function peak(speed:Float):Float {
            return if (speed <= f32(omega * position)) {
                position;
            }
            else {
                f32(f32(speed / omega) * f32(Math.exp(f32(f32(f32(omega * position) / speed) - 1.))));
            }
        }
        if (peak(speed) <= max) {
            return speed;
        }
        var low = 0.;
        var high = speed;
        for (_ in 0...24) {
            final mid = f32(f32(low + high) / 2.);
            if (peak(mid) <= max) {
                low = mid;
            }
            else {
                high = mid;
            }
        }
        return low;
    }

    /** Exact critically damped spring integration, independent of refresh rate. */
    public function step(seconds:Float):Bool {
        if (dragging || (position == 0. && velocity == 0.)) {
            return false;
        }
        final omega = motion.omega();
        if (omega == null) {
            position = 0.;
            velocity = 0.;
            return false;
        }
        final decay = f32(Math.exp(f32(-omega * seconds)));
        final c = f32(velocity + f32(omega * position));
        final nextPosition = f32(f32(position + f32(c * seconds)) * decay);
        velocity = f32(f32(velocity - f32(f32(omega * c) * seconds)) * decay);
        position = nextPosition;
        if (Math.abs(position) < 0.1 && Math.abs(velocity) < 1.) {
            position = 0.;
            velocity = 0.;
            return false;
        }
        return true;
    }

}

/**
 * The state of a `ScrollBounce` kept across frames (Rust `State`).
 */
@:allow(gpui.base)
class ScrollBounceState {

    var physics:Physics = new Physics();

    var overscroll:Overscroll = new Overscroll();

    /** In nanoseconds, or `null`. */
    var sampledAt:Null<Float> = null;

    var ongoingScroll:OngoingScroll = new OngoingScroll();

    var shortDragDistance:Null<Float> = null;

    /** In nanoseconds, or `null`. */
    var lastWheelAt:Null<Float> = null;

    /**
     * Sign of the stream being suppressed, when it is known to be momentum
     * that cannot reverse. `null` suppresses both directions.
     */
    var suppressedDirection:Null<Float> = null;

    public function new() {}

    /** `*state = State::default()`. */
    function resetAll():Void {
        physics = new Physics();
        overscroll = new Overscroll();
        sampledAt = null;
        ongoingScroll = new OngoingScroll();
        shortDragDistance = null;
        lastWheelAt = null;
        suppressedDirection = null;
    }

    /**
     * Release the edge. A stretch made outside a gesture is momentum (or a
     * phaseless wheel) hitting the edge; that stream only pushes outward,
     * so an inward packet is a new scroll and ends the suppression. After a
     * gesture's own release the suppressed momentum may point either way.
     */
    function release(fromRest:Bool):Void {
        physics.release();
        suppressedDirection = fromRest && physics.suppressMomentum ? gpui.util.MathUtil.signum(physics.offset()) : null;
    }

}

/**
 * Which scroll area under the pointer takes the current wheel event.
 *
 * Capture runs from the outside in, so every area that could scroll writes
 * itself here before its child paints, and the innermost one is the last
 * to write. Each then acts, from the inside out, only if it is still the
 * one written. Holds a hitbox id, or -1.
 */
class ScrollOwner {

    public var hitbox:Int = -1;

    public function new() {}

}

/**
 * Adds vertical touch overscroll to an existing scroll viewport.
 *
 * The child owns layout, content, and ordinary scrolling; `handle` must be the
 * child's scroll handle. Only unused vertical deltas stretch the viewport.
 * The stable `id` owns gesture and spring state. Change it when replacing the
 * document. Put fixed chrome (scrollbars, toolbars) outside this wrapper.
 *
 * Enabled by default where the platform's own scroll views bounce: iOS,
 * Android and macOS. Reduced motion disables displacement. Keyboard and
 * focus remain owned by the child. No colors, padding, or dimensions are
 * imposed.
 *
 * Nested scroll areas follow the platform: the innermost one under the
 * pointer takes the whole gesture, at its ends too, and bounces there
 * rather than handing the rest to the area around it. A disabled
 * `ScrollBounce` still scrolls its child and keeps the gesture from the
 * areas around it; it only stops at the ends instead of stretching.
 *
 * Differences with gpui-kit: every time is read from
 * `cx.backgroundExecutor().now()` (Rust reads the wall clock for the
 * displacement of the `scrollWheel(false)` mode).
 */
class ScrollBounce extends Element {

    /**
     * After a catch, a drag shorter than this (in px) stops the old fling
     * rather than turning a few fast pixels into a new one. GPUI starts a
     * normal touch pan only after its 8 px touch slop, but a touch catching
     * a fling starts at zero displacement.
     */
    static inline final CATCH_DRAG_SLOP:Float = 8.;

    /**
     * Momentum arrives once per frame until it stops, so a longer silence
     * means the suppressed stream has ended (250 ms). Smooth-scrolling mouse
     * drivers on macOS send precise deltas with no phase: they never send
     * the `Started` that otherwise ends suppression, and would stay locked
     * after one bounce.
     */
    public static inline final MOMENTUM_GAP:Float = 0.25;

    final _id:ElementId;

    final handle:ScrollbarHandle;

    final child:AnyElement;

    var _enabled:Bool;

    var _scrollWheel:Bool = true;

    var _motion:ScrollBounceMotion = new ScrollBounceMotion();

    var _onScroll:Null<(Window, App) -> Void> = null;

    /** Prepaint state. */
    var state:Null<ScrollBounceState> = null;

    var hitbox:Null<Hitbox> = null;

    public function new(id:ElementIdArg, handle:ScrollbarHandle, child:IntoElement) {
        _id = id;
        this.handle = handle;
        this.child = child.intoAnyElement();
        _enabled = enabledByDefault();
    }

    /**
     * Whether scroll areas bounce on this platform unless told otherwise:
     * on iOS, Android and macOS, whose own scroll views do.
     */
    public static inline function enabledByDefault():Bool {
        #if (ios || android || mac)
        return true;
        #else
        return false;
        #end
    }

    /** Turn the bounce on or off. Defaults to `enabledByDefault()`. */
    public function enabled(enabled:Bool):ScrollBounce {
        _enabled = enabled;
        return this;
    }

    /**
     * Own vertical scrolling using the shared input overscroll engine.
     * Precise pixel input can bounce; ordinary line-wheel input only scrolls
     * and cancels any existing displacement. Keep fixed chrome outside it.
     *
     * On by default. Turned off, the child scrolls itself and only its
     * unused deltas stretch the edge; that needs input that emits `Ended`
     * at finger release, before momentum, as touch does.
     */
    public function scrollWheel(enabled:Bool):ScrollBounce {
        _scrollWheel = enabled;
        return this;
    }

    /** Set how far a drag stretches past an edge and how the edge returns. */
    public function motion(motion:ScrollBounceMotion):ScrollBounce {
        _motion = motion;
        return this;
    }

    /**
     * Observe a logical scroll performed when a reverse drag leaves the stretched
     * region. Runs after the handle update. Ordinary child scrolling continues
     * to use the child's own notifications.
     */
    public function onScroll(handler:(Window, App) -> Void):ScrollBounce {
        _onScroll = handler;
        return this;
    }

    override public function elementId():Null<ElementId> {
        return _id;
    }

    /**
     * Take the current wheel event from the scroll areas around `hitbox`.
     * Call it in the capture phase, from a listener registered before the
     * children paint, whenever the area would scroll for the event.
     */
    @:allow(gpui.base)
    static function claimScroll(hitbox:Int, cx:App):Void {
        cx.defaultGlobal(ScrollOwner).hitbox = hitbox;
    }

    static function ownsScroll(hitbox:Int, cx:App):Bool {
        final owner = cx.tryGlobal(ScrollOwner);
        return owner != null && owner.hitbox == hitbox;
    }

    /**
     * `ScrollbarHandle` has no `maxOffset`; recover it from the definition
     * `contentSize = viewport + maxOffset`. Both dispatch phases clamp against
     * this bound and must agree on it.
     */
    static function maxScrollExtent(handle:ScrollbarHandle):Float {
        return Math.max(handle.contentSize().height - handle.viewportBounds().size.height, 0.);
    }

    static inline function clampOffset(value:Float, max:Float):Float {
        // `Pixels::clamp(-max, 0)`
        return value < -max ? -max : (value > 0. ? 0. : value);
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final state = window.withElementState(id, ScrollBounceState, (box, _) -> {
            if (box.value == null) box.value = new ScrollBounceState();
            return box.value;
        });
        this.state = state;
        if (!_enabled || cx.reduceMotion()) {
            state.resetAll();
        }
        final offset = if (_scrollWheel) {
            state.overscroll.setMotion(_motion);
            if (maxScrollExtent(handle) <= 0.) {
                state.overscroll.reset();
            }
            if (state.overscroll.step(cx.backgroundExecutor().now())) {
                window.requestAnimationFrame();
            }
            state.overscroll.offset();
        }
        else {
            state.physics.motion = _motion;
            final now = MotionTime.nanos(cx.backgroundExecutor().now());
            final last = state.sampledAt;
            state.sampledAt = now;
            final elapsed = last == null ? 0. : MotionTime.asSecsF32(now > last ? now - last : 0.);
            if (state.physics.step(elapsed)) {
                window.requestAnimationFrame();
            }
            state.physics.offset();
        }
        hitbox = window.insertHitbox(bounds, Normal);
        window.withContentMask(new ContentMask(bounds), window -> {
            window.withElementOffset(new Point(0., offset), window -> {
                child.prepaint(window, cx);
                return null;
            });
            return null;
        });
        // The child's fresh metrics can remove overflow during a drag.
        // Reset against those metrics as well, and repaint any displaced frame.
        if (_scrollWheel && maxScrollExtent(handle) <= 0.) {
            final displaced = state.overscroll.offset() != 0.;
            state.overscroll.reset();
            if (displaced) {
                window.requestAnimationFrame();
            }
        }
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final handle = this.handle;
        final state = this.state;
        final hitboxId = hitbox.id;
        if (_scrollWheel) {
            window.onMouseEvent(Scroll, (_, phase, window, cx) -> {
                if (phase == Capture && window.shouldHitboxIdHandleScroll(hitboxId) && maxScrollExtent(handle) > 0.) {
                    claimScroll(hitboxId, cx);
                }
            });
        }
        if (_enabled && !_scrollWheel && !cx.reduceMotion()) {
            final view = window.currentView();
            final onScroll = _onScroll;
            var before = 0.;
            var allowEndBounce = false;
            window.onMouseEvent(Scroll, (event, phase, window, cx) -> {
                final event:ScrollEvent = cast event;
                var delta:Point = switch event.delta {
                    case Pixels(delta): delta;
                    case Lines(_):
                        if (phase == Capture && window.shouldHitboxIdHandleScroll(hitboxId)) {
                            final displaced = state.physics.offset() != 0.;
                            state.resetAll();
                            if (displaced) {
                                cx.notify(view);
                            }
                        }
                        return;
                };
                if (!window.shouldHitboxIdHandleScroll(hitboxId)) {
                    return;
                }
                // Lock the gesture to the axis it started on, so a diagonal
                // swipe cannot wobble out of the stretch from one packet to
                // the next. Both dispatch phases see the same packet, and the
                // lock gives both the same answer.
                delta = lockAxis(state.ongoingScroll, delta, event.touchPhase, cx);
                if (Math.abs(delta.x) > Math.abs(delta.y)) {
                    return;
                }
                final ended = event.touchPhase == Ended || event.touchPhase == Cancelled;
                var scrolled = false;
                var changed = false;
                if (phase == Capture) {
                    before = handle.offset().y;
                    if (event.touchPhase == Started) {
                        state.shortDragDistance = delta.y == 0. ? 0. : null;
                        state.physics.begin(bounds.size.height);
                    }
                    else if (state.shortDragDistance != null) {
                        state.shortDragDistance = f32(state.shortDragDistance + Math.abs(delta.y));
                        if (state.shortDragDistance > CATCH_DRAG_SLOP) {
                            state.shortDragDistance = null;
                        }
                    }
                    final suppressShortDragMomentum = if (ended) {
                        final had = state.shortDragDistance != null;
                        state.shortDragDistance = null;
                        had && event.touchPhase == Ended;
                    }
                    else {
                        false;
                    }
                    // The current Ended packet may still cross an edge; only
                    // momentum packets after it should be suppressed.
                    allowEndBounce = suppressShortDragMomentum;
                    final now = MotionTime.nanos(cx.backgroundExecutor().now());
                    final lastWheel = state.lastWheelAt;
                    state.lastWheelAt = now;
                    final paused = lastWheel != null && (now > lastWheel ? now - lastWheel : 0.) >= MotionTime.nanos(MOMENTUM_GAP);
                    final reversed = state.suppressedDirection != null
                        && delta.y != 0.
                        && gpui.util.MathUtil.signum(delta.y) != state.suppressedDirection;
                    if (paused || reversed) {
                        state.physics.suppressMomentum = false;
                    }
                    if (state.physics.suppressMomentum) {
                        cx.stopPropagation();
                        return;
                    }
                    if (state.physics.offset() != 0.) {
                        // Outside a gesture (a phaseless wheel once suppression
                        // lifts) a packet grabs the returning edge and lets it
                        // go again, as it would at rest.
                        final fromRest = !state.physics.dragging;
                        if (fromRest) {
                            state.physics.begin(bounds.size.height);
                        }
                        final remainder = state.physics.pull(delta.y);
                        if (remainder != 0.) {
                            final max = maxScrollExtent(handle);
                            final offset = handle.offset();
                            handle.setOffset(new Point(offset.x, clampOffset(f32(before + remainder), max)));
                            scrolled = true;
                        }
                        if (ended || fromRest) {
                            state.release(fromRest);
                        }
                        changed = true;
                        cx.stopPropagation();
                    }
                    else if (ended) {
                        state.physics.release();
                    }
                    if (suppressShortDragMomentum) {
                        state.physics.suppressMomentum = true;
                        state.suppressedDirection = null;
                    }
                }
                else {
                    // Div applies deltas immediately but clamps during its next
                    // prepaint. Clamp here so that boundary deltas are not
                    // mistaken for consumed scrolling (ListState clamps eagerly).
                    var offset = handle.offset();
                    final max = maxScrollExtent(handle);
                    final clamped = clampOffset(offset.y, max);
                    if (clamped != offset.y) {
                        offset = new Point(offset.x, clamped);
                        handle.setOffset(offset);
                    }
                    final after = offset.y;
                    final requested = delta.y;
                    // A List can coalesce several packets against one painted
                    // scroll position. Their offset difference alone does not
                    // prove overscroll, especially after direction changes or
                    // a zero-delta Ended packet from a trackpad.
                    final atOutwardEdge = (requested > 0. && offset.y == 0.) || (requested < 0. && offset.y == -max);
                    var residual = f32(requested - f32(after - before));
                    final low = Math.min(requested, 0.);
                    final high = Math.max(requested, 0.);
                    residual = residual < low ? low : (residual > high ? high : residual);
                    if (atOutwardEdge && Math.abs(residual) > 0.01 && (!state.physics.suppressMomentum || allowEndBounce)) {
                        final dragging = state.physics.dragging;
                        if (!dragging) {
                            state.physics.begin(bounds.size.height);
                        }
                        state.physics.pull(residual);
                        if (!dragging || ended) {
                            state.release(!dragging);
                        }
                        changed = true;
                    }
                }
                if (changed) {
                    state.sampledAt = MotionTime.nanos(cx.backgroundExecutor().now());
                }
                if (changed) {
                    cx.notify(view);
                }
                if (scrolled && onScroll != null) {
                    onScroll(window, cx);
                }
            });
        }
        window.withContentMask(new ContentMask(bounds), window -> {
            child.paint(window, cx);
            return null;
        });
        // After the children, so that the areas inside act first.
        if (_scrollWheel) {
            final bounces = _enabled && !cx.reduceMotion();
            final view = window.currentView();
            final onScroll = _onScroll;
            window.onMouseEvent(Scroll, (event, phase, window, cx) -> {
                final event:ScrollEvent = cast event;
                if (phase != Capture || !window.shouldHitboxIdHandleScroll(hitboxId) || !ownsScroll(hitboxId, cx)) {
                    return;
                }
                var delta = event.delta.pixelDelta(window.lineHeight());
                delta = lockAxis(state.ongoingScroll, delta, event.touchPhase, cx);
                final max = maxScrollExtent(handle);
                if (max <= 0.) {
                    state.overscroll.reset();
                    return;
                }
                if (Math.abs(delta.x) > Math.abs(delta.y)) {
                    return;
                }
                final before = handle.offset();
                final isLines = switch event.delta {
                    case Lines(_): true;
                    case Pixels(_): false;
                };
                final changed = if (!bounces || isLines) {
                    final displaced = state.overscroll.offset() != 0.;
                    state.overscroll.reset();
                    handle.setOffset(new Point(before.x, clampOffset(f32(before.y + delta.y), max)));
                    displaced;
                }
                else {
                    state.overscroll.packet(delta.y, event.touchPhase, bounds.size.height, cx.backgroundExecutor().now(), dy -> {
                        final before = handle.offset();
                        final requested = f32(before.y + dy);
                        final next = clampOffset(requested, max);
                        handle.setOffset(new Point(before.x, next));
                        // Only clamping leaves unused input; subtraction
                        // can leave a rounding residue inside the list.
                        return next == requested ? dy : f32(next - before.y);
                    });
                };
                final scrolled = !handle.offset().equals(before);
                cx.stopPropagation();
                if (changed || scrolled) {
                    cx.notify(view);
                }
                if (scrolled && onScroll != null) {
                    onScroll(window, cx);
                }
            });
        }
    }

    /**
     * `OngoingScrollExt::lock_axis`. The original makes it a no-op on wasm32,
     * where `Instant` panics; the port reads the executor clock on every
     * target, so the lock applies everywhere.
     */
    @:allow(gpui.base)
    static function lockAxis(ongoingScroll:OngoingScroll, delta:Point, touchPhase:TouchPhase, cx:App):Point {
        return ongoingScroll.filter(delta, touchPhase, cx.backgroundExecutor().now());
    }

}
