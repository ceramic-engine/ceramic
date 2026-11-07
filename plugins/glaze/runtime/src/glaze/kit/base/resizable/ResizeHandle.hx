// Ported from gpui-kit 0.8.1: crates/base/src/resizable/resize_handle.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.resizable;

import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.Axis;
import glaze.Bounds;
import glaze.Div;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.GlobalElementId;
import glaze.Hitbox;
import glaze.HitboxBehavior;
import glaze.Hsla;
import glaze.LayoutId;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Pixels;
import glaze.Point;
import glaze.Window;

import glaze.Prelude.*;

using glaze.kit.base.Geometry.AxisExt;
using glaze.kit.base.Observe;

/**
 * Draws the visible part of a resize handle.
 *
 * Returning `null` keeps the built-in line, so a renderer can override some
 * handles and leave the rest alone.
 */
typedef ResizeHandleRenderer = (ResizeHandleContext, Window, App) -> Null<AnyElement>;

/**
 * What a `ResizeHandleRenderer` is told about the handle it is drawing.
 *
 * The hit area, the cursor and the drag itself stay with the handle; a
 * renderer only supplies what is painted inside it.
 */
class ResizeHandleContext {

    final axisValue:Axis;

    final edgeValue:Null<HandleEdge>;

    final stateValue:ResizeHandleState;

    @:allow(glaze.kit.base.resizable, tests)
    function new(axis:Axis, edge:Null<HandleEdge>, state:ResizeHandleState) {
        this.axisValue = axis;
        this.edgeValue = edge;
        this.stateValue = state;
    }

    /**
     * The axis the handle resizes along: `Horizontal` for a vertical divider
     * between two side-by-side panels.
     */
    public function axis():Axis {
        return axisValue;
    }

    /**
     * The edge of its container this handle hugs, or `null` for a handle
     * straddling the boundary it resizes.
     */
    public function edge():Null<HandleEdge> {
        return edgeValue;
    }

    /**
     * Whether the pointer currently owns this handle.
     */
    public function isActive():Bool {
        return stateValue.isActive();
    }

    /**
     * How far the pointer has gone with this handle.
     */
    public function state():ResizeHandleState {
        return stateValue;
    }

}

/**
 * How far the pointer has gone with a resize handle.
 *
 * A drag takes the pointer out of the handle's own band within a pixel or
 * two, so GPUI's hover reads false for most of a drag and cannot stand in for
 * `Dragging`. Base tracks the progression instead, and a renderer reads it
 * through `ResizeHandleContext.state()`.
 */
enum abstract ResizeHandleState(Int) {

    /** The pointer is somewhere else. */
    var Idle;

    /** The pointer is over the handle's band. */
    var Hovered;

    /** The pointer went down on the handle and has not moved since. */
    var Pressed;

    /** The handle is being dragged. */
    var Dragging;

    /**
     * Whether the pointer owns the handle: pressed on it, or dragging it.
     */
    public inline function isActive():Bool {
        return (cast this : ResizeHandleState) == Pressed || (cast this : ResizeHandleState) == Dragging;
    }

}

/**
 * Which edge of its own container a handle hugs.
 *
 * A handle named no edge straddles the boundary it resizes, half its band on
 * either side, which is what a divider between two panels of a group wants.
 * Naming the edge moves the whole band inside the container; the hairline
 * stays on the boundary itself.
 */
enum abstract HandleEdge(Int) {

    /**
     * Where the axis starts: the left edge of a horizontal handle's
     * container, the top edge of a vertical one's.
     */
    var Leading;

    /** Where the axis ends. */
    var Trailing;

}

/**
 * One handle's `ResizeHandleState`, shared between the element and the
 * mouse listeners it registers (Rust `Rc<Cell<ResizeHandleState>>`).
 */
@:allow(glaze.kit.base.resizable, tests)
class SharedHandleState {

    var state:ResizeHandleState = Idle;

    public function new() {}

    function get():ResizeHandleState {
        return state;
    }

    /**
     * Reports whether the state actually changed, so a listener repaints the
     * window only when there is something new to paint.
     */
    function set(state:ResizeHandleState):Bool {
        final changed = this.state != state;
        this.state = state;
        return changed;
    }

}

/**
 * A band that resizes along one axis when it is dragged, carrying a `T` that
 * the drag renders as a view. See `ResizeHandle.resizeHandle`.
 *
 * Base owns the band: where it sits, how wide it is, its cursor, and the
 * Idle, Hovered, Pressed, Dragging progression its appearance is told about.
 * What a drag resizes is the caller's. Give the handle a payload with
 * `onDrag` and follow that payload with `onDragMove`; any other listener
 * goes on `base` (the band itself, Rust `InteractiveElement`).
 *
 * The band's element id, its `"handle"` group, its occlusion and its drag are
 * base's: an id, group, hitbox behavior or drag set on `base` is replaced
 * when the band is laid out.
 */
class ResizeHandle<T> extends Element {

    /** Size of the padding around the hairline. */
    public static inline final HANDLE_PADDING:Pixels = 4.;

    /** Thickness of the hairline. */
    public static inline final HANDLE_SIZE:Pixels = 1.;

    /**
     * Create a resize handle: a band that resizes whatever it edges when it
     * is dragged.
     */
    public static function resizeHandle<T>(id:ElementIdArg, axis:Axis):ResizeHandle<T> {
        return new ResizeHandle<T>(id, axis);
    }

    final id:ElementId;

    final axis:Axis;

    var edge:Null<HandleEdge> = null;

    var dragValue:Null<T> = null;

    var dragConstructor:Null<(T, Point, Window, App) -> AnyView> = null;

    var appearance:Null<ResizeHandleRenderer> = null;

    /**
     * The band itself. Listeners a caller attaches land here, on the element
     * the pointer actually hits; base places and sizes it when it is laid out.
     */
    public var base(default, null):Div;

    var child:Null<AnyElement> = null;

    var hitbox:Null<Hitbox> = null;

    function new(id:ElementIdArg, axis:Axis) {
        this.id = id;
        this.axis = axis;
        this.base = div();
    }

    /**
     * Hand the painted part of this handle to `appearance`.
     */
    public function withAppearance(appearance:ResizeHandleRenderer):ResizeHandle<T> {
        this.appearance = appearance;
        return this;
    }

    /**
     * Start a drag carrying `value` when the band is pressed and moved.
     *
     * A band takes one drag, and this is it: use this rather than
     * `base.onDrag()`, which it shadows. GPUI tells drags apart by the type of
     * their payload, so the drag carries `value` itself, and a caller
     * following it with `onDragMove` listens for its class.
     */
    public function onDrag(value:T, f:(T, Point, Window, App) -> AnyView):ResizeHandle<T> {
        this.dragValue = value;
        this.dragConstructor = f;
        return this;
    }

    /**
     * Keep the whole handle inside its container, hugging `edge`, instead of
     * straddling the boundary it resizes.
     */
    public function inside(edge:HandleEdge):ResizeHandle<T> {
        this.edge = edge;
        return this;
    }

    override public function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final negOffset = -HANDLE_PADDING;
        final axis = this.axis;
        final edge = this.edge;
        // Sizes are border-box: the extent has to name the whole band, padding
        // included, or the content box resolves to zero and the hairline
        // overflows into the padding.
        final hugExtent = HANDLE_SIZE + HANDLE_PADDING;
        final straddleExtent = HANDLE_SIZE + HANDLE_PADDING * 2.;
        // The caller's listeners are already on it; what base adds is where the
        // band goes and what it holds.
        final base = this.base;
        this.base = div();
        final dragValue = this.dragValue;
        final dragConstructor = this.dragConstructor;
        this.dragValue = null;
        this.dragConstructor = null;

        return window.withElementState(globalId, SharedHandleState, (box, window) -> {
            if (box.value == null) box.value = new SharedHandleState();
            final state:SharedHandleState = box.value;

            final bgColor = handleColor(glaze.kit.base.theme.Theme.global(cx), state.get().isActive());

            final el = base
                .id(id)
                .testSupport()
                .occlude()
                .absolute()
                .flexShrink0()
                .group('handle');
            if (dragConstructor != null) {
                el.onDrag(dragValue, (value, position, window, cx) -> dragConstructor(value, position, window, cx));
            }
            if (edge == Trailing && axis == Horizontal) {
                // Hugging an edge: the whole band is inside the container,
                // padded on the inner side only, so the hairline is the
                // container's outermost pixel (the seam itself).
                // FIXME: Improve this to let the scroll bar have px(HANDLE_PADDING)
                el.cursorColResize().top0().right0().hFull().w(hugExtent).pl(HANDLE_PADDING);
            } else if (edge == Leading && axis == Horizontal) {
                el.cursorColResize().top0().left0().hFull().w(hugExtent).pr(HANDLE_PADDING);
            } else if (edge == Trailing && axis == Vertical) {
                el.cursorRowResize().bottom0().left0().wFull().h(hugExtent).pt(HANDLE_PADDING);
            } else if (edge == Leading && axis == Vertical) {
                el.cursorRowResize().top0().left0().wFull().h(hugExtent).pb(HANDLE_PADDING);
            } else if (axis == Horizontal) {
                // Straddling the boundary: half the band on either side.
                el.cursorColResize().top0().left(negOffset).hFull().w(straddleExtent).px(HANDLE_PADDING);
            } else {
                el.cursorRowResize().top(negOffset).left0().wFull().h(straddleExtent).py(HANDLE_PADDING);
            }

            // A renderer that declines, or is absent, leaves the built-in
            // line, so overriding one handle never obliges a caller to redraw
            // them all. What it paints stays in tree order, under the
            // container's own mask.
            var painted:Null<AnyElement> = null;
            if (appearance != null) {
                painted = appearance(new ResizeHandleContext(axis, edge, state.get()), window, cx);
            }
            if (painted == null) {
                final line = div()
                    // The line fills the handle's content box exactly, so it
                    // has nothing to give: a shrinkable child collapses with it.
                    .flexNone()
                    .bg(bgColor)
                    .groupHover('handle', s -> s.bg(bgColor));
                if (axis.isHorizontal()) line.hFull().w(HANDLE_SIZE);
                if (axis.isVertical()) line.wFull().h(HANDLE_SIZE);
                painted = line.intoAnyElement();
            }
            el.child(painted);

            final element = el.intoAnyElement();
            final layoutId = element.requestLayout(window, cx);
            child = element;
            return layoutId;
        });
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.prepaint(window, cx);
        // After the child, deliberately. The band's own div occludes, and a
        // hit test stops at the first hitbox that does, so a hitbox inserted
        // before it would sit underneath and never read as hovered.
        hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);

        // Hovered and pressed are answered by the hitbox, not by the bounds.
        final hitbox = this.hitbox;

        window.withElementState(globalId, SharedHandleState, (box, window) -> {
            if (box.value == null) box.value = new SharedHandleState();
            final state:SharedHandleState = box.value;

            window.onMouseEvent(MouseDown, (event, phase, window, _) -> {
                final ev:MouseDownEvent = cast event;
                if (phase.bubble() && hitbox.isHoveredAt(ev.position, window) && state.set(Pressed)) {
                    window.refresh();
                }
            });

            window.onMouseEvent(MouseMove, (event, phase, window, _) -> {
                if (!phase.bubble()) {
                    return;
                }
                final ev:MouseMoveEvent = cast event;

                // A press that moves is a drag, and stays one until the
                // button comes back up: by the second frame the pointer is
                // outside this nine-pixel band.
                final current = state.get();
                final next:ResizeHandleState = if (current.isActive()) {
                    Dragging;
                } else if (hitbox.isHoveredAt(ev.position, window)) {
                    Hovered;
                } else {
                    Idle;
                };
                if (state.set(next)) {
                    window.refresh();
                }
            });

            window.onMouseEvent(MouseUp, (event, _, window, _) -> {
                if (!state.get().isActive()) {
                    return;
                }
                final ev:MouseUpEvent = cast event;

                // Releasing over the handle leaves it hovered. Going straight
                // to idle there would drop the indicator for one frame and
                // bring it back under a pointer that never left.
                final next:ResizeHandleState = hitbox.isHoveredAt(ev.position, window) ? Hovered : Idle;
                if (state.set(next)) {
                    window.refresh();
                }
            });
            return null;
        });
    }

    /**
     * What a resize handle paints, given the active theme.
     *
     * Projected colors win; without them the handle resolves from the tokens
     * that already mean these two states everywhere else: `border` for a
     * divider at rest, `ring` for the thing the pointer currently owns.
     */
    @:allow(glaze.kit.base, tests)
    static function handleColor(theme:glaze.kit.base.theme.Theme, active:Bool):Hsla {
        if (active) {
            return theme.resizable.activeHandle != null ? theme.resizable.activeHandle : theme.tokens.colors.ring;
        } else {
            return theme.resizable.handle != null ? theme.resizable.handle : theme.tokens.colors.border;
        }
    }

}
