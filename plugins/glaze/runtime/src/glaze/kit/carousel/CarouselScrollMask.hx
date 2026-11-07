// Ported from gpui-kit 0.8.1: crates/component/src/carousel/scroll_mask.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.carousel;

import gpui.AbsoluteLength;
import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.ContentMask;
import gpui.DefiniteLength;
import gpui.Element;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.Hitbox;
import gpui.LayoutId;
import gpui.Length;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.OngoingScroll;
import gpui.Point;
import gpui.ScrollEvent;
import gpui.Style;
import gpui.Window;
import gpui.base.GlobalState;
import gpui.base.TextSelection;

import gpui.Prelude.*;

using gpui.ScrollDelta.ScrollDeltaTools;

/**
 * The pointer and wheel event surface used by `CarouselContent`: a
 * viewport-sized, invisible event surface for a Carousel.
 *
 * The mask is deliberately a sibling of the scrolled content. A mask nested
 * inside the content would receive the content's scroll offset and would stop
 * covering the viewport after the first scroll.
 *
 * This surface owns pointer, wheel, and trackpad input so that a Carousel
 * nested in a list can lock its own axis while allowing cross-axis gestures
 * to continue to an ancestor.
 */
@:allow(gpui.component.carousel)
class CarouselScrollMask extends Element {

    final axis:Axis;

    var _id:ElementId;

    final state:Entity<CarouselState>;

    var hitbox:Null<Hitbox> = null;

    function new(axis:Axis, state:Entity<CarouselState>, ?pos:haxe.PosInfos) {
        this.axis = axis;
        this._id = ElementId.CodeLocation(pos.fileName, pos.lineNumber);
        this.state = state;
    }

    function id(id:ElementIdArg):CarouselScrollMask {
        _id = id;
        return this;
    }

    override public function elementId():Null<ElementId> {
        return ElementId.NamedChild(_id, axis == Horizontal ? 'horizontal' : 'vertical');
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.position = Absolute;
        style.insetTop = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(0.)));
        style.insetLeft = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(0.)));
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        hitbox = window.insertHitbox(bounds, Normal);
    }

    public function paint(globalId:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        final axis = this.axis;
        final hitboxId = hitbox.id;
        final bounds = hitbox.bounds;
        final state = this.state;
        final ongoingScroll:OngoingScroll = globalId != null
            ? window.withElementState(globalId, OngoingScroll, (box, _) -> {
                if (box.value == null) box.value = new OngoingScroll();
                return box.value;
            })
            : new OngoingScroll();

        window.withContentMask(new ContentMask(bounds), window -> {
            final pointerState = state;
            window.onMouseEvent(MouseDown, (event, phase, window, cx) -> {
                final event:MouseDownEvent = cast event;
                if (phase == Capture && event.button == Left && window.shouldHitboxIdHandleScroll(hitboxId)) {
                    final started = pointerState.update(cx, (state, cx) -> state.beginDrag(event.position, cx));
                    if (started) {
                        GlobalState.suppressTextSelection(cx);
                    }
                }
            });

            window.onMouseEvent(MouseMove, (event, phase, _, cx) -> {
                final event:MouseMoveEvent = cast event;
                if (phase != Capture || event.pressedButton != Left) {
                    return;
                }

                final handled = pointerState.update(cx, (state, cx) -> state.updateDrag(event.position, cx));
                if (handled) {
                    cx.stopPropagation();
                }
            });

            var suppressRelease = false;
            window.onMouseEvent(MouseUp, (event, phase, window, cx) -> {
                final event:MouseUpEvent = cast event;
                if (event.button != Left) {
                    return;
                }

                if (phase == Capture) {
                    final snapshot = pointerState.read(cx);
                    final handled = snapshot.isPointerDragLocked();
                    suppressRelease = handled || snapshot.shouldSuppressPointerClick();
                    pointerState.update(cx, (state, cx) -> {
                        state.finishDrag(cx);
                    });
                    if (suppressRelease) {
                        // The release may be stopped before TextSelectionLayer's
                        // bubble listener. Clear its observable selection state
                        // here so a Carousel drag cannot leave a stale drag or
                        // participant-local selection behind.
                        TextSelection.clear(window, cx);
                    }
                }
                else if (suppressRelease) {
                    // All capture handlers have now cleared their pressed
                    // state. Stop before descendant click handlers run.
                    suppressRelease = false;
                    cx.stopPropagation();
                }
            });

            window.onMouseEvent(Scroll, (event, phase, window, cx) -> {
                final event:ScrollEvent = cast event;
                if (phase != Capture || !window.shouldHitboxIdHandleScroll(hitboxId)) {
                    return;
                }

                var delta = event.delta.pixelDelta(window.lineHeight());
                if (event.delta.precise()) {
                    // Rust `OngoingScrollExt::lock_axis`.
                    delta = ongoingScroll.filter(delta, event.touchPhase, cx.backgroundExecutor().now());
                }

                if (delta.x != 0. && delta.y != 0.) {
                    if (Math.abs(delta.x) > Math.abs(delta.y)) {
                        delta = new Point(delta.x, 0.);
                    }
                    else {
                        delta = new Point(0., delta.y);
                    }
                }

                // Ignore the secondary axis. The lock above keeps this stable
                // throughout a precise trackpad gesture.
                if (axis == Horizontal) {
                    delta = new Point(delta.x, 0.);
                }
                else {
                    delta = new Point(0., delta.y);
                }

                final precise = event.delta.precise();
                final primaryDelta = axis == Horizontal ? delta.x : delta.y;
                final consumed = if (primaryDelta == 0.) {
                    false;
                }
                else if (!precise) {
                    state.update(cx, (state, cx) -> state.handleWheelStep(axis, primaryDelta, cx));
                }
                else if (event.touchPhase == Ended || event.touchPhase == Cancelled) {
                    false;
                }
                else {
                    // A gesture this carousel already owns stays here even at
                    // an edge, so its leftover never scrolls an ancestor. One
                    // that begins at an edge belongs to the ancestor until it
                    // ends.
                    final owned = state.read(cx).hasScrollGesture();
                    final moved = state.update(cx, (state, cx) -> state.handleScrollDelta(axis, primaryDelta, event.touchPhase, cx));
                    if (!moved && !owned) {
                        state.update(cx, (state, cx) -> state.deferScrollToAncestor(cx));
                    }
                    moved || owned;
                };

                if (precise) {
                    switch event.touchPhase {
                        case Ended:
                            state.update(cx, (state, cx) -> state.finishScroll(false, cx));
                        case Cancelled:
                            state.update(cx, (state, cx) -> state.finishScroll(true, cx));
                        case Started | Moved:
                    }
                }

                // Horizontal carousels retain every gesture at their edge. A
                // vertical carousel hands a gesture that begins at an edge to
                // an ancestor so the surrounding document keeps scrolling.
                if (consumed || (axis == Horizontal && primaryDelta != 0.)) {
                    cx.stopPropagation();
                }
            });
            return null;
        });
    }

}
