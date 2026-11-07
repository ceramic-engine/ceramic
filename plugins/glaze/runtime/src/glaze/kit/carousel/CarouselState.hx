// Ported from gpui-kit 0.8.1: crates/component/src/carousel/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.carousel;

import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Context;
import gpui.FocusHandle;
import gpui.Model;
import gpui.Point;
import gpui.ScrollHandle;
import gpui.TouchPhase;
import gpui.util.MathUtil;

/**
 * An event emitted when user interaction selects another carousel item.
 */
enum CarouselEvent {
    /** The newly selected item index. */
    Change(index:Int);
}

/**
 * Bounds collected by `CarouselContent` after layout.
 *
 * The bounds are kept in the content's unscrolled coordinate space. Keeping
 * this geometry in the behavior state lets pointer, wheel, and keyboard
 * input all resolve to the same snap points without making the content own a
 * second copy of the selection state.
 */
@:allow(gpui.component.carousel)
private class CarouselStateGeometry {

    var viewport:Null<Bounds> = null;

    var frame:Null<Bounds> = null;

    var items:Array<Bounds> = [];

    function new() {}

}

@:allow(gpui.component.carousel)
private class PointerGesture {

    var startPosition:Point;

    @:allow(tests) var startOffset:Point;

    var startIndex:Null<Int>;

    var totalDelta:Float;

    var axisLocked:Bool;

    function new(startPosition:Point, startOffset:Point, startIndex:Null<Int>, totalDelta:Float, axisLocked:Bool) {
        this.startPosition = startPosition;
        this.startOffset = startOffset;
        this.startIndex = startIndex;
        this.totalDelta = totalDelta;
        this.axisLocked = axisLocked;
    }

}

@:allow(gpui.component.carousel)
private class ScrollGesture {

    var startOffset:Point;

    var startIndex:Null<Int>;

    var totalDelta:Float;

    function new(startOffset:Point, startIndex:Null<Int>, totalDelta:Float) {
        this.startOffset = startOffset;
        this.startIndex = startIndex;
        this.totalDelta = totalDelta;
    }

}

/** A `Copy` value in Rust: never mutated, replaced instead. */
@:allow(gpui.component.carousel)
private class LoopLayout {

    final cycleExtent:Float;

    final trackGap:Float;

    final runwayExtent:Float;

    final runwayReady:Bool;

    function new(cycleExtent:Float, trackGap:Float, runwayExtent:Float, runwayReady:Bool) {
        this.cycleExtent = cycleExtent;
        this.trackGap = trackGap;
        this.runwayExtent = runwayExtent;
        this.runwayReady = runwayReady;
    }

}

/**
 * Shared behavior state for every part of a `Carousel`.
 *
 * `CarouselState` intentionally owns behavior only. The content and its
 * items provide presentation and layout, while this state owns selection,
 * orientation, looping, the shared scroll handle, and the input snapshots
 * used to settle gestures. Programmatic setters are silent; user-facing
 * selection methods emit one `CarouselEvent.Change` for a successful
 * selection.
 *
 * Pixels are Rust `f32`: every computed length is rounded to `f32`.
 */
class CarouselState extends Model {

    static inline final POINTER_AXIS_LOCK_THRESHOLD:Float = 2.;

    /**
     * Keep this aligned with GPUI's OngoingScroll timeout. Some platforms only
     * emit `Moved`, so a quiet period is the only signal that a new gesture
     * began (seconds).
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    static inline final SCROLL_EVENT_SEPARATION:Float = 0.028;

    var _itemCount:Int;

    @:allow(tests)
    var _selectedIndex:Null<Int>;

    var _axis:Axis = Horizontal;

    var looping:Bool = false;

    @:allow(tests)
    final scrollHandleValue:ScrollHandle = new ScrollHandle();

    final geometry:CarouselStateGeometry = new CarouselStateGeometry();

    @:allow(tests)
    var pointerGesture:Null<PointerGesture> = null;

    var scrollGesture:Null<ScrollGesture> = null;

    @:allow(tests)
    var ignoreScrollUntilQuiet:Bool = false;

    var scrollSettleEpoch:Int = 0;

    var suppressPointerClick:Bool = false;

    var _motionRevision:Int = 0;

    var loopLayout:Null<LoopLayout> = null;

    var geometryHasRunway:Bool = false;

    var loopLayoutRemovalPending:Bool = false;

    var loopMotionTarget:Null<Point> = null;

    var wheelBurstActive:Bool = false;

    var wheelBurstEpoch:Int = 0;

    var focusHandleValue:Null<FocusHandle> = null;

    var focusRingSuppressed:Bool = false;

    /**
     * Creates state for `itemCount` items, initially selecting the first
     * item when at least one item exists.
     */
    public function new(itemCount:Int) {
        super();
        _itemCount = itemCount;
        _selectedIndex = itemCount > 0 ? 0 : null;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    /** Sets the initially selected item. */
    public function withSelectedIndex(index:Int):CarouselState {
        _selectedIndex = clampIndex(index);
        return this;
    }

    /** Sets the carousel orientation. */
    public function withAxis(axis:Axis):CarouselState {
        _axis = axis;
        return this;
    }

    /** Enables or disables wrapping at the first and last items. */
    public function withLooping(looping:Bool):CarouselState {
        this.looping = looping;
        return this;
    }

    /** Returns the number of logical items. */
    public inline function itemCount():Int {
        return _itemCount;
    }

    /** Returns the selected logical item, or `null` when the carousel is empty. */
    public inline function selectedIndex():Null<Int> {
        return _selectedIndex;
    }

    /** Returns the configured orientation. */
    public inline function axis():Axis {
        return _axis;
    }

    /** Returns whether navigation wraps at the carousel edges. */
    public inline function isLooping():Bool {
        return looping;
    }

    /** Returns whether a previous item can be selected. */
    public function hasPrevious():Bool {
        return _selectedIndex != null && navigationIndex(_selectedIndex, false) != null;
    }

    /** Returns whether a next item can be selected. */
    public function hasNext():Bool {
        return _selectedIndex != null && navigationIndex(_selectedIndex, true) != null;
    }

    /**
     * Silently changes the selected item for controlled/programmatic use.
     *
     * The value is clamped to the available item range. This method does
     * not emit `CarouselEvent.Change`.
     */
    public function setSelectedIndex(index:Int, cx:Context<CarouselState>):Void {
        final rebasedLoopMotion = rebasePendingLoopMotion();
        final nextIndex = clampIndex(index);
        final changed = _selectedIndex != nextIndex || isInteracting() || rebasedLoopMotion;
        final current = _selectedIndex;
        final wrapped = current != null && nextIndex != null && isLoopWrap(current, nextIndex);
        final loopTarget = current != null && wrapped && nextIndex != null ? adjacentLoopTarget(current, nextIndex) : null;
        final seamlessWrap = loopTarget != null;
        loopMotionTarget = if (loopTarget != null) {
            final real = nextIndex != null ? snapTargetFor(nextIndex) : null;
            real != null && primaryOffset(real) != primaryOffset(loopTarget) ? loopTarget : null;
        } else null;
        if (wrapped && !seamlessWrap) {
            _motionRevision = _motionRevision + 1;
        }
        _selectedIndex = nextIndex;
        cancelInteractions(cx);
        if (changed) {
            cx.notify();
        }
    }

    /** Silently changes the number of logical items and clamps the selection. */
    public function setItemCount(itemCount:Int, cx:Context<CarouselState>):Void {
        if (_itemCount == itemCount) {
            return;
        }
        _itemCount = itemCount;
        _selectedIndex = _selectedIndex != null && itemCount > 0 ? Std.int(Math.min(_selectedIndex, saturatingSub(itemCount, 1))) : null;
        if (_selectedIndex == null && itemCount > 0) {
            _selectedIndex = 0;
        }
        if (loopLayout != null) {
            scrollHandleValue.setOffset(new Point(0., 0.));
            _motionRevision = _motionRevision + 1;
        }
        geometry.items = [];
        loopLayout = null;
        loopLayoutRemovalPending = geometryHasRunway;
        loopMotionTarget = null;
        cancelInteractions(cx);
        cx.notify();
    }

    /** Silently changes the carousel orientation. */
    public function setAxis(axis:Axis, cx:Context<CarouselState>):Void {
        if (_axis != axis) {
            _axis = axis;
            scrollHandleValue.setOffset(new Point(0., 0.));
            loopLayout = null;
            loopLayoutRemovalPending = geometryHasRunway;
            loopMotionTarget = null;
            cancelInteractions(cx);
            _motionRevision = _motionRevision + 1;
            cx.notify();
        }
    }

    /** Silently changes whether edge navigation wraps. */
    public function setLooping(looping:Bool, cx:Context<CarouselState>):Void {
        if (this.looping != looping) {
            this.looping = looping;
            updateLoopLayout();
            loopMotionTarget = null;
            cancelInteractions(cx);
            cx.notify();
        }
    }

    /**
     * Selects an item through a user-facing path and emits one change event
     * when the index is valid and differs from the current selection.
     */
    public function selectIndex(index:Int, cx:Context<CarouselState>):Bool {
        if (index >= _itemCount) {
            cancelUserInteraction(cx);
            return false;
        }
        final wrapped = _selectedIndex != null && isLoopWrap(_selectedIndex, index);
        return selectIndexWithWrap(index, wrapped, cx);
    }

    /** Selects the previous item, wrapping when looping is enabled. */
    public function selectPrevious(cx:Context<CarouselState>):Bool {
        final current = _selectedIndex;
        if (current == null) {
            return false;
        }
        final index = navigationIndex(current, false);
        if (index == null) {
            cancelUserInteraction(cx);
            return false;
        }
        final wrapped = isLoopWrap(current, index);
        return selectIndexWithWrap(index, wrapped, cx);
    }

    /** Selects the next item, wrapping when looping is enabled. */
    public function selectNext(cx:Context<CarouselState>):Bool {
        final current = _selectedIndex;
        if (current == null) {
            return false;
        }
        final index = navigationIndex(current, true);
        if (index == null) {
            cancelUserInteraction(cx);
            return false;
        }
        final wrapped = isLoopWrap(current, index);
        return selectIndexWithWrap(index, wrapped, cx);
    }

    /** Selects the first item through the user-facing path. */
    public function selectFirst(cx:Context<CarouselState>):Bool {
        return selectIndex(0, cx);
    }

    /** Selects the last item through the user-facing path. */
    public function selectLast(cx:Context<CarouselState>):Bool {
        if (_itemCount == 0) {
            cancelUserInteraction(cx);
            return false;
        }
        return selectIndex(_itemCount - 1, cx);
    }

    /** Returns the shared scroll handle used by the content viewport. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function scrollHandle():ScrollHandle {
        return scrollHandleValue;
    }

    /**
     * Hides or restores the focus ring. Focus that arrives through the
     * pointer keeps the arrow keys working without drawing the ring.
     */
    @:allow(gpui.component.carousel)
    function suppressFocusRing(suppressed:Bool):Void {
        focusRingSuppressed = suppressed;
    }

    @:allow(gpui.component.carousel)
    function isFocusRingSuppressed():Bool {
        return focusRingSuppressed;
    }

    /** Returns whether pointer or trackpad input is currently active. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function isInteracting():Bool {
        return pointerGesture != null || scrollGesture != null;
    }

    /** Returns whether a trackpad gesture is being tracked. */
    @:allow(gpui.component.carousel)
    function hasScrollGesture():Bool {
        return scrollGesture != null;
    }

    /** Returns whether the active pointer gesture has committed to this axis. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function isPointerDragLocked():Bool {
        return pointerGesture != null && pointerGesture.axisLocked;
    }

    /**
     * Returns whether a cross-axis move cancelled this pointer sequence.
     *
     * The event surface uses this to stop the release during its bubble phase.
     * Capture-phase handlers still run first, so descendant controls clear
     * their pending press and ancestor gesture surfaces can finish.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function shouldSuppressPointerClick():Bool {
        return suppressPointerClick;
    }

    /**
     * Returns a monotonic key for motion that must be rebased immediately.
     *
     * Ordinary adjacent selection and a loop wrap leave this value unchanged.
     * It advances only when the scroll coordinate is silently rebased to an
     * equivalent cycle, letting the content start a fresh spring at the same
     * visual position.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function motionRevision():Int {
        return _motionRevision;
    }

    /**
     * Returns the size of the clipped content frame that controls and the
     * focus ring are positioned around.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function frameSize():Null<gpui.Size> {
        return geometry.frame != null ? geometry.frame.size : null;
    }

    /** Records the viewport and item bounds used for gesture snapping (test helper). */
    @:allow(tests)
    function setGeometry(viewport:Bounds, items:Array<Bounds>):Void {
        final hasRunway = loopLayout != null;
        setGeometryWithRunway(viewport, viewport, items, hasRunway);
    }

    /**
     * Records the scroll track (`viewport`), the clipped content `frame`, and
     * the item bounds after layout.
     */
    @:allow(gpui.component.carousel)
    function setGeometryWithRunway(viewport:Bounds, frame:Bounds, items:Array<Bounds>, hasRunway:Bool):Void {
        geometry.viewport = viewport;
        geometry.frame = frame;
        geometry.items = items;
        geometryHasRunway = hasRunway;
        updateLoopLayout();
    }

    /** Returns the runway reserved on both sides of the real item cycle. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function loopRunway():Null<Float> {
        return loopLayout != null ? loopLayout.cycleExtent : null;
    }

    /** Returns whether content layout is moving into or out of its runway. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function isLoopLayoutTransitioning():Bool {
        return loopLayoutRemovalPending || (loopLayout != null && !loopLayout.runwayReady);
    }

    /** Returns the visual offset applied to one item in the circular track. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function loopItemOffset(index:Int):Point {
        final layout = loopLayout;
        if (layout == null) {
            return new Point(0., 0.);
        }

        if (!layout.runwayReady) {
            return axisPoint(-layout.runwayExtent);
        }

        final viewport = geometry.viewport;
        if (viewport == null) {
            return new Point(0., 0.);
        }
        if (index < 0 || index >= geometry.items.length) {
            return new Point(0., 0.);
        }
        final item = geometry.items[index];
        final viewportCenter = f32(f32(primaryStart(viewport) + f32(viewport.size.along(_axis) / 2.)) - primaryOffset(scrollHandleValue.offset()));
        final itemCenter = f32(primaryStart(item) + f32(item.size.along(_axis) / 2.));
        final cycles = MathUtil.clamp(MathUtil.round(f32(f32(viewportCenter - itemCenter) / layout.cycleExtent)), -1., 1.);
        return axisPoint(f32(layout.cycleExtent * cycles));
    }

    /**
     * Returns the target used by content motion. During a boundary wrap this
     * is the equivalent snap in the adjacent runway cycle.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function motionTargetFor(index:Int):Null<Point> {
        if (loopMotionTarget != null && _selectedIndex == index) {
            return loopMotionTarget;
        }
        return snapTargetFor(index);
    }

    /** Silently returns a settled virtual target to the middle cycle. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function settleLoopMotion(rendered:Point, cx:Context<CarouselState>):Null<Point> {
        final target = loopMotionTarget;
        if (target == null) {
            return null;
        }
        if (Math.abs(f32(primaryOffset(rendered) - primaryOffset(target))) > 0.01) {
            return null;
        }

        final selected = _selectedIndex;
        if (selected == null) {
            return null;
        }
        loopMotionTarget = null;
        final realTarget = snapTargetFor(selected);
        if (realTarget == null) {
            return null;
        }
        scrollHandleValue.setOffset(realTarget);
        _motionRevision = _motionRevision + 1;
        cx.notify();
        return realTarget;
    }

    /** Returns the geometry-derived snap offset for `index`. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function snapTargetFor(index:Int):Null<Point> {
        final viewport = geometry.viewport;
        if (viewport == null) {
            return null;
        }
        if (index < 0 || index >= geometry.items.length) {
            return null;
        }
        return snapOffset(viewport, geometry.items[index]);
    }

    /** Returns the nearest item index for a scroll offset. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function nearestIndex(offset:Point):Null<Int> {
        final viewport = geometry.viewport;
        if (viewport == null) {
            return null;
        }
        // `Iterator::min_by` keeps the first of equal minimums.
        var best:Null<Int> = null;
        var bestDistance = 0.;
        for (index in 0...geometry.items.length) {
            final distance = loopingDistance(offset, viewport, geometry.items[index]);
            if (best == null || distance < bestDistance) {
                best = index;
                bestDistance = distance;
            }
        }
        return best;
    }

    /** Begins a pointer drag and notifies the owning entity. */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function beginDrag(position:Point, cx:Context<CarouselState>):Bool {
        final cancelledScroll = scrollGesture != null;
        final started = beginDragSnapshot(position);
        if (started) {
            if (cancelledScroll) {
                scheduleIgnoredScrollRecovery(cx);
            }
            cx.notify();
        }
        return started;
    }

    /**
     * Updates the active pointer drag after locking it to the carousel axis.
     * Cross-axis drags cancel this gesture so an ancestor can handle them.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function updateDrag(position:Point, cx:Context<CarouselState>):Bool {
        final gesture = pointerGesture;
        if (gesture == null) {
            return false;
        }

        final delta = new Point(f32(position.x - gesture.startPosition.x), f32(position.y - gesture.startPosition.y));
        final primaryDelta = this.primaryDelta(delta);
        if (!gesture.axisLocked) {
            final crossAxisDelta = this.crossAxisDelta(delta);
            if (Math.max(Math.abs(primaryDelta), Math.abs(crossAxisDelta)) <= POINTER_AXIS_LOCK_THRESHOLD) {
                return false;
            }
            if (Math.abs(crossAxisDelta) > Math.abs(primaryDelta)) {
                pointerGesture = null;
                suppressPointerClick = true;
                cx.notify();
                return false;
            }
            gesture.axisLocked = true;
        }

        gesture.totalDelta = primaryDelta;
        pointerGesture = gesture;
        final next = clampedOffset(f32(primaryOffset(gesture.startOffset) + primaryDelta));
        final offset = setPrimaryOffset(gesture.startOffset, next);
        final previous = scrollHandleValue.offset();
        scrollHandleValue.setOffset(offset);
        normalizeLoopCoordinate();
        final changed = !scrollHandleValue.offset().equals(previous);
        if (changed) {
            cx.notify();
        }
        return true;
    }

    /**
     * Finishes a pointer drag by selecting the nearest item and settling the
     * handle to its snap point.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function finishDrag(cx:Context<CarouselState>):Bool {
        final suppressedClick = suppressPointerClick;
        suppressPointerClick = false;
        final gesture = pointerGesture;
        pointerGesture = null;
        if (gesture == null) {
            if (suppressedClick) {
                cx.notify();
            }
            return false;
        }
        return finishSnapshot(gesture.startOffset, gesture.startIndex, gesture.totalDelta, cx);
    }

    /**
     * Applies a precise trackpad delta and remembers the gesture's start.
     * Returns whether the delta moved the handle or can be consumed by a
     * looping carousel.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function handleScrollDelta(axis:Axis, delta:Float, phase:TouchPhase, cx:Context<CarouselState>):Bool {
        if (axis != _axis || _itemCount < 2) {
            return false;
        }

        rebasePendingLoopMotion();

        if (ignoreScrollUntilQuiet) {
            switch phase {
                case Started:
                    ignoreScrollUntilQuiet = false;
                    invalidateScrollSettle();
                case Ended | Cancelled:
                    ignoreScrollUntilQuiet = false;
                    invalidateScrollSettle();
                    return false;
                case Moved:
                    scheduleIgnoredScrollRecovery(cx);
                    return false;
            }
        }

        if (phase == Started && scrollGesture != null) {
            finishScroll(false, cx);
        }

        if (scrollGesture == null) {
            pointerGesture = null;
            scrollGesture = new ScrollGesture(scrollHandleValue.offset(), _selectedIndex, 0.);
        }

        if (scrollGesture != null) {
            scrollGesture.totalDelta = f32(scrollGesture.totalDelta + delta);
        }
        else {
            return false;
        }

        final previous = scrollHandleValue.offset();
        final next = clampedOffset(f32(primaryOffset(previous) + delta));
        final offset = setPrimaryOffset(previous, next);
        scrollHandleValue.setOffset(offset);
        normalizeLoopCoordinate();
        final moved = !scrollHandleValue.offset().equals(previous);
        if (moved) {
            cx.notify();
        }
        if (phase == Started || phase == Moved) {
            scheduleScrollSettle(cx);
        }
        return moved || runtimeLooping();
    }

    /**
     * Finishes a precise trackpad gesture. Cancelled gestures restore the
     * original offset and never emit a selection event.
     */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    function finishScroll(cancelled:Bool, cx:Context<CarouselState>):Bool {
        invalidateScrollSettle();
        if (ignoreScrollUntilQuiet) {
            ignoreScrollUntilQuiet = false;
            return false;
        }
        final gesture = scrollGesture;
        scrollGesture = null;
        if (gesture == null) {
            return false;
        }
        if (cancelled) {
            scrollHandleValue.setOffset(gesture.startOffset);
            cx.notify();
            return false;
        }

        return finishSnapshot(gesture.startOffset, gesture.startIndex, gesture.totalDelta, cx);
    }

    /**
     * Hands a trackpad gesture that began at an edge to an ancestor scroller
     * until it ends or goes quiet.
     */
    @:allow(gpui.component.carousel)
    function deferScrollToAncestor(cx:Context<CarouselState>):Void {
        scrollGesture = null;
        invalidateScrollSettle();
        ignoreScrollUntilQuiet = true;
        scheduleIgnoredScrollRecovery(cx);
    }

    /**
     * Applies one mouse-wheel notch. Line deltas carry no touch phases, so
     * the events within one quiet period form a burst that the first event
     * assigns: a step keeps the whole burst here, while a burst that cannot
     * step belongs to an ancestor scroller.
     */
    @:allow(gpui.component.carousel)
    function handleWheelStep(axis:Axis, delta:Float, cx:Context<CarouselState>):Bool {
        if (axis != _axis || delta == 0.) {
            return false;
        }
        if (ignoreScrollUntilQuiet) {
            scheduleIgnoredScrollRecovery(cx);
            return false;
        }
        if (wheelBurstActive) {
            scheduleWheelBurstEnd(cx);
            return true;
        }

        final stepped = if (delta > 0.) {
            selectPrevious(cx);
        }
        else {
            selectNext(cx);
        }
        if (stepped) {
            wheelBurstActive = true;
            scheduleWheelBurstEnd(cx);
        }
        else {
            ignoreScrollUntilQuiet = true;
            scheduleIgnoredScrollRecovery(cx);
        }
        return stepped;
    }

    function selectIndexWithWrap(index:Int, wrapped:Bool, cx:Context<CarouselState>):Bool {
        final clamped = clampIndex(index);
        if (clamped == null) {
            return false;
        }
        final index:Int = clamped;
        final rebasedLoopMotion = rebasePendingLoopMotion();
        final wasInteracting = isInteracting();
        cancelInteractions(cx);
        if (_selectedIndex == index) {
            if (wasInteracting || rebasedLoopMotion) {
                cx.notify();
            }
            return false;
        }

        final current = _selectedIndex;
        final loopTarget = current != null && wrapped ? adjacentLoopTarget(current, index) : null;
        final seamlessWrap = loopTarget != null;
        loopMotionTarget = if (loopTarget != null) {
            final real = snapTargetFor(index);
            real != null && primaryOffset(real) != primaryOffset(loopTarget) ? loopTarget : null;
        } else null;
        _selectedIndex = index;
        if (wrapped && !seamlessWrap) {
            _motionRevision = _motionRevision + 1;
        }
        cx.emit(CarouselEvent.Change(index));
        cx.notify();
        return true;
    }

    function clampIndex(index:Int):Null<Int> {
        return _itemCount > 0 ? (index < _itemCount - 1 ? index : _itemCount - 1) : null;
    }

    function isLoopWrap(current:Int, next:Int):Bool {
        return runtimeLooping()
            && _itemCount > 1
            && ((current == 0 && next + 1 == _itemCount) || (current + 1 == _itemCount && next == 0));
    }

    /**
     * Returns the next logical item that has a distinct physical snap point.
     *
     * When layout has not populated the geometry yet, navigation falls back
     * to logical item indices. Once geometry is available, adjacent items
     * that clamp to the same physical endpoint are treated as one snap
     * point. Keeping the first item in a duplicate group as the canonical
     * index preserves the existing nearest-index tie break at the end of the
     * track, while allowing navigation from a controlled duplicate index to
     * skip back over that group.
     */
    function navigationIndex(current:Int, next:Bool):Null<Int> {
        if (runtimeLooping() || !geometryIsReady()) {
            return logicalNavigationIndex(current, next);
        }

        final currentSnap = snapTargetFor(current);
        if (currentSnap == null) {
            return null;
        }
        final currentTarget = primaryOffset(currentSnap);
        if (next) {
            for (index in current + 1..._itemCount) {
                final target = snapTargetFor(index);
                if (target != null && primaryOffset(target) != currentTarget) {
                    return index;
                }
            }
            return null;
        }
        else {
            var index = current - 1;
            while (index >= 0) {
                final target = snapTargetFor(index);
                if (target != null && primaryOffset(target) != currentTarget) {
                    return index;
                }
                index--;
            }
            return null;
        }
    }

    function logicalNavigationIndex(current:Int, next:Bool):Null<Int> {
        if (next) {
            if (current + 1 < _itemCount) {
                return current + 1;
            }
            else if (runtimeLooping() && _itemCount > 1) {
                return 0;
            }
            else {
                return null;
            }
        }
        else if (current > 0) {
            return current - 1;
        }
        else if (runtimeLooping() && _itemCount > 1) {
            return _itemCount - 1;
        }
        else {
            return null;
        }
    }

    function geometryIsReady():Bool {
        return geometry.viewport != null && geometry.items.length == _itemCount;
    }

    function runtimeLooping():Bool {
        return looping && (!geometryIsReady() || loopLayout != null);
    }

    function adjacentLoopTarget(current:Int, next:Int):Null<Point> {
        final layout = loopLayout;
        if (layout == null || !layout.runwayReady) {
            return null;
        }
        final target = snapTargetFor(next);
        if (target == null) {
            return null;
        }
        final cycle = if (current + 1 == _itemCount && next == 0) {
            -layout.cycleExtent;
        }
        else if (current == 0 && next + 1 == _itemCount) {
            layout.cycleExtent;
        }
        else {
            return null;
        }
        final primary = f32(primaryOffset(target) + cycle);
        return setPrimaryOffset(target, primary);
    }

    function updateLoopLayout():Void {
        final previous = loopLayout;
        var nextMetrics = measuredCycleMetrics();
        if (nextMetrics != null) {
            final extent = nextMetrics.extent;
            final viewport = geometry.viewport;
            if (!(looping && _itemCount > 1 && extent > 0. && viewport != null && extent >= viewport.size.along(_axis))) {
                nextMetrics = null;
            }
        }

        if (nextMetrics == null) {
            if (previous != null && previous.runwayReady) {
                shiftScrollCoordinate(previous.runwayExtent);
                _motionRevision = _motionRevision + 1;
            }
            if (previous != null) {
                loopLayoutRemovalPending = geometryHasRunway;
            }
            else if (loopLayoutRemovalPending && !geometryHasRunway) {
                loopLayoutRemovalPending = false;
            }
            loopLayout = null;
            loopMotionTarget = null;
            return;
        }

        final nextExtent = nextMetrics.extent;
        final nextGap = nextMetrics.gap;
        final sameExtent = previous != null
            && Math.abs(f32(previous.cycleExtent - nextExtent)) <= 0.5
            && Math.abs(f32(previous.trackGap - nextGap)) <= 0.5;
        if (!sameExtent) {
            if (previous != null && previous.runwayReady) {
                shiftScrollCoordinate(previous.runwayExtent);
                pointerGesture = null;
                scrollGesture = null;
                loopMotionTarget = null;
                _motionRevision = _motionRevision + 1;
            }
            loopLayoutRemovalPending = false;
            loopLayout = new LoopLayout(nextExtent, nextGap, f32(nextExtent + nextGap), false);
            return;
        }

        final layout = previous;
        if (layout == null) {
            return;
        }
        if (!layout.runwayReady && geometryHasRunway) {
            shiftScrollCoordinate(-layout.runwayExtent);
            loopLayout = new LoopLayout(layout.cycleExtent, layout.trackGap, layout.runwayExtent, true);
            _motionRevision = _motionRevision + 1;
        }
    }

    function measuredCycleMetrics():Null<{extent:Float, gap:Float}> {
        if (geometry.items.length == 0) {
            return null;
        }
        final first = geometry.items[0];
        final last = geometry.items[geometry.items.length - 1];
        final gap = geometry.items.length > 1 ? Math.max(f32(primaryStart(geometry.items[1]) - primaryEnd(first)), 0.) : 0.;
        return {
            extent: Math.max(f32(f32(primaryEnd(last) - primaryStart(first)) + gap), 0.),
            gap: gap
        };
    }

    function shiftScrollCoordinate(delta:Float):Void {
        final offset = scrollHandleValue.offset();
        final primary = f32(primaryOffset(offset) + delta);
        scrollHandleValue.setOffset(setPrimaryOffset(offset, primary));
        if (pointerGesture != null) {
            pointerGesture.startOffset = shiftPointForAxis(pointerGesture.startOffset, _axis, delta);
        }
        if (scrollGesture != null) {
            scrollGesture.startOffset = shiftPointForAxis(scrollGesture.startOffset, _axis, delta);
        }
        if (loopMotionTarget != null) {
            loopMotionTarget = shiftPointForAxis(loopMotionTarget, _axis, delta);
        }
    }

    function rebasePendingLoopMotion():Bool {
        final virtualTarget = loopMotionTarget;
        if (virtualTarget == null) {
            return false;
        }
        final realTarget = _selectedIndex != null ? snapTargetFor(_selectedIndex) : null;
        if (realTarget == null) {
            loopMotionTarget = null;
            return false;
        }
        final delta = f32(primaryOffset(realTarget) - primaryOffset(virtualTarget));
        shiftScrollCoordinate(delta);
        loopMotionTarget = null;
        _motionRevision = _motionRevision + 1;
        return true;
    }

    /**
     * Keeps an active pointer or trackpad gesture inside the middle runway.
     * Moving by one full cycle is visually identical because every item is
     * painted in the closest cycle, so the gesture snapshots move with the
     * handle and continuous input never reaches the finite runway edge.
     */
    @:allow(tests)
    function normalizeLoopCoordinate():Bool {
        final layout = loopLayout;
        if (layout == null || !(layout.runwayReady && layout.cycleExtent > 0.)) {
            return false;
        }
        final firstTarget = snapTargetFor(0);
        if (firstTarget == null) {
            return false;
        }
        if (_itemCount == 0) {
            return false;
        }
        final lastTarget = snapTargetFor(_itemCount - 1);
        if (lastTarget == null) {
            return false;
        }

        final first = primaryOffset(firstTarget);
        final last = primaryOffset(lastTarget);
        var current = primaryOffset(scrollHandleValue.offset());
        var delta = 0.;
        while (current <= f32(first - layout.cycleExtent)) {
            current = f32(current + layout.cycleExtent);
            delta = f32(delta + layout.cycleExtent);
        }
        while (current >= f32(last + layout.cycleExtent)) {
            current = f32(current - layout.cycleExtent);
            delta = f32(delta - layout.cycleExtent);
        }
        if (delta == 0.) {
            return false;
        }
        shiftScrollCoordinate(delta);
        return true;
    }

    static function shiftPointForAxis(point:Point, axis:Axis, delta:Float):Point {
        return switch axis {
            case Horizontal: new Point(f32(point.x + delta), point.y);
            case Vertical: new Point(point.x, f32(point.y + delta));
        }
    }

    function cancelInteractions(cx:Context<CarouselState>):Void {
        final cancelledScroll = scrollGesture != null;
        pointerGesture = null;
        scrollGesture = null;
        invalidateScrollSettle();
        if (cancelledScroll) {
            ignoreScrollUntilQuiet = true;
            scheduleIgnoredScrollRecovery(cx);
        }
    }

    function cancelUserInteraction(cx:Context<CarouselState>):Void {
        final wasInteracting = isInteracting();
        cancelInteractions(cx);
        if (wasInteracting) {
            cx.notify();
        }
    }

    function beginDragSnapshot(position:Point):Bool {
        suppressPointerClick = false;
        if (_itemCount < 2) {
            return false;
        }
        rebasePendingLoopMotion();
        pointerGesture = new PointerGesture(position, scrollHandleValue.offset(), _selectedIndex, 0., false);
        if (scrollGesture != null) {
            ignoreScrollUntilQuiet = true;
        }
        scrollGesture = null;
        invalidateScrollSettle();
        return true;
    }

    function scheduleScrollSettle(cx:Context<CarouselState>):Void {
        scrollSettleEpoch = scrollSettleEpoch + 1;
        final epoch = scrollSettleEpoch;
        cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(SCROLL_EVENT_SEPARATION).then(_ -> {
            final entity = this_.upgrade();
            if (entity != null) {
                entity.update(acx, (state, cx) -> {
                    if (state.scrollSettleEpoch == epoch && state.scrollGesture != null) {
                        state.finishScroll(false, cx);
                    }
                });
            }
        })).detach();
    }

    function scheduleIgnoredScrollRecovery(cx:Context<CarouselState>):Void {
        scrollSettleEpoch = scrollSettleEpoch + 1;
        final epoch = scrollSettleEpoch;
        cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(SCROLL_EVENT_SEPARATION).then(_ -> {
            final entity = this_.upgrade();
            if (entity != null) {
                entity.update(acx, (state, _) -> {
                    if (state.scrollSettleEpoch == epoch) {
                        state.ignoreScrollUntilQuiet = false;
                    }
                });
            }
        })).detach();
    }

    function scheduleWheelBurstEnd(cx:Context<CarouselState>):Void {
        wheelBurstEpoch = wheelBurstEpoch + 1;
        final epoch = wheelBurstEpoch;
        cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(SCROLL_EVENT_SEPARATION).then(_ -> {
            final entity = this_.upgrade();
            if (entity != null) {
                entity.update(acx, (state, _) -> {
                    if (state.wheelBurstEpoch == epoch) {
                        state.wheelBurstActive = false;
                    }
                });
            }
        })).detach();
    }

    function invalidateScrollSettle():Void {
        scrollSettleEpoch = scrollSettleEpoch + 1;
    }

    function finishSnapshot(startOffset:Point, startIndex:Null<Int>, totalDelta:Float, cx:Context<CarouselState>):Bool {
        final currentOffset = scrollHandleValue.offset();
        final selected = if (runtimeLooping()) {
            final boundary = loopBoundaryIndex(startIndex, totalDelta);
            boundary != null ? boundary : nearestIndex(currentOffset);
        }
        else {
            nearestIndex(currentOffset);
        }

        final changed = if (selected == null) {
            false;
        }
        else if (_selectedIndex == selected) {
            false;
        }
        else {
            final wrapped = _selectedIndex != null && isLoopWrap(_selectedIndex, selected);
            selectIndexWithWrap(selected, wrapped, cx);
        }

        if (selected == null) {
            scrollHandleValue.setOffset(startOffset);
        }
        if (!changed) {
            cx.notify();
        }
        return changed;
    }

    function loopBoundaryIndex(startIndex:Null<Int>, totalDelta:Float):Null<Int> {
        if (startIndex == null) {
            return null;
        }
        final threshold = f32(snapExtent() * 0.25);
        if (Math.abs(totalDelta) < Math.max(threshold, 1.)) {
            return null;
        }
        if (startIndex == 0 && totalDelta > 0.) {
            return _itemCount > 0 ? _itemCount - 1 : null;
        }
        else if (startIndex + 1 == _itemCount && totalDelta < 0.) {
            return 0;
        }
        else {
            return null;
        }
    }

    function snapExtent():Float {
        if (geometry.viewport != null) {
            return geometry.viewport.size.along(_axis);
        }
        if (geometry.items.length > 0) {
            return geometry.items[0].size.along(_axis);
        }
        return 1.;
    }

    function snapOffset(viewport:Bounds, item:Bounds):Point {
        final offset = scrollHandleValue.offset();
        var target = switch _axis {
            case Horizontal: f32(viewport.left() - item.left());
            case Vertical: f32(viewport.top() - item.top());
        };
        final layout = loopLayout;
        if (layout != null && layout.runwayReady) {
            final contentInset = geometry.items.length > 0
                ? f32(f32(primaryStart(geometry.items[0]) - primaryStart(viewport)) - layout.runwayExtent)
                : 0.;
            target = f32(target + contentInset);
        }
        else {
            target = MathUtil.clamp(target, -maxSnapOffset(), 0.);
        }
        return setPrimaryOffset(offset, target);
    }

    function maxSnapOffset():Float {
        final handleMax = Math.max(primaryOffset(scrollHandleValue.maxOffset()), 0.);
        final viewport = geometry.viewport;
        if (viewport == null) {
            return handleMax;
        }
        if (geometry.items.length == 0) {
            return handleMax;
        }
        final first = geometry.items[0];

        var contentStart = primaryStart(first);
        var contentEnd = primaryEnd(first);
        for (i in 1...geometry.items.length) {
            final item = geometry.items[i];
            contentStart = Math.min(contentStart, primaryStart(item));
            contentEnd = Math.max(contentEnd, primaryEnd(item));
        }
        final geometryMax = Math.max(f32(f32(contentEnd - contentStart) - viewport.size.along(_axis)), 0.);
        return Math.max(handleMax, geometryMax);
    }

    function primaryDistance(offset:Point, viewport:Bounds, item:Bounds):Float {
        final target = snapOffset(viewport, item);
        return Math.abs(f32(primaryOffset(offset) - primaryOffset(target)));
    }

    function loopingDistance(offset:Point, viewport:Bounds, item:Bounds):Float {
        final distance = primaryDistance(offset, viewport, item);
        final layout = loopLayout;
        if (layout == null || !layout.runwayReady) {
            return distance;
        }
        final target = primaryOffset(snapOffset(viewport, item));
        final offset = primaryOffset(offset);
        return Math.min(Math.min(distance, Math.abs(f32(offset - f32(target - layout.cycleExtent)))), Math.abs(f32(offset - f32(target + layout.cycleExtent))));
    }

    inline function primaryOffset(offset:Point):Float {
        return _axis == Horizontal ? offset.x : offset.y;
    }

    inline function primaryStart(bounds:Bounds):Float {
        return _axis == Horizontal ? bounds.origin.x : bounds.origin.y;
    }

    inline function primaryEnd(bounds:Bounds):Float {
        return _axis == Horizontal ? f32(bounds.origin.x + bounds.size.width) : f32(bounds.origin.y + bounds.size.height);
    }

    function axisPoint(value:Float):Point {
        return _axis == Horizontal ? new Point(value, 0.) : new Point(0., value);
    }

    /** Rust `set_primary_offset` on a copy (points are immutable here). */
    inline function setPrimaryOffset(offset:Point, value:Float):Point {
        return _axis == Horizontal ? new Point(value, offset.y) : new Point(offset.x, value);
    }

    inline function primaryDelta(delta:Point):Float {
        return _axis == Horizontal ? delta.x : delta.y;
    }

    inline function crossAxisDelta(delta:Point):Float {
        return _axis == Horizontal ? delta.y : delta.x;
    }

    function clampedOffset(value:Float):Float {
        final maxOffset = scrollHandleValue.maxOffset();
        final bound = Math.max(primaryOffset(maxOffset), 0.);
        return MathUtil.clamp(value, -bound, 0.);
    }

    static inline function saturatingSub(a:Int, b:Int):Int {
        return a > b ? a - b : 0;
    }

    /**
     * The keyboard focus shared by every part: the root tracks it, and a
     * clicked control moves focus here so the arrow keys keep working.
     */
    public function focusHandle(cx:App):FocusHandle {
        if (focusHandleValue == null) {
            focusHandleValue = cx.focusHandle();
        }
        return focusHandleValue;
    }

}
