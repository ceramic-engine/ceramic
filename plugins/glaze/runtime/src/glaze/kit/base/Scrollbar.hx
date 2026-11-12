// Ported from gpui-kit 0.8.1: crates/base/src/scrollbar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deviation DEV-023 (scrollbar appearance: fade in place by default, no thumb growth, an 8 pixel fully rounded thumb). See docs/DEVIATIONS.md.
package glaze.kit.base;

import glaze.App;
import glaze.Axis;
import glaze.Background;
import glaze.Bounds;
import glaze.ContentMask;
import glaze.Corners;
import glaze.Edges;
import glaze.Element;
import glaze.ElementId;
import glaze.GlobalElementId;
import glaze.Hitbox;
import glaze.HitboxBehavior;
import glaze.Hsla;
import glaze.IntoBackground;
import glaze.ElementIdArg;
import glaze.Length;
import glaze.LayoutId;
import glaze.ListState;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.Size;
import glaze.Style;
import glaze.UniformListScrollHandle;
import glaze.Window;
import glaze.kit.base.ScrollbarAppearance.ScrollbarTransition;
import glaze.kit.base.animation.Easings;
import glaze.kit.base.motion.MotionTime;
import glaze.kit.base.theme.ScrollbarMode;
import glaze.kit.base.theme.Theme as BaseTheme;

import glaze.Prelude.*;

/**
 * Scrollbar show mode (defined with the Base theme, `glaze.kit.base.theme.ScrollbarMode`).
 */
typedef ScrollbarMode = glaze.kit.base.theme.ScrollbarMode;

/**
 * A scroll handle that can get and set offset (Rust trait `ScrollbarHandle`).
 * Implement it, or pass a `ScrollHandle`, `UniformListScrollHandle` or
 * `ListState`: they convert to it implicitly.
 */
interface ScrollbarHandleImpl {

    /** Bounds of the viewport the scrollbar overlays. */
    function viewportBounds():Bounds;

    /** Get the current offset of the scroll handle. */
    function offset():Point;

    /** Set the offset of the scroll handle. */
    function setOffset(offset:Point):Void;

    /** The full size of the content, including padding. */
    function contentSize():Size;

    /** Called when start dragging the scrollbar thumb. */
    function startDrag():Void;

    /** Called when end dragging the scrollbar thumb. */
    function endDrag():Void;

}

/**
 * Optional, for a `ScrollbarHandleImpl` whose content has a vertical padding
 * outside its scrolled text (Glaze addition): the vertical thumb is measured
 * against the viewport and the content without it, like the scrollbar of the
 * kit's editors. The track and the scroll range are unchanged.
 */
interface ScrollbarThumbPadding {

    /** The vertical padding (top plus bottom) left out of the thumb, 0 for none. */
    function thumbVerticalPadding():Float;

}

/**
 * Rust `impl ScrollbarHandle`: any `ScrollbarHandleImpl`, or a GPUI scroll
 * handle wrapped on the fly.
 */
@:forward
abstract ScrollbarHandle(ScrollbarHandleImpl) from ScrollbarHandleImpl to ScrollbarHandleImpl {

    @:from static inline function fromScrollHandle(handle:ScrollHandle):ScrollbarHandle {
        return new ScrollHandleScrollbar(handle);
    }

    @:from static inline function fromUniformListScrollHandle(handle:UniformListScrollHandle):ScrollbarHandle {
        return new UniformListScrollbar(handle);
    }

    @:from static inline function fromListState(handle:ListState):ScrollbarHandle {
        return new ListStateScrollbar(handle);
    }

}

/**
 * `impl ScrollbarHandle for ScrollHandle`.
 */
class ScrollHandleScrollbar implements ScrollbarHandleImpl {

    public final handle:ScrollHandle;

    public function new(handle:ScrollHandle) {
        this.handle = handle;
    }

    public function viewportBounds():Bounds {
        return handle.bounds();
    }

    public function offset():Point {
        return handle.offset();
    }

    public function setOffset(offset:Point):Void {
        handle.setOffset(offset);
    }

    public function contentSize():Size {
        final max = handle.maxOffset();
        final size = handle.bounds().size;
        return new Size(max.x + size.width, max.y + size.height);
    }

    public function startDrag():Void {}

    public function endDrag():Void {}

}

/**
 * `impl ScrollbarHandle for UniformListScrollHandle`.
 */
class UniformListScrollbar implements ScrollbarHandleImpl {

    public final handle:UniformListScrollHandle;

    public function new(handle:UniformListScrollHandle) {
        this.handle = handle;
    }

    public function viewportBounds():Bounds {
        return handle.state.baseHandle.bounds();
    }

    public function offset():Point {
        return handle.state.baseHandle.offset();
    }

    public function setOffset(offset:Point):Void {
        handle.state.baseHandle.setOffset(offset);
    }

    public function contentSize():Size {
        final baseHandle = handle.state.baseHandle;
        final max = baseHandle.maxOffset();
        final size = baseHandle.bounds().size;
        return new Size(max.x + size.width, max.y + size.height);
    }

    public function startDrag():Void {}

    public function endDrag():Void {}

}

/**
 * `impl ScrollbarHandle for ListState`.
 */
class ListStateScrollbar implements ScrollbarHandleImpl {

    public final handle:ListState;

    public function new(handle:ListState) {
        this.handle = handle;
    }

    public function viewportBounds():Bounds {
        return handle.viewportBounds();
    }

    public function offset():Point {
        return handle.scrollPxOffsetForScrollbar();
    }

    public function setOffset(offset:Point):Void {
        handle.setOffsetFromScrollbar(offset);
    }

    public function contentSize():Size {
        final size = handle.viewportBounds().size;
        final max = handle.maxOffsetForScrollbar();
        return new Size(size.width + max.x, size.height + max.y);
    }

    public function startDrag():Void {
        handle.scrollbarDragStarted();
    }

    public function endDrag():Void {
        handle.scrollbarDragEnded();
    }

}

/**
 * A transition of a scalar (Rust `ScalarTransition<T>`). Times are in
 * seconds (`cx.backgroundExecutor().now()`).
 */
@:allow(glaze.kit.base)
class ScalarTransition {

    var from:Float;

    var target:Float;

    var startedAt:Float;

    var duration:Float;

    function new(from:Float, target:Float, startedAt:Float, duration:Float) {
        this.from = from;
        this.target = target;
        this.startedAt = startedAt;
        this.duration = duration;
    }

    static function settled(value:Float, now:Float):ScalarTransition {
        return new ScalarTransition(value, value, now, 0);
    }

    function copy():ScalarTransition {
        return new ScalarTransition(from, target, startedAt, duration);
    }

    /**
     * The value at `now` (`value`), and whether the transition is still running.
     */
    function sample(now:Float, interpolate:(Float, Float, Float) -> Float):TransitionSample {
        if (from == target || duration == 0) {
            return new TransitionSample(target, false);
        }
        final elapsed = MotionTime.nanos(now) - MotionTime.nanos(startedAt);
        final linear = f32(MotionTime.asSecsF32(elapsed > 0 ? elapsed : 0) / MotionTime.asSecsF32(MotionTime.nanos(duration)));
        if (linear >= 1.0) {
            return new TransitionSample(target, false);
        }
        return new TransitionSample(interpolate(from, target, clamp01(linear)), true);
    }

    function start(from:Float, target:Float, duration:Float, now:Float):Void {
        this.from = from;
        this.target = target;
        this.startedAt = now;
        this.duration = duration;
    }

    function settle(target:Float, now:Float):Void {
        start(target, target, 0, now);
    }

    static inline function clamp01(value:Float):Float {
        return value < 0 ? 0 : (value > 1 ? 1 : value);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * A sampled value and whether its transition still runs.
 */
class TransitionSample {

    public final value:Float;

    public final running:Bool;

    public inline function new(value:Float, running:Bool) {
        this.value = value;
        this.running = running;
    }

}

/**
 * The animated width of a thumb (Rust `WidthAnimation`).
 */
@:allow(glaze.kit.base)
class WidthAnimation {

    var transition:ScalarTransition;

    var initialized:Bool = false;

    function new(now:Float) {
        transition = ScalarTransition.settled(0, now);
    }

    function copy():WidthAnimation {
        final result = new WidthAnimation(0);
        result.transition = transition.copy();
        result.initialized = initialized;
        return result;
    }

    function sample(now:Float):TransitionSample {
        return transition.sample(now, (from, target, linear) -> {
            return f32(from + f32(f32(target - from) * Easings.easeOutCubic(linear)));
        });
    }

    /**
     * Move toward `target` over `duration`. A zero duration adopts the target
     * immediately, which is how reduced motion and a motionless theme arrive here.
     */
    function setTarget(target:Float, duration:Float, now:Float):TransitionSample {
        if (duration == 0 || !initialized) {
            transition.settle(target, now);
            initialized = true;
        }
        else if (transition.target != target) {
            final from = sample(now).value;
            transition.start(from, target, duration, now);
        }
        return sample(now);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * How a scrollbar becomes visible.
 *
 * The styled layer chooses the choreography; Base only plays it.
 */
enum abstract ScrollbarEntrance(Int) {

    /** Fade in without moving (the default). */
    var Fade = 0;

    /** Slide in from the nearest edge while fading. */
    var SlideAndFade = 1;

}

/**
 * Motion tokens used by `Scrollbar`.
 *
 * Base installs no motion of its own: every transition duration defaults to
 * zero, so visibility and thumb width snap. Product timing belongs to the
 * styled layer, which projects it through `ScrollbarTheme`. Durations are in
 * seconds.
 */
class ScrollbarMotion {

    /**
     * How long visibility is held after the last activity, when the styled layer
     * projects no `ScrollbarMotion` of its own (2 seconds).
     *
     * This is a visibility hold rather than motion: without it `ScrollbarMode.Scrolling`
     * could never reveal the scrollbar.
     */
    public static inline final DEFAULT_IDLE:Float = 2.0;

    var _idle:Float = DEFAULT_IDLE;

    var _enter:Float = 0;

    var _exit:Float = 0;

    var _expand:Float = 0;

    var _entrance:ScrollbarEntrance = Fade;

    var _thumbHoverEntrance:ScrollbarEntrance = Fade;

    public function new() {}

    function copy():ScrollbarMotion {
        final result = new ScrollbarMotion();
        result._idle = _idle;
        result._enter = _enter;
        result._exit = _exit;
        result._expand = _expand;
        result._entrance = _entrance;
        result._thumbHoverEntrance = _thumbHoverEntrance;
        return result;
    }

    /** How long visibility is held after the last scroll, drag, or hover. */
    public function withIdle(idle:Float):ScrollbarMotion {
        final result = copy();
        result._idle = idle;
        return result;
    }

    /** How long the scrollbar takes to become fully visible. */
    public function withEnter(enter:Float):ScrollbarMotion {
        final result = copy();
        result._enter = enter;
        return result;
    }

    /** How long the scrollbar takes to fade away once the idle hold expires. */
    public function withExit(exit:Float):ScrollbarMotion {
        final result = copy();
        result._exit = exit;
        return result;
    }

    /** How long the thumb takes to reach a new width. */
    public function withExpand(expand:Float):ScrollbarMotion {
        final result = copy();
        result._expand = expand;
        return result;
    }

    /** Which entrance choreography to play. */
    public function withEntrance(entrance:ScrollbarEntrance):ScrollbarMotion {
        final result = copy();
        result._entrance = entrance;
        return result;
    }

    /** Which entrance choreography to play when hover reveals the thumb. */
    public function withThumbHoverEntrance(entrance:ScrollbarEntrance):ScrollbarMotion {
        final result = copy();
        result._thumbHoverEntrance = entrance;
        return result;
    }

    public inline function idle():Float {
        return _idle;
    }

    public inline function enter():Float {
        return _enter;
    }

    public inline function exit():Float {
        return _exit;
    }

    public inline function expand():Float {
        return _expand;
    }

    public inline function entrance():ScrollbarEntrance {
        return _entrance;
    }

    public inline function thumbHoverEntrance():ScrollbarEntrance {
        return _thumbHoverEntrance;
    }

    @:allow(glaze.kit.base)
    function entranceFor(mode:ScrollbarMode, thumbHovered:Bool):ScrollbarEntrance {
        if (mode == Hover && thumbHovered) {
            return _thumbHoverEntrance;
        }
        return _entrance;
    }

    public function equals(other:ScrollbarMotion):Bool {
        return _idle == other._idle
            && _enter == other._enter
            && _exit == other._exit
            && _expand == other._expand
            && _entrance == other._entrance
            && _thumbHoverEntrance == other._thumbHoverEntrance;
    }

}

/**
 * Sampled visibility (Rust `VisibilitySample`).
 */
class VisibilitySample {

    public final opacity:Float;

    public final position:Float;

    public final running:Bool;

    public inline function new(opacity:Float, position:Float, running:Bool) {
        this.opacity = opacity;
        this.position = position;
        this.running = running;
    }

}

/**
 * The visibility of a scrollbar: an opacity and a slide position (Rust
 * `VisibilityAnimation`).
 */
@:allow(glaze.kit.base)
class VisibilityAnimation {

    var opacity:ScalarTransition;

    var position:ScalarTransition;

    var entrance:ScrollbarEntrance = Fade;

    /**
     * Whether hiding slides toward the edge while fading (gpui-kit), or fades
     * linearly in place (Glaze addition, DEV-023: `ScrollbarTransition.Fade`).
     */
    var slideOut:Bool = true;

    function new(opacity:ScalarTransition, position:ScalarTransition) {
        this.opacity = opacity;
        this.position = position;
    }

    static function hidden(now:Float):VisibilityAnimation {
        return new VisibilityAnimation(ScalarTransition.settled(0, now), ScalarTransition.settled(0, now));
    }

    function copy():VisibilityAnimation {
        final result = new VisibilityAnimation(opacity.copy(), position.copy());
        result.entrance = entrance;
        result.slideOut = slideOut;
        return result;
    }

    function sample(now:Float):VisibilitySample {
        final entering = opacity.target > opacity.from || position.target > position.from;
        // DEV-023: a fade out in place is linear and keeps the position it
        // started from until it ends (fully transparent by then)
        final fadeOut = !entering && !slideOut;
        final opacitySample = opacity.sample(now, (from, target, linear) -> {
            final factor = entering || fadeOut ? linear : Easings.easeInCubic(linear);
            return f32(from + f32(f32(target - from) * factor));
        });
        final positionSample = position.sample(now, (from, target, linear) -> {
            final factor = entering ? Easings.easeOutCubic(linear) : Easings.easeInCubic(linear);
            return f32(from + f32(f32(target - from) * factor));
        });
        final positionValue = fadeOut && positionSample.running ? position.from : positionSample.value;
        return new VisibilitySample(opacitySample.value, positionValue, opacitySample.running || positionSample.running);
    }

    /**
     * Reverse or start a transition toward `visible`.
     *
     * The leg runs for `enter` or `exit` scaled by the distance still to cover,
     * so an interrupted transition keeps its speed instead of restarting.
     *
     * `slideOut` (Glaze addition, DEV-023): false fades out in place,
     * linearly, instead of sliding toward the edge.
     */
    function setVisible(visible:Bool, entrance:ScrollbarEntrance, enter:Float, exit:Float, now:Float, slideOut:Bool = true):Void {
        this.slideOut = slideOut;
        final target = visible ? 1.0 : 0.0;
        final fullDuration = visible ? enter : exit;
        if (fullDuration == 0) {
            // A motionless policy (reduced motion, an always-visible scrollbar,
            // or a theme that projects no motion) adopts the target outright,
            // even if a transition was in flight when the policy changed.
            opacity.settle(target, now);
            position.settle(target, now);
            this.entrance = entrance;
            return;
        }
        if (opacity.target == target && position.target == target && this.entrance == entrance) {
            return;
        }

        final sample = this.sample(now);
        final fromPosition = visible && entrance == Fade ? 1.0 : sample.position;
        final distance = Math.max(Math.abs(target - sample.opacity), Math.abs(target - fromPosition));
        // `Duration::mul_f32`
        final duration = fullDuration * f32(distance);
        opacity.start(sample.opacity, target, duration, now);
        position.start(fromPosition, target, duration, now);
        this.entrance = entrance;
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * The state of a scrollbar kept across frames (Rust `ScrollbarStateInner`,
 * mutated in place instead of copied in and out of a `Cell`).
 */
@:allow(glaze.kit.base)
class ScrollbarState {

    var hoveredAxis:Null<Axis> = null;

    var hoveredOnThumb:Null<Axis> = null;

    var draggedAxis:Null<Axis> = null;

    var dragPos:Point = new Point(0, 0);

    var lastScrollOffset:Point = new Point(0, 0);

    var lastScrollTime:Null<Float> = null;

    /** Last update offset */
    var lastUpdate:Float;

    var dragUpdateScheduled:Bool = false;

    var dragUpdateGeneration:Int = 0;

    var idleTimerScheduled:Bool = false;

    var visibility:VisibilityAnimation;

    var verticalWidth:WidthAnimation;

    var horizontalWidth:WidthAnimation;

    function new(now:Float) {
        lastUpdate = now;
        visibility = VisibilityAnimation.hidden(now);
        verticalWidth = new WidthAnimation(now);
        horizontalWidth = new WidthAnimation(now);
    }

    function withDragPos(axis:Axis, pos:Point, now:Float):ScrollbarState {
        if (axis == Vertical) {
            dragPos = new Point(dragPos.x, pos.y);
        }
        else {
            dragPos = new Point(pos.x, dragPos.y);
        }
        draggedAxis = axis;
        lastUpdate = now;
        dragUpdateScheduled = false;
        dragUpdateGeneration = (dragUpdateGeneration + 1) & 0x7fffffff;
        return this;
    }

    function withUnsetDragPos(now:Float):ScrollbarState {
        draggedAxis = null;
        dragUpdateScheduled = false;
        dragUpdateGeneration = (dragUpdateGeneration + 1) & 0x7fffffff;
        lastScrollTime = now;
        return this;
    }

    function withHovered(axis:Null<Axis>, now:Float):ScrollbarState {
        hoveredAxis = axis;
        lastScrollTime = now;
        return this;
    }

    function withHoveredOnThumb(axis:Null<Axis>, now:Float):ScrollbarState {
        final visible = isScrollbarVisible(now);
        hoveredOnThumb = axis;
        if (visible) {
            if (axis != null) {
                lastScrollTime = now;
            }
        }
        return this;
    }

    function withLastScroll(lastScrollOffset:Point, lastScrollTime:Null<Float>):ScrollbarState {
        this.lastScrollOffset = lastScrollOffset;
        this.lastScrollTime = lastScrollTime;
        return this;
    }

    function isScrollbarVisible(now:Float):Bool {
        return draggedAxis != null || visibility.sample(now).opacity > 0.0;
    }

    /**
     * Notify the view of a drag, at most once per `interval`, with a trailing
     * notification for the last move of a burst.
     */
    function notifyDrag(now:Float, interval:Float, view:Int, window:Window, cx:App):Void {
        if (dragUpdateScheduled) {
            return;
        }
        final elapsed = Math.max(0, now - lastUpdate);
        if (elapsed >= interval) {
            lastUpdate = now;
            cx.notify(view);
            return;
        }
        dragUpdateScheduled = true;
        final generation = dragUpdateGeneration;
        final delay = interval - elapsed;
        cx.backgroundExecutor().timer(delay).then(_ -> {
            // A release or new drag supersedes the pending trailing update.
            if (!dragUpdateScheduled || dragUpdateGeneration != generation) {
                return;
            }
            dragUpdateScheduled = false;
            lastUpdate = cx.backgroundExecutor().now();
            if (!window.isDestroyed()) {
                cx.update(cx -> cx.notify(view));
            }
        });
    }

}

/**
 * Scrollbar axis.
 */
enum abstract ScrollbarAxis(Int) {

    /** Vertical scrollbar. */
    var Vertical = 0;

    /** Horizontal scrollbar. */
    var Horizontal = 1;

    /** Show both vertical and horizontal scrollbars. */
    var Both = 2;

    @:from static inline function fromAxis(axis:Axis):ScrollbarAxis {
        return axis == Axis.Vertical ? Vertical : Horizontal;
    }

    /** Return true if the scrollbar axis is vertical. */
    public inline function isVertical():Bool {
        return this == 0;
    }

    /** Return true if the scrollbar axis is horizontal. */
    public inline function isHorizontal():Bool {
        return this == 1;
    }

    /** Return true if the scrollbar axis is both vertical and horizontal. */
    public inline function isBoth():Bool {
        return this == 2;
    }

    /** Return true if the scrollbar has vertical axis. */
    public inline function hasVertical():Bool {
        return this == 0 || this == 2;
    }

    /** Return true if the scrollbar has horizontal axis. */
    public inline function hasHorizontal():Bool {
        return this == 1 || this == 2;
    }

    public function all():Array<Axis> {
        return switch (cast this : ScrollbarAxis) {
            case Vertical: [Axis.Vertical];
            case Horizontal: [Axis.Horizontal];
            // This should keep Horizontal first, Vertical is the primary axis
            // if Vertical not need display, then Horizontal will not keep right margin.
            case Both: [Axis.Horizontal, Axis.Vertical];
        }
    }

}

/**
 * Paint-only styles for a scrollbar track.
 */
class ScrollbarTrackStyle {

    @:allow(glaze.kit.base) var _background:Null<Hsla> = null;

    @:allow(glaze.kit.base) var _border:Null<Hsla> = null;

    @:allow(glaze.kit.base) var _width:Null<Float> = null;

    public function new() {}

    public function bg(background:Hsla):ScrollbarTrackStyle {
        this._background = background;
        return this;
    }

    public function borderColor(border:Hsla):ScrollbarTrackStyle {
        this._border = border;
        return this;
    }

    public function width(width:Float):ScrollbarTrackStyle {
        this._width = width;
        return this;
    }

    /** `FluentBuilder::when`. */
    public function when(condition:Bool, then:(ScrollbarTrackStyle) -> ScrollbarTrackStyle):ScrollbarTrackStyle {
        return condition ? then(this) : this;
    }

    public function backgroundValue():Null<Hsla> {
        return _background;
    }

    public function borderValue():Null<Hsla> {
        return _border;
    }

    public function widthValue():Null<Float> {
        return _width;
    }

}

/**
 * Paint-only styles for a scrollbar thumb.
 */
class ScrollbarThumbStyle {

    @:allow(glaze.kit.base) var _background:Null<Background> = null;

    @:allow(glaze.kit.base) var _width:Null<Float> = null;

    @:allow(glaze.kit.base) var _inset:Null<Float> = null;

    @:allow(glaze.kit.base) var _radius:Null<Float> = null;

    @:allow(glaze.kit.base) var _minLength:Null<Float> = null;

    public function new() {}

    public function bg(background:IntoBackground):ScrollbarThumbStyle {
        this._background = background;
        return this;
    }

    public function width(width:Float):ScrollbarThumbStyle {
        this._width = width;
        return this;
    }

    public function inset(inset:Float):ScrollbarThumbStyle {
        this._inset = inset;
        return this;
    }

    public function radius(radius:Float):ScrollbarThumbStyle {
        this._radius = radius;
        return this;
    }

    public function minLength(minLength:Float):ScrollbarThumbStyle {
        this._minLength = minLength;
        return this;
    }

    /** `FluentBuilder::when`. */
    public function when(condition:Bool, then:(ScrollbarThumbStyle) -> ScrollbarThumbStyle):ScrollbarThumbStyle {
        return condition ? then(this) : this;
    }

    public function backgroundValue():Null<Background> {
        return _background;
    }

    public function widthValue():Null<Float> {
        return _width;
    }

    public function insetValue():Null<Float> {
        return _inset;
    }

    public function radiusValue():Null<Float> {
        return _radius;
    }

    public function minLengthValue():Null<Float> {
        return _minLength;
    }

}

/**
 * Typed paint styles supported by `Scrollbar`.
 */
class ScrollbarStyles {

    @:allow(glaze.kit.base) final _track:ScrollbarTrackStyle = new ScrollbarTrackStyle();

    @:allow(glaze.kit.base) final _trackHover:ScrollbarTrackStyle = new ScrollbarTrackStyle();

    @:allow(glaze.kit.base) final _trackActive:ScrollbarTrackStyle = new ScrollbarTrackStyle();

    @:allow(glaze.kit.base) final _thumb:ScrollbarThumbStyle = new ScrollbarThumbStyle();

    @:allow(glaze.kit.base) final _thumbHover:ScrollbarThumbStyle = new ScrollbarThumbStyle();

    @:allow(glaze.kit.base) final _thumbActive:ScrollbarThumbStyle = new ScrollbarThumbStyle();

    public function new() {}

    public function track(build:(ScrollbarTrackStyle) -> ScrollbarTrackStyle):ScrollbarStyles {
        build(_track);
        return this;
    }

    public function trackHover(build:(ScrollbarTrackStyle) -> ScrollbarTrackStyle):ScrollbarStyles {
        build(_trackHover);
        return this;
    }

    public function trackActive(build:(ScrollbarTrackStyle) -> ScrollbarTrackStyle):ScrollbarStyles {
        build(_trackActive);
        return this;
    }

    public function thumb(build:(ScrollbarThumbStyle) -> ScrollbarThumbStyle):ScrollbarStyles {
        build(_thumb);
        return this;
    }

    public function thumbHover(build:(ScrollbarThumbStyle) -> ScrollbarThumbStyle):ScrollbarStyles {
        build(_thumbHover);
        return this;
    }

    public function thumbActive(build:(ScrollbarThumbStyle) -> ScrollbarThumbStyle):ScrollbarStyles {
        build(_thumbActive);
        return this;
    }

    /** `FluentBuilder::when`. */
    public function when(condition:Bool, then:(ScrollbarStyles) -> ScrollbarStyles):ScrollbarStyles {
        return condition ? then(this) : this;
    }

    /** The track style (read). */
    public inline function trackStyle():ScrollbarTrackStyle {
        return _track;
    }

    public inline function trackHoverStyle():ScrollbarTrackStyle {
        return _trackHover;
    }

    public inline function trackActiveStyle():ScrollbarTrackStyle {
        return _trackActive;
    }

    public inline function thumbStyle():ScrollbarThumbStyle {
        return _thumb;
    }

    public inline function thumbHoverStyle():ScrollbarThumbStyle {
        return _thumbHover;
    }

    public inline function thumbActiveStyle():ScrollbarThumbStyle {
        return _thumbActive;
    }

}

/**
 * The paint parameters resolved for one state of the scrollbar (Rust
 * returns them as a tuple).
 */
class ScrollbarResolvedStyle {

    public final thumb:Background;

    public final track:Hsla;

    public final border:Hsla;

    public final width:Float;

    public final inset:Float;

    public final radius:Float;

    public final minLength:Float;

    public function new(thumb:Background, track:Hsla, border:Hsla, width:Float, inset:Float, radius:Float, minLength:Float) {
        this.thumb = thumb;
        this.track = track;
        this.border = border;
        this.width = width;
        this.inset = inset;
        this.radius = radius;
        this.minLength = minLength;
    }

}

/**
 * The same longitudinal geometry drives painting, track clicks and dragging.
 * `length` excludes the inset, while `travel` excludes the full logical thumb.
 */
class ThumbGeometry {

    public final origin:Float;

    public final inset:Float;

    public final length:Float;

    public final travel:Float;

    public final extent:Float;

    public function new(origin:Float, trackSize:Float, viewportSize:Float, content:Float, marginEnd:Float, inset:Float, minLength:Float) {
        final track = Math.max(trackSize - marginEnd, 0.);
        final logicalLength = Math.min(Math.max(f32(f32(viewportSize / content) * track), minLength), track);
        // `Pixels::clamp` (max then min)
        final inset = Math.min(Math.max(inset, 0.), f32(logicalLength / 2.));
        this.origin = origin;
        this.inset = inset;
        this.length = f32(logicalLength - f32(inset * 2.));
        this.travel = f32(track - logicalLength);
        this.extent = f32(content - viewportSize);
    }

    public function start(offset:Float):Float {
        var ratio = f32(-offset / extent);
        ratio = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
        return f32(f32(origin + inset) + f32(ratio * travel));
    }

    public function offset(position:Float, grab:Float):Float {
        if (travel <= 0) {
            return 0;
        }
        var ratio = f32(f32(f32(f32(position - origin) - inset) - grab) / travel);
        ratio = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
        return f32(-extent * ratio);
    }

    public function dragOffset(axis:Axis, position:Point, grab:Point, offset:Point):Point {
        if (travel <= 0) {
            return offset;
        }
        if (axis == Vertical) {
            return new Point(offset.x, this.offset(position.y, grab.y));
        }
        return new Point(this.offset(position.x, grab.x), offset.y);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * Prepaint state of one axis (Rust `AxisPrepaintState`).
 */
class AxisPrepaintState {

    public var axis:Axis;
    public var barHitbox:Hitbox;
    public var bounds:Bounds;
    public var radius:Float;
    public var bg:Hsla;
    public var border:Hsla;
    public var thumbBounds:Bounds;
    /** Bounds of thumb to be rendered. */
    public var thumbFillBounds:Bounds;
    public var thumbBg:Background;
    public var geometry:ThumbGeometry;
    public var activeGeometry:ThumbGeometry;
    public var trackWidth:Float;
    public var visibilityOpacity:Float;
    public var visibilityPosition:Float;
    public var visibilityRequested:Bool;

    public function new() {}

}

/**
 * Scrollbar control for scroll-area or a uniform-list.
 *
 * Differences with gpui-kit: times come from `cx.backgroundExecutor().now()`
 * (seconds) instead of `Instant::now()`, so tests can drive them.
 */
class Scrollbar extends Element {

    /** The width of the scrollbar (THUMB_ACTIVE_INSET * 2 + THUMB_ACTIVE_WIDTH) */
    public static inline final WIDTH:Float = 4. * 2. + 8.;

    static inline final MIN_THUMB_SIZE:Float = 48.;

    static inline final THUMB_WIDTH:Float = 6.;

    static inline final THUMB_RADIUS:Float = 0.;

    static inline final THUMB_INSET:Float = 4.;

    static inline final THUMB_ACTIVE_WIDTH:Float = 8.;

    static inline final THUMB_ACTIVE_RADIUS:Float = 0.;

    static inline final THUMB_ACTIVE_INSET:Float = 4.;

    @:allow(glaze.kit.base) var _id:ElementId;

    var _axis:ScrollbarAxis = Both;

    var _mode:Null<ScrollbarMode> = null;

    /** Glaze addition (DEV-023): this scrollbar's appearance, null for the theme's. */
    var _appearance:Null<ScrollbarAppearance> = null;

    @:allow(glaze.kit.base) final scrollHandle:ScrollbarHandle;

    var _scrollSize:Null<Size> = null;

    var _viewportBounds:Null<Bounds> = null;

    // Scroll range may use a smaller viewport than the padded track bounds.
    var _scrollViewportSize:Null<Size> = null;

    var useLayoutBounds:Bool = false;

    /**
     * Maximum frames per second for scrolling by drag. Default is 120 FPS.
     *
     * This is used to limit the update rate of the scrollbar when it is
     * being dragged for some complex interactions for reducing CPU usage.
     */
    var _maxFps:Int = 120;

    @:allow(glaze.kit.base) final _styles:ScrollbarStyles = new ScrollbarStyles();

    /** The prepaint state (Rust `PrepaintState`). */
    var hitbox:Null<Hitbox> = null;

    var scrollbarState:Null<ScrollbarState> = null;

    @:allow(glaze.kit.base) var states:Array<AxisPrepaintState> = [];

    /**
     * Create a new scrollbar.
     *
     * This will have both vertical and horizontal scrollbars.
     */
    public function new(scrollHandle:ScrollbarHandle, ?pos:haxe.PosInfos) {
        _id = ElementId.CodeLocation(pos.fileName, pos.lineNumber);
        this.scrollHandle = scrollHandle;
    }

    /** Create with horizontal scrollbar. */
    public static function horizontal(scrollHandle:ScrollbarHandle, ?pos:haxe.PosInfos):Scrollbar {
        return new Scrollbar(scrollHandle, pos).axis(Horizontal);
    }

    /** Create with vertical scrollbar. */
    public static function vertical(scrollHandle:ScrollbarHandle, ?pos:haxe.PosInfos):Scrollbar {
        return new Scrollbar(scrollHandle, pos).axis(Vertical);
    }

    /**
     * Set a specific element id, default is the call site.
     *
     * NOTE: In most cases, you don't need to set a specific id for scrollbar.
     */
    public function id(id:ElementIdArg):Scrollbar {
        _id = id;
        return this;
    }

    /**
     * Set the scrollbar show mode `ScrollbarMode`.
     *
     * If unset, the current application theme projection is used.
     */
    public function mode(mode:ScrollbarMode):Scrollbar {
        _mode = mode;
        return this;
    }

    /**
     * Set how this scrollbar shows, hides and reacts to hover
     * (`ScrollbarAppearance`: fade, instant or gpui-kit's slide, durations,
     * thumb growth, thumb width and radius). Glaze addition (DEV-023).
     *
     * If unset, the theme's (`Theme.scrollbarAppearance` of the kit) is used.
     */
    public function appearance(appearance:Null<ScrollbarAppearance>):Scrollbar {
        _appearance = appearance;
        return this;
    }

    /**
     * Set a special scroll size of the content area, default is null.
     *
     * Default will sync the `contentSize` from `scrollHandle`.
     */
    public function scrollSize(scrollSize:Size):Scrollbar {
        _scrollSize = scrollSize;
        return this;
    }

    /**
     * Override the viewport bounds that this scrollbar overlays.
     *
     * Most scroll containers should rely on the bounds reported by their
     * scroll handle. Custom-painted viewports, such as the text editor, can
     * use this when their visible bounds differ from the handle's layout
     * bounds.
     */
    public function viewportBounds(bounds:Bounds):Scrollbar {
        _viewportBounds = bounds;
        return this;
    }

    @:allow(glaze.kit.base)
    function scrollViewportSize(size:Size):Scrollbar {
        _scrollViewportSize = size;
        return this;
    }

    /**
     * Use the scrollbar element's layout bounds as its viewport.
     *
     * This is useful for composite widgets whose scrollbar viewport excludes
     * fixed headers or columns and is therefore defined by a positioned
     * overlay container rather than by the underlying scroll handle.
     */
    public function viewportFromLayout():Scrollbar {
        useLayoutBounds = true;
        return this;
    }

    @:allow(glaze.kit.base)
    function resolvedViewportBounds(layoutBounds:Bounds):Bounds {
        if (_viewportBounds != null) {
            return _viewportBounds;
        }
        return useLayoutBounds ? layoutBounds : scrollHandle.viewportBounds();
    }

    /** Set scrollbar axis. */
    public function axis(axis:ScrollbarAxis):Scrollbar {
        _axis = axis;
        return this;
    }

    public function styles(build:(ScrollbarStyles) -> ScrollbarStyles):Scrollbar {
        build(_styles);
        return this;
    }

    /**
     * Set maximum frames per second for scrolling by drag. Default is 120 FPS.
     *
     * Available values: 30..120
     */
    public function maxFps(maxFps:Int):Scrollbar {
        _maxFps = maxFps < 30 ? 30 : (maxFps > 120 ? 120 : maxFps);
        return this;
    }

    /** Get the width of the scrollbar. */
    public static inline function width():Float {
        return WIDTH;
    }

    override public function elementId():Null<ElementId> {
        return _id;
    }

    static function baseTheme(cx:App):BaseTheme {
        return BaseTheme.global(cx);
    }

    function resolveTrack(cx:App, state:ScrollbarTrackStyle, globalState:ScrollbarTrackStyle, defaultBorder:Hsla):{track:Hsla, border:Hsla} {
        final global = baseTheme(cx).scrollbar.styles();
        var background = state._background;
        if (background == null) background = _styles._track._background;
        if (background == null) background = globalState._background;
        if (background == null) background = global._track._background;
        if (background == null) background = transparentBlack();
        var border = state._border;
        if (border == null) border = _styles._track._border;
        if (border == null) border = globalState._border;
        if (border == null) border = global._track._border;
        if (border == null) border = defaultBorder;
        return {track: background, border: border};
    }

    function resolveThumb(cx:App, state:ScrollbarThumbStyle, globalState:ScrollbarThumbStyle, defaults:ScrollbarThumbStyle, appearanceRadius:Null<Float>):ScrollbarThumbStyle {
        final global = baseTheme(cx).scrollbar.styles();
        final result = new ScrollbarThumbStyle();
        result._background = firstOf(state._background, _styles._thumb._background, globalState._background, global._thumb._background, defaults._background);
        result._width = firstOf(state._width, _styles._thumb._width, globalState._width, global._thumb._width, defaults._width);
        result._inset = firstOf(state._inset, _styles._thumb._inset, globalState._inset, global._thumb._inset, defaults._inset);
        // DEV-023: the appearance's radius comes after this scrollbar's own
        // styles and before the theme's (which always sets the theme radius)
        final ownRadius = state._radius != null ? state._radius : _styles._thumb._radius;
        result._radius = ownRadius != null ? ownRadius : firstOf(appearanceRadius, globalState._radius, global._thumb._radius, defaults._radius, null);
        var minLength = firstOf(state._minLength, _styles._thumb._minLength, globalState._minLength, global._thumb._minLength, defaults._minLength);
        result._minLength = minLength != null ? minLength : MIN_THUMB_SIZE;
        return result;
    }

    static function firstOf<T>(a:Null<T>, b:Null<T>, c:Null<T>, d:Null<T>, e:Null<T>):Null<T> {
        return a != null ? a : (b != null ? b : (c != null ? c : (d != null ? d : e)));
    }

    /**
     * The thumb colour a scrollbar falls back to when nothing has overridden
     * it, taken from the active theme rather than fixed: the `foreground`
     * token at the given alpha. An explicit `ScrollbarStyles` still wins:
     * this is the bottom of the cascade, not a new top of it.
     */
    static function thumbDefaultBackground(cx:App, alpha:Float):Background {
        return (baseTheme(cx).tokens.colors.foreground.alpha(alpha) : IntoBackground);
    }

    static function thumbDefaults(background:Background, width:Float, inset:Float, radius:Float):ScrollbarThumbStyle {
        final result = new ScrollbarThumbStyle();
        result._background = background;
        result._width = width;
        result._inset = inset;
        result._radius = radius;
        result._minLength = MIN_THUMB_SIZE;
        return result;
    }

    function resolved(cx:App, track:ScrollbarTrackStyle, globalTrack:ScrollbarTrackStyle, thumb:ScrollbarThumbStyle, globalThumb:ScrollbarThumbStyle, defaults:ScrollbarThumbStyle, appearance:Null<ScrollbarAppearance>):ScrollbarResolvedStyle {
        final trackStyle = resolveTrack(cx, track, globalTrack, transparentBlack());
        final thumbStyle = resolveThumb(cx, thumb, globalThumb, defaults, appearance != null ? appearance.thumbRadius : null);
        return new ScrollbarResolvedStyle(thumbStyle._background, trackStyle.track, trackStyle.border, thumbStyle._width, thumbStyle._inset, thumbStyle._radius, thumbStyle._minLength);
    }

    /**
     * The appearance in effect (DEV-023): this scrollbar's, else the
     * theme's, null for Base alone (gpui-base's behaviour).
     */
    function effectiveAppearance(cx:App):Null<ScrollbarAppearance> {
        return _appearance != null ? _appearance : baseTheme(cx).scrollbar.appearance();
    }

    /** DEV-023: the default resting thumb width, the appearance's when it has one. */
    static function restingThumbWidth(appearance:Null<ScrollbarAppearance>):Float {
        return appearance != null ? appearance.resolvedThumbWidth() : THUMB_WIDTH;
    }

    /** DEV-023: the default hovered and dragged thumb width, the appearance's when it has one. */
    static function activeThumbWidth(appearance:Null<ScrollbarAppearance>):Float {
        return appearance != null ? appearance.resolvedGrownThumbWidth() : THUMB_ACTIVE_WIDTH;
    }

    @:allow(glaze.kit.base)
    function styleForActive(cx:App):ScrollbarResolvedStyle {
        final global = baseTheme(cx).scrollbar.styles();
        final appearance = effectiveAppearance(cx);
        return resolved(cx, _styles._trackActive, global._trackActive, _styles._thumbActive, global._thumbActive,
            thumbDefaults(thumbDefaultBackground(cx, 0.55), activeThumbWidth(appearance), THUMB_ACTIVE_INSET, THUMB_ACTIVE_RADIUS), appearance);
    }

    @:allow(glaze.kit.base)
    function styleForHoveredThumb(cx:App):ScrollbarResolvedStyle {
        final global = baseTheme(cx).scrollbar.styles();
        final appearance = effectiveAppearance(cx);
        return resolved(cx, _styles._trackActive, global._trackActive, _styles._thumbHover, global._thumbHover,
            thumbDefaults(thumbDefaultBackground(cx, 0.55), activeThumbWidth(appearance), THUMB_ACTIVE_INSET, THUMB_ACTIVE_RADIUS), appearance);
    }

    @:allow(glaze.kit.base)
    function styleForHoveredBar(cx:App):ScrollbarResolvedStyle {
        final global = baseTheme(cx).scrollbar.styles();
        final appearance = effectiveAppearance(cx);
        return resolved(cx, _styles._trackHover, global._trackHover, _styles._thumb, global._thumb,
            thumbDefaults(thumbDefaultBackground(cx, 0.35), restingThumbWidth(appearance), THUMB_INSET, THUMB_RADIUS), appearance);
    }

    @:allow(glaze.kit.base)
    function styleForNormal(cx:App):ScrollbarResolvedStyle {
        final global = baseTheme(cx).scrollbar.styles();
        final appearance = effectiveAppearance(cx);
        return resolved(cx, _styles._track, global._track, _styles._thumb, global._thumb,
            thumbDefaults(thumbDefaultBackground(cx, 0.35), restingThumbWidth(appearance), THUMB_INSET, THUMB_RADIUS), appearance);
    }

    @:allow(glaze.kit.base)
    static function clampThumbRadius(radius:Float, bounds:Bounds):Float {
        return Math.min(Math.min(radius, bounds.size.width / 2.), bounds.size.height / 2.);
    }

    @:allow(glaze.kit.base)
    static function visibilityTranslation(axis:Axis, trackWidth:Float, progress:Float):Point {
        final clamped = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
        final offset = f32(trackWidth * f32(1.0 - clamped));
        if (axis == Vertical) {
            return new Point(offset, 0);
        }
        return new Point(0, offset);
    }

    @:allow(glaze.kit.base)
    static function wantsVisible(mode:ScrollbarMode, isHovered:Bool, isDragging:Bool, lastScrollTime:Null<Float>, idle:Float, now:Float):Bool {
        return mode == Always
            || isDragging
            || (mode == Hover && isHovered)
            || (lastScrollTime != null && sinceNanos(now, lastScrollTime) < MotionTime.nanos(idle));
    }

    @:allow(glaze.kit.base)
    static function tracksThumbHover(mode:ScrollbarMode, isVisible:Bool):Bool {
        return mode == Hover || isVisible;
    }

    @:allow(glaze.kit.base)
    static function hoverKeepsVisible(mode:ScrollbarMode, isHovered:Bool, isCurrentlyVisible:Bool):Bool {
        return isHovered && (mode == Hover || (mode == Scrolling && isCurrentlyVisible));
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    /** `now.saturating_duration_since(at)` in whole nanoseconds. */
    static inline function sinceNanos(now:Float, at:Float):Float {
        final elapsed = MotionTime.nanos(now) - MotionTime.nanos(at);
        return elapsed > 0 ? elapsed : 0;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.position = Absolute;
        style.flexGrow = 1.0;
        style.flexShrink = 1.0;
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, layoutBounds:Bounds, window:Window, cx:App):Void {
        final bounds = resolvedViewportBounds(layoutBounds);
        final hitbox = window.withContentMask(new ContentMask(bounds), window -> window.insertHitbox(bounds, Normal));
        this.hitbox = hitbox;

        final now = cx.backgroundExecutor().now();
        final state:ScrollbarState = window.useState(cx, _ -> new ScrollbarState(now)).read(cx).value;
        scrollbarState = state;

        final baseTheme = baseTheme(cx);
        final mode = _mode != null ? _mode : baseTheme.scrollbar.mode();
        final motion = baseTheme.scrollbar.motion();
        // DEV-023: the appearance of this scrollbar or of the theme, when one
        // is set, gives the timing, the choreography and the thumb growth;
        // without one (Base alone), the projected motion does, like gpui-kit
        final appearance = effectiveAppearance(cx);
        final motionEnter = appearance != null ? appearance.resolvedShowDuration() : motion.enter();
        final motionExit = appearance != null ? appearance.resolvedHideDuration() : motion.exit();
        final motionExpand = appearance != null ? appearance.resolvedGrowthDuration() : motion.expand();
        final slideOut = appearance == null || appearance.transition == ScrollbarTransition.GpuiKit;
        final thumbGrowth = appearance == null || appearance.thumbGrowth;
        // Always-visible scrollbars skip visibility motion but still animate
        // their activity width. Reduced motion snaps every channel.
        final reduceMotion = cx.reduceMotion();
        final enter = mode != Always && !reduceMotion ? motionEnter : 0.;
        final exit = mode != Always && !reduceMotion ? motionExit : 0.;
        final expand = reduceMotion ? 0. : motionExpand;

        final inner = state;
        final currentOffset = scrollHandle.offset();
        if (!currentOffset.equals(inner.lastScrollOffset)) {
            inner.withLastScroll(currentOffset, now);
        }

        final isHovered = inner.hoveredAxis != null || inner.hoveredOnThumb != null;
        final isDragging = inner.draggedAxis != null;
        final isCurrentlyVisible = inner.visibility.sample(now).opacity > 0.0;
        final visible = hoverKeepsVisible(mode, isHovered, isCurrentlyVisible)
            || wantsVisible(mode, isHovered, isDragging, inner.lastScrollTime, motion.idle(), now);
        final entrance = appearance == null
            ? motion.entranceFor(mode, inner.hoveredOnThumb != null)
            : (appearance.transition == ScrollbarTransition.GpuiKit && mode == Hover && inner.hoveredOnThumb != null ? SlideAndFade : Fade);
        inner.visibility.setVisible(visible, entrance, enter, exit, now, slideOut);
        final visibility = inner.visibility.sample(now);
        if (visibility.running) {
            window.requestAnimationFrame();
        }

        if (!isHovered && !isDragging) {
            final lastTime = inner.lastScrollTime;
            if (lastTime != null) {
                final elapsed = sinceNanos(now, lastTime);
                if (elapsed < MotionTime.nanos(motion.idle()) && !inner.idleTimerScheduled) {
                    inner.idleTimerScheduled = true;
                    final currentView = window.currentView();
                    final nextDelay = MotionTime.seconds(MotionTime.nanos(motion.idle()) - elapsed);
                    cx.backgroundExecutor().timer(nextDelay).then(_ -> {
                        state.idleTimerScheduled = false;
                        if (!window.isDestroyed()) {
                            cx.update(cx -> cx.notify(currentView));
                        }
                    });
                }
            }
        }

        final states:Array<AxisPrepaintState> = [];
        var hasBoth = _axis.isBoth();
        var scrollSize = _scrollSize != null ? _scrollSize : scrollHandle.contentSize();
        var scrollViewportSize = _scrollViewportSize != null ? _scrollViewportSize : hitbox.bounds.size;
        final handleImpl:ScrollbarHandleImpl = scrollHandle;
        if (Std.isOfType(handleImpl, ScrollbarThumbPadding) && _scrollSize == null && _scrollViewportSize == null) {
            final padding = (cast handleImpl : ScrollbarThumbPadding).thumbVerticalPadding();
            if (padding > 0) {
                scrollSize = new Size(scrollSize.width, Math.max(0, scrollSize.height - padding));
                scrollViewportSize = new Size(scrollViewportSize.width, Math.max(0, scrollViewportSize.height - padding));
            }
        }
        final hitboxBounds = hitbox.bounds;

        for (axis in _axis.all()) {
            final isVertical = axis == Vertical;
            var trackWidth:Null<Float> = _styles._track._width;
            if (trackWidth == null) trackWidth = baseTheme.scrollbar.styles()._track._width;
            if (trackWidth == null) trackWidth = WIDTH;
            final scrollAreaSize = isVertical ? scrollSize.height : scrollSize.width;
            final containerSize = isVertical ? hitboxBounds.size.height : hitboxBounds.size.width;
            final axisViewportSize = isVertical ? scrollViewportSize.height : scrollViewportSize.width;
            final scrollPosition = isVertical ? scrollHandle.offset().y : scrollHandle.offset().x;

            // The horizontal scrollbar is set avoid overlapping with the vertical scrollbar, if the vertical scrollbar is visible.
            final marginEnd = hasBoth && !isVertical ? trackWidth : 0.;

            // Hide scrollbar, if the scroll area is smaller than the container.
            if (scrollAreaSize <= axisViewportSize) {
                hasBoth = false;
                continue;
            }

            final bounds = new Bounds(
                isVertical
                    ? new Point(hitboxBounds.origin.x + hitboxBounds.size.width - trackWidth, hitboxBounds.origin.y)
                    : new Point(hitboxBounds.origin.x, hitboxBounds.origin.y + hitboxBounds.size.height - trackWidth),
                new Size(
                    isVertical ? trackWidth : hitboxBounds.size.width,
                    isVertical ? hitboxBounds.size.height : trackWidth
                )
            );

            final isAlwaysToShow = mode == Always;
            final isHoverToShow = mode == Hover;
            final isHoveredOnBar = state.hoveredAxis == axis;
            final isHoveredOnThumb = state.hoveredOnThumb == axis;

            var normalStyle = false;
            final style = if (state.draggedAxis == axis) {
                styleForActive(cx);
            }
            else if ((isHoverToShow || mode == Scrolling) && (isHoveredOnBar || isHoveredOnThumb)) {
                isHoveredOnThumb ? styleForHoveredThumb(cx) : styleForHoveredBar(cx);
            }
            else if (isAlwaysToShow && (isHoveredOnBar || isHoveredOnThumb)) {
                isHoveredOnThumb ? styleForHoveredThumb(cx) : styleForHoveredBar(cx);
            }
            else {
                normalStyle = true;
                styleForNormal(cx);
            }
            // DEV-023: without thumb growth, the thumb keeps its resting width
            // and inset when hovered or dragged (only its color changes)
            final rest = thumbGrowth || normalStyle ? null : styleForNormal(cx);
            final inset = rest != null ? rest.inset : style.inset;
            final thumbTargetWidth = rest != null ? rest.width : style.width;
            final radius = style.radius;
            final minLength = style.minLength;

            final widthAnimation = isVertical ? state.verticalWidth : state.horizontalWidth;
            final animated = widthAnimation.setTarget(thumbTargetWidth, expand, now);
            final thumbWidth = animated.value;
            if (animated.running) {
                window.requestAnimationFrame();
            }

            final origin = isVertical ? bounds.origin.y : bounds.origin.x;
            final geometry = new ThumbGeometry(origin, containerSize, axisViewportSize, scrollAreaSize, marginEnd, inset, minLength);
            final active = styleForActive(cx);
            final activeInset = thumbGrowth ? active.inset : inset;
            final activeGeometry = new ThumbGeometry(origin, containerSize, axisViewportSize, scrollAreaSize, marginEnd, activeInset, active.minLength);
            final thumbStart = f32(geometry.start(scrollPosition) - origin);

            // The clickable area of the thumb
            final thumbLength = geometry.length;
            final thumbBounds = isVertical
                ? Bounds.fromAnchorAndSize(TopRight, bounds.topRight().add(new Point(-inset, thumbStart)), new Size(trackWidth, thumbLength))
                : Bounds.fromAnchorAndSize(BottomLeft, bounds.bottomLeft().add(new Point(thumbStart, -inset)), new Size(thumbLength, trackWidth));

            // The actual render area of the thumb
            final thumbFillBounds = isVertical
                ? Bounds.fromAnchorAndSize(TopRight, bounds.topRight().add(new Point(-inset, thumbStart)), new Size(thumbWidth, thumbLength))
                : Bounds.fromAnchorAndSize(BottomLeft, bounds.bottomLeft().add(new Point(thumbStart, -inset)), new Size(thumbLength, thumbWidth));

            final barHitbox = window.withContentMask(new ContentMask(bounds), window -> window.insertHitbox(bounds, Normal));

            final axisState = new AxisPrepaintState();
            axisState.axis = axis;
            axisState.barHitbox = barHitbox;
            axisState.bounds = bounds;
            axisState.radius = radius;
            axisState.bg = style.track;
            axisState.border = style.border;
            axisState.thumbBounds = thumbBounds;
            axisState.thumbFillBounds = thumbFillBounds;
            axisState.thumbBg = style.thumb;
            axisState.geometry = geometry;
            axisState.activeGeometry = activeGeometry;
            axisState.trackWidth = trackWidth;
            axisState.visibilityOpacity = visibility.opacity;
            axisState.visibilityPosition = visibility.position;
            axisState.visibilityRequested = visible;
            states.push(axisState);
        }

        this.states = states;
    }

    public function paint(id:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        final scrollbarState = this.scrollbarState;
        final theme = baseTheme(cx);
        final mode = _mode != null ? _mode : theme.scrollbar.mode();
        final viewId = window.currentView();
        final hitboxBounds = hitbox.bounds;
        final isHoverToShow = mode == Hover;
        final scrollHandle = this.scrollHandle;
        final maxFpsDuration = 1. / _maxFps;

        window.withContentMask(new ContentMask(hitboxBounds), window -> {
            for (state in states) {
                final axis = state.axis;
                var radius = state.radius;
                if (theme.tokens.radius.md == 0) {
                    radius = 0.;
                }
                radius = clampThumbRadius(radius, state.thumbFillBounds);
                final thumbBounds = state.thumbBounds;
                final geometry = state.geometry;
                final activeGeometry = state.activeGeometry;
                final isVertical = axis == Vertical;
                final visibilityOpacity = state.visibilityOpacity;
                final isVisible = state.visibilityRequested || visibilityOpacity > 0.0;
                final translation = visibilityTranslation(axis, state.trackWidth, state.visibilityPosition);
                final paintedBounds = state.bounds.add(translation);
                final paintedThumbBounds = state.thumbFillBounds.add(translation);
                final paintedTrackBg = state.bg.opacity(visibilityOpacity);
                final paintedBorder = state.border.opacity(visibilityOpacity);
                final paintedThumbBg = state.thumbBg.opacity(visibilityOpacity);

                window.setCursorStyle(Arrow, state.barHitbox);

                window.paintLayer(hitboxBounds, window -> {
                    window.paintQuad(fill(paintedBounds, paintedTrackBg));

                    window.paintQuad(quad(paintedBounds, Corners.all(0.), transparentBlack(), new Edges(0., 0., 0., 0.), paintedBorder, Solid));

                    window.paintQuad(fill(paintedThumbBounds, paintedThumbBg).withCornerRadii(Corners.all(radius)));
                    return null;
                });

                window.onMouseEvent(Scroll, (event, phase, _, cx) -> {
                    final event:ScrollEvent = cast event;
                    if (phase == Bubble && hitboxBounds.contains(event.position)) {
                        if (!scrollHandle.offset().equals(scrollbarState.lastScrollOffset)) {
                            scrollbarState.withLastScroll(scrollHandle.offset(), cx.backgroundExecutor().now());
                            cx.notify(viewId);
                        }
                    }
                });

                // A thumb follows the finger, unlike content panning. Claim
                // this touch before the window turns it into wheel deltas.
                window.onMouseEvent(TouchDrag, (event, phase, window, cx) -> {
                    final event:glaze.TouchDragEvent = cast event;
                    if (!phase.bubble()) {
                        return;
                    }
                    if (event.phase == Started) {
                        if (!isVisible || window.defaultPrevented() || !thumbBounds.contains(event.startPosition)) {
                            return;
                        }
                        scrollHandle.startDrag();
                        scrollbarState.withDragPos(axis, event.startPosition.sub(thumbBounds.origin), cx.backgroundExecutor().now());
                    }
                    else if (scrollbarState.draggedAxis != axis) {
                        return;
                    }
                    if (event.phase != Cancelled) {
                        scrollHandle.setOffset(activeGeometry.dragOffset(axis, event.position, scrollbarState.dragPos, scrollHandle.offset()));
                    }
                    if (event.phase == Ended || event.phase == Cancelled) {
                        scrollHandle.endDrag();
                        scrollbarState.withUnsetDragPos(cx.backgroundExecutor().now());
                    }
                    window.preventDefault();
                    cx.stopPropagation();
                    if (event.phase == Moved) {
                        scrollbarState.notifyDrag(cx.backgroundExecutor().now(), maxFpsDuration, viewId, window, cx);
                    }
                    else {
                        cx.notify(viewId);
                    }
                });

                if (isVisible) {
                    // The hitbox rather than the bounds, so that an element
                    // above the bar (a menu, a dialog) keeps the press.
                    final barHitbox = state.barHitbox;
                    window.onMouseEvent(MouseDown, (event, phase, window, cx) -> {
                        final event:MouseDownEvent = cast event;
                        if (phase == Bubble && barHitbox.isHovered(window)) {
                            cx.stopPropagation();

                            if (thumbBounds.contains(event.position)) {
                                // click on the thumb bar, set the drag position
                                final pos = event.position.sub(thumbBounds.origin);

                                scrollHandle.startDrag();
                                scrollbarState.withDragPos(axis, pos, cx.backgroundExecutor().now());
                                // Active styling can change the inset or minimum length.
                                // Keep the original grab point under the pointer on that frame.
                                scrollHandle.setOffset(activeGeometry.dragOffset(axis, event.position, pos, scrollHandle.offset()));
                            }
                            else {
                                // click on the scrollbar, jump to the position
                                // Set the thumb bar center to the click position
                                final center = new Point(geometry.length / 2., geometry.length / 2.);
                                scrollHandle.setOffset(geometry.dragOffset(axis, event.position, center, scrollHandle.offset()));
                            }

                            cx.notify(viewId);
                        }
                    });
                }

                final barHitbox = state.barHitbox;
                window.onMouseEvent(MouseMove, (event, _, window, cx) -> {
                    final event:MouseMoveEvent = cast event;
                    final now = cx.backgroundExecutor().now();
                    var notify = false;
                    // When is hover to show mode or it was visible,
                    // we need to update the hovered state and increase the last_scroll_time.
                    final needHoverToUpdate = isHoverToShow || isVisible;
                    // Update hovered state for scrollbar
                    final barHovered = barHitbox.isHovered(window);
                    if (barHovered && needHoverToUpdate) {
                        final hoverChanged = scrollbarState.hoveredAxis != axis;
                        scrollbarState.withHovered(axis, now);
                        notify = notify || hoverChanged;
                    }
                    else if (scrollbarState.hoveredAxis == axis) {
                        scrollbarState.withHovered(null, now);
                        notify = true;
                    }

                    // Update hovered state for scrollbar thumb
                    if (tracksThumbHover(mode, isVisible) && barHovered && thumbBounds.contains(event.position)) {
                        if (scrollbarState.hoveredOnThumb != axis) {
                            scrollbarState.withHoveredOnThumb(axis, now);
                            notify = true;
                        }
                    }
                    else {
                        if (scrollbarState.hoveredOnThumb == axis) {
                            scrollbarState.withHoveredOnThumb(null, now);
                            notify = true;
                        }
                    }

                    // Move thumb position on dragging
                    if (scrollbarState.draggedAxis == axis && event.pressedButton == Left) {
                        // Stop the event propagation to avoid selecting text or other side effects.
                        cx.stopPropagation();

                        final offset = activeGeometry.dragOffset(axis, event.position, scrollbarState.dragPos, scrollHandle.offset());
                        if (!scrollHandle.offset().equals(offset)) {
                            // Coalesce rendering, never discard the newest pointer position.
                            scrollHandle.setOffset(offset);
                            notify = true;
                        }
                        if (notify) {
                            scrollbarState.notifyDrag(now, maxFpsDuration, viewId, window, cx);
                        }
                        return;
                    }

                    if (notify) {
                        cx.notify(viewId);
                    }
                });

                window.onMouseEvent(MouseUp, (event, phase, _, cx) -> {
                    final event:MouseUpEvent = cast event;
                    if (phase == Bubble && scrollbarState.draggedAxis == axis) {
                        scrollHandle.setOffset(activeGeometry.dragOffset(axis, event.position, scrollbarState.dragPos, scrollHandle.offset()));
                        scrollHandle.endDrag();
                        scrollbarState.withUnsetDragPos(cx.backgroundExecutor().now());
                        cx.notify(viewId);
                    }
                });
            }
            return null;
        });
    }

}
