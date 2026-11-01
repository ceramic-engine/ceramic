// Ported from gpui-kit 0.8.1: crates/base/src/toast.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.Anchor;
import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.ClickEvent;
import gpui.Div;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.MouseMoveEvent;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.Point;
import gpui.RenderOnce;
import gpui.Size;
import gpui.SpringMath.f32;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.motion.Motion;
import gpui.base.motion.MotionTime;
import gpui.base.motion.Spring;
import gpui.base.motion.TransitionId;

import gpui.Prelude.*;

using gpui.base.ElementExt;
using gpui.base.Observe;
using gpui.base.StyledExt;

/**
 * Motion tokens used by an unstyled toast stack.
 *
 * Durations are `Float` seconds (Rust `Duration`).
 */
class ToastMotion {

    /**
     * Time scale of the stack's motion.
     *
     * This is read as two different quantities, because the stack sequences
     * one thing and interpolates another. `ToastManager` treats it as a
     * deadline: a toast is present once it has elapsed. The layout treats it
     * as a spring response, which is the scale the reflow is felt at rather
     * than the moment it stops.
     */
    public var duration:Float;

    /** Duration before an ending toast is unmounted. */
    public var exitDuration:Float;

    /** Visible distance between collapsed toast layers. */
    public var collapsedPeek:Pixels;

    /** Distance between expanded toast items. */
    public var expandedGap:Pixels;

    /** Fractional width reduction for each collapsed layer. */
    public var collapsedScaleStep:Float;

    /** Number of layers visible while the stack is collapsed. */
    public var collapsedVisible:Int;

    public function new(duration:Float, exitDuration:Float, collapsedPeek:Pixels, expandedGap:Pixels, collapsedScaleStep:Float, collapsedVisible:Int) {
        this.duration = duration;
        this.exitDuration = exitDuration;
        this.collapsedPeek = collapsedPeek;
        this.expandedGap = expandedGap;
        this.collapsedScaleStep = collapsedScaleStep;
        this.collapsedVisible = collapsedVisible;
    }

    /**
     * Create motion matching the shadcn/Sonner toaster (also Rust's `Default`).
     */
    public static function sonner():ToastMotion {
        return new ToastMotion(0.4, 0.2, gpui.Prelude.px(14.), gpui.Prelude.px(14.), f32(0.05), 3);
    }

}

/**
 * Persistent private layout state used by `ToastStack` (Rust shares its
 * cells through `Rc`: here the state object itself is shared).
 */
class ToastStackState {

    /** Measured item heights, keyed by item element id. */
    @:allow(gpui.base, tests)
    final heights:Map<String, Pixels> = new Map();

    @:allow(gpui.base, tests)
    var width:Pixels = 0.;

    @:allow(gpui.base, tests)
    var hovered:Bool = false;

    @:allow(gpui.base, tests)
    var focused:Bool = false;

    public function new() {}

    /**
     * Return whether interaction has expanded the stack.
     */
    public inline function isExpanded():Bool {
        return hovered || focused;
    }

}

/**
 * Options applied when a toast enters a `ToastManager`.
 */
class ToastOptions {

    /** Active time before automatic dismissal, in seconds; null disables auto-hide. */
    public var timeout:Null<Float>;

    public function new(?timeout:Float) {
        this.timeout = timeout;
    }

}

/**
 * The lifecycle phase exposed by a toast root to application-owned presentation.
 */
enum abstract ToastTransitionStatus(Int) {
    /** The toast has just been added and may run its enter transition (the default). */
    var Starting = 0;
    /** The toast is fully present. */
    var Present = 1;
    /** The toast is closing and remains mounted until its exit transition completes. */
    var Ending = 2;

    public function toString():String {
        return switch (cast this : ToastTransitionStatus) {
            case Starting: 'Starting';
            case Present: 'Present';
            case Ending: 'Ending';
        }
    }
}

/**
 * A mounted toast. Times are whole nanoseconds (see `MotionTime`).
 */
private class ManagedToast<I, T> {

    public final id:I;

    public final value:T;

    public var status:ToastTransitionStatus;

    public var timeoutRemaining:Null<Float>;

    public var transitionElapsed:Float;

    public var lastAdvance:Float;

    public function new(id:I, value:T, status:ToastTransitionStatus, timeoutRemaining:Null<Float>, transitionElapsed:Float, lastAdvance:Float) {
        this.id = id;
        this.value = value;
        this.status = status;
        this.timeoutRemaining = timeoutRemaining;
        this.transitionElapsed = transitionElapsed;
        this.lastAdvance = lastAdvance;
    }

}

/**
 * One mounted toast as iterated: its id, value and phase.
 */
class ToastEntry<I, T> {

    public final id:I;

    public final value:T;

    public final status:ToastTransitionStatus;

    public inline function new(id:I, value:T, status:ToastTransitionStatus) {
        this.id = id;
        this.value = value;
        this.status = status;
    }

}

/**
 * Changes produced when a toast manager advances its lifecycle clock.
 */
class ToastAdvance<I, T> {

    /** Whether a mounted toast changed phase or membership. */
    public var changed:Bool = false;

    /** Toast ids whose entry transition completed. */
    public final presented:Array<I> = [];

    /** Toast ids that entered their ending transition. */
    public final ending:Array<I> = [];

    /** Toast ids and values removed after their ending transition completed. */
    public final removed:Array<{id:I, value:T}> = [];

    public function new() {}

}

/**
 * Ordered toast storage, lifecycle, auto-hide, limits, and exit coordination.
 *
 * Instants and durations are `Float` seconds: instants come from
 * `cx.backgroundExecutor().now()` (Rust `Instant`; GPUI's executor clock,
 * so tests and the reference harness drive it with the test clock). They are
 * converted to whole nanoseconds before any arithmetic, like Rust's
 * `Duration`. Ids are compared with `==`, or `Type.enumEq` for enum values.
 */
class ToastManager<I, T> {

    final entries:Array<ManagedToast<I, T>> = [];

    final transitionDuration:Float;

    final exitDuration:Float;

    /**
     * Create a manager using the supplied motion duration for enter and exit.
     */
    public function new(motion:ToastMotion) {
        transitionDuration = MotionTime.nanos(motion.duration);
        exitDuration = MotionTime.nanos(motion.exitDuration);
    }

    static function idEquals<I>(a:I, b:I):Bool {
        if (Reflect.isEnumValue(a) && Reflect.isEnumValue(b)) {
            return Type.enumEq(cast a, cast b);
        }
        return a == b;
    }

    /**
     * Return the number of mounted toasts, including ending toasts.
     */
    public inline function len():Int {
        return entries.length;
    }

    /**
     * Return whether no toast is mounted.
     */
    public inline function isEmpty():Bool {
        return entries.length == 0;
    }

    /**
     * The mounted toast ids, values, and phases in display order.
     */
    public function iter():Array<ToastEntry<I, T>> {
        return [for (entry in entries) new ToastEntry(entry.id, entry.value, entry.status)];
    }

    /**
     * The newest visible active toasts plus ending toasts.
     */
    public function visible(limit:Int):Array<ToastEntry<I, T>> {
        var activeCount = 0;
        for (entry in entries) {
            if (entry.status != Ending) activeCount++;
        }
        final first = activeCount - limit > 0 ? activeCount - limit : 0;
        var activeIndex = 0;
        final result = [];
        for (entry in entries) {
            final visible = if (entry.status == Ending) {
                true;
            }
            else {
                final keep = activeIndex >= first;
                activeIndex++;
                keep;
            }
            if (visible) result.push(new ToastEntry(entry.id, entry.value, entry.status));
        }
        return result;
    }

    /**
     * Return a mounted toast value by id.
     */
    public function get(id:I):Null<T> {
        for (entry in entries) {
            if (idEquals(entry.id, id)) return entry.value;
        }
        return null;
    }

    /**
     * Add a newest toast, replacing an existing toast with the same id.
     * Returns the replaced value, if any.
     */
    public function push(id:I, value:T, options:ToastOptions, now:Float):Null<T> {
        var replaced:Null<T> = null;
        for (index in 0...entries.length) {
            if (idEquals(entries[index].id, id)) {
                replaced = entries[index].value;
                entries.splice(index, 1);
                break;
            }
        }
        entries.push(new ManagedToast(id, value, Starting, options.timeout != null ? MotionTime.nanos(options.timeout) : null, 0, MotionTime.nanos(now)));
        return replaced;
    }

    /**
     * Begin a toast's exit transition, returning whether its state changed.
     */
    public function dismiss(id:I, now:Float):Bool {
        var entry:Null<ManagedToast<I, T>> = null;
        for (candidate in entries) {
            if (idEquals(candidate.id, id)) {
                entry = candidate;
                break;
            }
        }
        if (entry == null) {
            return false;
        }
        if (entry.status == Ending) {
            return false;
        }
        entry.status = Ending;
        entry.transitionElapsed = 0;
        entry.lastAdvance = MotionTime.nanos(now);
        return true;
    }

    /**
     * Begin the exit transition for every active toast.
     */
    public function dismissAll(now:Float):Array<I> {
        final changed = [];
        for (entry in entries) {
            if (entry.status != Ending) {
                entry.status = Ending;
                entry.transitionElapsed = 0;
                entry.lastAdvance = MotionTime.nanos(now);
                changed.push(entry.id);
            }
        }
        return changed;
    }

    /**
     * Advance lifecycle time; active timers pause while `paused` is true.
     */
    public function advance(now:Float, paused:Bool):ToastAdvance<I, T> {
        final now = MotionTime.nanos(now);
        final result = new ToastAdvance<I, T>();
        for (entry in entries) {
            // Rust `saturating_duration_since`
            final delta = now - entry.lastAdvance > 0 ? now - entry.lastAdvance : 0.0;
            entry.lastAdvance = now;
            switch entry.status {
                case Starting:
                    entry.transitionElapsed += delta;
                    if (entry.transitionElapsed >= transitionDuration) {
                        entry.status = Present;
                        entry.transitionElapsed = 0;
                        result.presented.push(entry.id);
                        result.changed = true;
                    }
                case Present if (!paused):
                    if (entry.timeoutRemaining != null) {
                        final remaining = entry.timeoutRemaining - delta > 0 ? entry.timeoutRemaining - delta : 0.0;
                        entry.timeoutRemaining = remaining;
                        if (remaining == 0) {
                            entry.status = Ending;
                            entry.transitionElapsed = 0;
                            result.ending.push(entry.id);
                            result.changed = true;
                        }
                    }
                case Ending:
                    entry.transitionElapsed += delta;
                case Present:
            }
        }
        var index = 0;
        while (index < entries.length) {
            if (entries[index].status == Ending && entries[index].transitionElapsed >= exitDuration) {
                final entry = entries.splice(index, 1)[0];
                result.removed.push({id: entry.id, value: entry.value});
                result.changed = true;
            }
            else {
                index++;
            }
        }
        return result;
    }

}

/**
 * The geometry of a toast stack (Rust `stack_geometry`): the collapsed and
 * expanded heights, and each item's (collapsed, expanded) offset.
 */
class ToastStackGeometry {

    public final collapsedHeight:Pixels;

    public final expandedHeight:Pixels;

    public final offsets:Array<{collapsed:Pixels, expanded:Pixels}>;

    function new(collapsedHeight:Pixels, expandedHeight:Pixels, offsets:Array<{collapsed:Pixels, expanded:Pixels}>) {
        this.collapsedHeight = collapsedHeight;
        this.expandedHeight = expandedHeight;
        this.offsets = offsets;
    }

    @:allow(gpui.base, tests)
    static function compute(heights:Array<Pixels>, gap:Pixels, peek:Pixels, anchoredBottom:Bool):ToastStackGeometry {
        final count = heights.length;
        final gaps = count > 0 ? count - 1 : 0;
        var expandedHeight:Float = 0.;
        for (height in heights) expandedHeight = f32(expandedHeight + height);
        expandedHeight = f32(expandedHeight + f32(gap * gaps));
        final frontHeight:Float = count > 0 ? heights[count - 1] : 0.;
        var collapsedHeight:Float = f32(frontHeight + f32(peek * gaps));
        for (index in 0...count) {
            final rank = count - 1 - index;
            collapsedHeight = Math.max(collapsedHeight, f32(heights[index] + f32(peek * rank)));
        }
        final offsets = [];
        for (index in 0...count) {
            final height:Float = heights[index];
            final rank = count - 1 - index;
            var newerHeight:Float = 0.;
            for (newer in (index + 1)...count) newerHeight = f32(newerHeight + heights[newer]);
            final expanded = anchoredBottom
                ? f32(f32(f32(expandedHeight - newerHeight) - f32(gap * rank)) - height)
                : f32(newerHeight + f32(gap * rank));
            final collapsed = anchoredBottom
                ? f32(f32(collapsedHeight - height) - f32(peek * rank))
                : f32(peek * rank);
            offsets.push({collapsed: (collapsed : Pixels), expanded: (expanded : Pixels)});
        }
        return new ToastStackGeometry(collapsedHeight, expandedHeight, offsets);
    }

}

/**
 * A deep toast-stack element that owns measurement, overlap, and expansion motion.
 *
 * Interactive methods (Rust `InteractiveElement` by delegation) go to
 * `base`, the stateful `Div` the stack renders.
 */
class ToastStack implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    /** The stateful element the stack renders. */
    public final base:Div;

    final stackStyle:StyleRefinement = new StyleRefinement();

    final state:ToastStackState;

    var motionValue:ToastMotion;

    var placementValue:Anchor = Anchor.TopRight;

    var focusHandleValue:Null<FocusHandle> = null;

    final items:Array<{id:ElementId, child:AnyElement}> = [];

    /**
     * Create a toast stack with Base UI-compatible motion.
     */
    public function new(id:ElementIdArg, state:ToastStackState) {
        this.id = id;
        this.base = div().id(id).testSupport();
        this.state = state;
        this.motionValue = ToastMotion.sonner();
    }

    public inline function style():StyleRefinement {
        return stackStyle;
    }

    public function extend(children:Array<AnyElement>):Void {
        for (child in children) {
            items.push({id: ElementId.NamedInteger('toast-stack-child', items.length), child: child});
        }
    }

    /**
     * Add a stably keyed toast item to the stack.
     */
    public function item(id:ElementIdArg, child:IntoElement):ToastStack {
        items.push({id: id, child: child});
        return this;
    }

    /**
     * Set the stack motion tokens.
     */
    public function motion(motion:ToastMotion):ToastStack {
        motionValue = motion;
        return this;
    }

    /**
     * Set the viewport edge used to anchor stack geometry.
     */
    public function placement(placement:Anchor):ToastStack {
        placementValue = placement;
        return this;
    }

    /**
     * Set the focus scope that expands the stack and pauses auto-hide timers.
     */
    public function focusHandle(focusHandle:FocusHandle):ToastStack {
        focusHandleValue = focusHandle;
        return this;
    }

    public function trackFocus(handle:FocusHandle):ToastStack {
        base.trackFocus(handle);
        return this;
    }

    static function key(id:ElementId):String {
        return Std.string(id);
    }

    public function render(window:Window, cx:App):IntoElement {
        final focused = focusHandleValue != null && focusHandleValue.containsFocused(window, cx);
        state.focused = focused;
        final expanded = state.isExpanded();
        final keys = [for (item in items) key(item.id)];
        for (id in [for (k in state.heights.keys()) k]) {
            if (keys.indexOf(id) == -1) state.heights.remove(id);
        }
        final heights:Array<Pixels> = [for (id in keys) state.heights.exists(id) ? state.heights.get(id) : gpui.Prelude.px(0.)];
        final measured = state.heights;
        final peek = motionValue.collapsedPeek;
        final gap = motionValue.expandedGap;
        final scaleStep = motionValue.collapsedScaleStep;
        final collapsedVisible = motionValue.collapsedVisible > 1 ? motionValue.collapsedVisible : 1;
        final stackWidth = state.width;
        final count = items.length;
        final anchoredBottom = switch placementValue {
            case BottomLeft | BottomCenter | BottomRight: true;
            case _: false;
        };
        final geometryResult = ToastStackGeometry.compute(heights.slice(0, count < heights.length ? count : heights.length), gap, peek, anchoredBottom);
        final collapsedHeight = geometryResult.collapsedHeight;
        final expandedHeight = geometryResult.expandedHeight;
        final offsets = geometryResult.offsets;
        // The whole stack reflows every time a toast arrives or leaves, so each
        // layer is sprung: one retargeted mid-move carries its velocity into the
        // new layout instead of restarting. Critically damped, because a height
        // or an opacity that overshoots its target reads as a glitch. Geometry
        // settles in pixels, so its tolerance is coarser than the fade's.
        final geometry = new Spring(motionValue.duration).withEpsilon(0.1);
        final fade = new Spring(motionValue.duration);
        final stackHeight:Pixels = Motion.spring(TransitionId.named(id, 'height'), expanded ? expandedHeight : collapsedHeight, geometry, window, cx);
        final rendered:Array<IntoElement> = [];
        for (index in 0...items.length) {
            final itemId = items[index].id;
            final child = items[index].child;
            final offsetPair = index < offsets.length ? offsets[index] : {collapsed: gpui.Prelude.px(0.), expanded: gpui.Prelude.px(0.)};
            final measuredId = key(itemId);
            final rank = count - (1 + index) > 0 ? count - (1 + index) : 0;
            final targetOffset = expanded ? offsetPair.expanded : offsetPair.collapsed;
            final offset:Pixels = Motion.spring(TransitionId.named(itemId, 'offset'), targetOffset, geometry, window, cx);
            final layer = rank < collapsedVisible - 1 ? rank : collapsedVisible - 1;
            final targetInset:Pixels = expanded ? gpui.Prelude.px(0.) : f32(stackWidth * f32(f32(scaleStep * layer) / 2.));
            final inset:Pixels = Motion.spring(TransitionId.named(itemId, 'inset'), targetInset, geometry, window, cx);
            final opacity = Motion.spring(TransitionId.named(itemId, 'visibility'), expanded || rank < collapsedVisible ? 1. : 0., fade, window, cx);
            final element = div()
                .id(itemId)
                .absolute()
                .top0()
                .left0()
                .right0()
                .top(offset)
                .left(inset)
                .right(inset)
                .opacity(opacity)
                .when(!expanded && rank >= collapsedVisible, d -> d.invisible())
                .onPrepaint((bounds, _, cx) -> {
                    if (!measured.exists(measuredId) || measured.get(measuredId) != bounds.size.height) {
                        measured.set(measuredId, bounds.size.height);
                        cx.refreshWindows();
                    }
                })
                .child(child);
            rendered.push(element);
        }

        final state = this.state;
        final element = base
            .relative()
            .h(stackHeight);
        if (focusHandleValue != null) {
            element.trackFocus(focusHandleValue);
        }
        return element
            .child(canvas((_, _, _) -> null, (bounds:Bounds, _, window, cx) -> {
                if (state.width != bounds.size.width) {
                    state.width = bounds.size.width;
                    cx.refreshWindows();
                }
                var hitBounds = bounds;
                if (!expanded) {
                    final y = anchoredBottom ? bounds.origin.y + (stackHeight - collapsedHeight) : bounds.origin.y;
                    hitBounds = new Bounds(new Point(bounds.origin.x, y), new Size(bounds.size.width, collapsedHeight));
                }
                window.onMouseEvent(MouseMove, (event, _, _, cx) -> {
                    final event:MouseMoveEvent = cast event;
                    final hovered = hitBounds.contains(event.position);
                    if (state.hovered != hovered) {
                        state.hovered = hovered;
                        cx.refreshWindows();
                    }
                });
            })
                .absolute()
                .sizeFull())
            .children(rendered)
            .refineStyle(stackStyle);
    }

}

/**
 * An unstyled semantic toast root. Applications own all presentation and motion.
 *
 * Interactive methods (Rust `InteractiveElement` by delegation) go to
 * `base`. The port has no accessibility tree: the role is kept in `a11y`.
 */
class Toast implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the toast renders. */
    public final base:Div;

    final toastStyle:StyleRefinement = new StyleRefinement();

    var transitionStatusValue:ToastTransitionStatus = Starting;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the toast exports. */
    public final a11y:A11y = new A11y(Role.Alert);

    /**
     * Create an unstyled semantic toast in the starting transition phase.
     */
    public function new(id:ElementIdArg) {
        this.base = div().id(id).testSupport();
    }

    public inline function style():StyleRefinement {
        return toastStyle;
    }

    public function extend(children:Array<AnyElement>):Void {
        for (child in children) childElements.push(child);
    }

    public function child(child:IntoElement):Toast {
        childElements.push(child);
        return this;
    }

    /**
     * Set the lifecycle phase used by application-owned toast presentation.
     */
    public function transitionStatus(status:ToastTransitionStatus):Toast {
        transitionStatusValue = status;
        return this;
    }

    /**
     * Return the lifecycle phase used by application-owned toast presentation.
     */
    public inline function status():ToastTransitionStatus {
        return transitionStatusValue;
    }

    /** Assigns the group of `base`. */
    public function group(group:String):Toast {
        base.group(group);
        return this;
    }

    /** Occludes the hitboxes below `base`. */
    public function occlude():Toast {
        base.occlude();
        return this;
    }

    public function trackFocus(handle:FocusHandle):Toast {
        base.trackFocus(handle);
        return this;
    }

    public function onClick(listener:(ClickEvent, Window, App) -> Void):Toast {
        base.onClick(listener);
        return this;
    }

    public function onAuxClick(listener:(ClickEvent, Window, App) -> Void):Toast {
        base.onAuxClick(listener);
        return this;
    }

    /**
     * The element this toast renders (Rust `render`), so a caller can
     * animate it like Rust animates the toast itself: the toast's style is
     * refined last in both, so refining the rendered `Div` is the same.
     */
    public function intoDiv():Div {
        // Rust `.role(Role::Alert)`: no accessibility tree in the port (see `a11y`).
        base.extend(childElements);
        return base.refineStyle(toastStyle);
    }

    public function render(_:Window, _:App):IntoElement {
        return intoDiv();
    }

}
