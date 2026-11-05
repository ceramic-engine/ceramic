// Ported from gpui-kit 0.8.1: crates/component/src/carousel/carousel.rs
// (CarouselContent, CarouselGeometry, same_bounds, CarouselLoopItem)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.carousel;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Element;
import gpui.ElementId;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.ParentElement;
import gpui.Point;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.motion.Motion;
import gpui.base.motion.TransitionId;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.ElementExt;
using gpui.base.StyledExt;

/**
 * The layout the content last read (Rust `CarouselGeometry` of
 * carousel.rs), kept in a keyed state.
 */
@:allow(gpui.component.carousel)
private class CarouselContentGeometry {

    var viewport:Bounds = new Bounds();

    var frame:Bounds = new Bounds();

    var items:Array<Bounds> = [];

    var hasRunway:Bool = false;

    var revision:Int = 0;

    function new() {}

    /**
     * Reads the layout relative to the content `frame` origin.
     *
     * Window-space bounds move whenever an ancestor scrolls or shifts the
     * carousel, while every snap and loop calculation uses only differences
     * and sizes. Storing frame-relative bounds keeps those moves from being
     * treated as layout changes.
     */
    static function read(state:CarouselState, frame:Bounds, hasRunway:Bool, renderedItemCount:Int):CarouselContentGeometry {
        final handle = state.scrollHandle();
        final itemOffset = hasRunway ? 1 : 0;
        final origin = frame.origin;
        inline function relative(bounds:Bounds):Bounds {
            return new Bounds(new Point(f32(bounds.origin.x - origin.x), f32(bounds.origin.y - origin.y)), bounds.size);
        }
        final result = new CarouselContentGeometry();
        result.viewport = relative(handle.bounds());
        result.frame = new Bounds(new Point(0., 0.), frame.size);
        final count = state.itemCount() < renderedItemCount ? state.itemCount() : renderedItemCount;
        for (ix in 0...count) {
            final bounds = handle.boundsForItem(ix + itemOffset);
            if (bounds != null) result.items.push(relative(bounds));
        }
        result.hasRunway = hasRunway;
        result.revision = 0;
        return result;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    /**
     * Compares layouts with a sub-pixel tolerance so float noise from the
     * frame-relative subtraction does not register as a layout change.
     */
    function sameLayout(other:CarouselContentGeometry):Bool {
        if (hasRunway != other.hasRunway || !sameBounds(viewport, other.viewport) || !sameBounds(frame, other.frame) || items.length != other.items.length) {
            return false;
        }
        for (i in 0...items.length) {
            if (!sameBounds(items[i], other.items[i])) return false;
        }
        return true;
    }

    static function sameBounds(left:Bounds, right:Bounds):Bool {
        final TOLERANCE = 0.01;
        return Math.abs(f32(left.origin.x - right.origin.x)) <= TOLERANCE
            && Math.abs(f32(left.origin.y - right.origin.y)) <= TOLERANCE
            && Math.abs(f32(left.size.width - right.size.width)) <= TOLERANCE
            && Math.abs(f32(left.size.height - right.size.height)) <= TOLERANCE;
    }

}

/**
 * A layout-transparent proxy that paints one real item in the closest loop
 * cycle. The child keeps its original layout id, so ScrollHandle geometry
 * continues to address logical items without cloning their elements.
 */
private class CarouselLoopItem extends Element {

    final child:AnyElement;

    final index:Int;

    final state:Entity<CarouselState>;

    public function new(child:AnyElement, index:Int, state:Entity<CarouselState>) {
        this.child = child;
        this.index = index;
        this.state = state;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final offset = state.read(cx).loopItemOffset(index);
        window.withElementOffset(offset, window -> {
            child.prepaint(window, cx);
            return null;
        });
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

/**
 * The clipped viewport and snap track for Carousel items.
 */
class CarouselContent implements RenderOnce implements Styled implements ParentElement {

    final state:Entity<CarouselState>;

    final contentStyle:StyleRefinement = new StyleRefinement();

    var trackStyleValue:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /** Creates content bound to `state`. */
    public function new(state:Entity<CarouselState>) {
        this.state = state;
    }

    /**
     * Sets style overrides for the inner flex track.
     *
     * Use this for paired Carousel spacing such as a negative leading margin.
     * The `Styled` implementation applies to the clipped viewport itself.
     */
    public function trackStyle(style:StyleRefinement):CarouselContent {
        trackStyleValue = style;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):CarouselContent {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):CarouselContent {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return contentStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final entityId = state.entityId();
        final snapshot = state.read(cx);
        final axis = snapshot.axis();
        final selectedIx = snapshot.selectedIndex();
        final itemCount = snapshot.itemCount();
        final handle = snapshot.scrollHandle();
        final interacting = snapshot.isInteracting();
        final motionRevision = snapshot.motionRevision();
        final loopRunway = snapshot.loopRunway();
        final loopLayoutTransitioning = snapshot.isLoopLayoutTransitioning();
        final stateSnapTarget = selectedIx != null ? snapshot.motionTargetFor(selectedIx) : null;

        final geometry = window.useKeyedState(
            ElementId.NamedChild(ElementId.NamedInteger('carousel-geometry', entityId), 'content'),
            cx,
            _ -> new CarouselContentGeometry()
        );
        final geometryRevision = geometry.read(cx).value.revision;

        final current = Carousel.axisValue(handle.offset(), axis);
        var target = if (loopLayoutTransitioning) {
            current;
        }
        else if (stateSnapTarget != null) {
            Carousel.axisValue(stateSnapTarget, axis);
        }
        else {
            final snap = selectedIx != null ? Carousel.snapOffset(handle, axis, selectedIx + (loopRunway != null ? 1 : 0)) : null;
            snap != null ? snap : current;
        };
        if (interacting) target = current;
        final snapSpring = Theme.global(cx).motionTokens().springMove.withEpsilon(0.5);
        final animated = Motion.spring(
            TransitionId.named(ElementId.NamedInteger('carousel-content', entityId), 'offset-$motionRevision-$geometryRevision'),
            target,
            snapSpring.withTravel(!interacting),
            window,
            cx
        );
        var offset = Carousel.setAxisValue(handle.offset(), axis, animated);
        offset = Carousel.setAxisValue(offset, axis == Horizontal ? Vertical : Horizontal, 0.);
        handle.setOffset(offset);
        if (!interacting) {
            final rendered = offset;
            final rebased = state.update(cx, (state, cx) -> state.settleLoopMotion(rendered, cx));
            if (rebased != null) {
                offset = rebased;
                handle.setOffset(offset);
            }
        }

        final geometryState = state;
        final viewportId = ElementId.NamedInteger('carousel-content', entityId);

        final renderedItemCount = childElements.length;
        final loopState = state;
        final children:Array<IntoElement> = [for (index in 0...childElements.length) new CarouselLoopItem(childElements[index], index, loopState).intoAnyElement()];
        function runwaySpacer(runway:Float):IntoElement {
            final spacer = div().flexNone();
            if (axis == Horizontal) spacer.w(gpui.Prelude.px(runway));
            if (axis == Vertical) spacer.h(gpui.Prelude.px(runway));
            return spacer;
        }
        final hasRunway = loopRunway != null;

        // As a flex child the track grows by its negative leading
        // margin, so the padded items fill the frame on both edges.
        final track = div()
            .id(viewportId)
            .flex1()
            .flex();
        if (axis == Horizontal) track.flexRow().minW0().mlNeg4();
        if (axis == Vertical) track.flexCol().minH0().mtNeg4();
        track.trackScroll(handle);
        if (loopRunway != null) track.child(runwaySpacer(loopRunway));
        track.children(children);
        if (loopRunway != null) track.child(runwaySpacer(loopRunway));
        track.refineStyle(trackStyleValue);

        final root = div()
            .relative()
            .wFull()
            .flex();
        if (axis == Horizontal) root.flexRow();
        if (axis == Vertical) root.flexCol();
        root.refineStyle(contentStyle)
            .overflowHidden()
            .child(track)
            .child(new CarouselScrollMask(axis, state).id(viewportId))
            .onPrepaint((frame, _, cx) -> {
                final next = CarouselContentGeometry.read(geometryState.read(cx), frame, hasRunway, renderedItemCount);
                if (!geometry.read(cx).value.sameLayout(next)) {
                    geometryState.update(cx, (state, _) -> {
                        state.setGeometryWithRunway(next.viewport, next.frame, next.items.copy(), next.hasRunway);
                    });
                    geometry.update(cx, (model, cx) -> {
                        final current = model.value;
                        current.viewport = next.viewport;
                        current.frame = next.frame;
                        current.items = next.items;
                        current.hasRunway = next.hasRunway;
                        current.revision = current.revision + 1;
                        cx.notify();
                    });
                }
            });
        if (itemCount == 0) root.invisible();
        return root;
    }

}
