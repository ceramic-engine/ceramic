// Ported from gpui-kit 0.8.1: crates/base/src/scrollable_mask.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AbsoluteLength;
import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.ContentMask;
import gpui.Corners;
import gpui.DefiniteLength;
import gpui.Div;
import gpui.Edges;
import gpui.Element;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.GlobalElementId;
import gpui.Hitbox;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Length;
import gpui.OngoingScroll;
import gpui.Path;
import gpui.PathBuilder;
import gpui.Point;
import gpui.ScrollEvent;
import gpui.ScrollHandle;
import gpui.Style;
import gpui.StyleRefinement;
import gpui.Window;
import gpui.base.Scrollbar.ScrollbarHandle;
import gpui.base.theme.Theme as BaseTheme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * A scroll step that a horizontal `ScrollableMask` used to move its content.
 */
class HorizontalScrollClaim {

    final _at:Float;

    final _deltaX:Float;

    public function new(at:Float, deltaX:Float) {
        _at = at;
        _deltaX = deltaX;
    }

    /** When the step was handled (seconds, `cx.backgroundExecutor().now()`). */
    public inline function at():Float {
        return _at;
    }

    /** How far the content moved: positive moves it right, negative moves it left. */
    public inline function deltaX():Float {
        return _deltaX;
    }

    public function equals(other:HorizontalScrollClaim):Bool {
        return other != null && _at == other._at && _deltaX == other._deltaX;
    }

}

/**
 * Keeps a rounded scroll viewport's corners clean at every scroll offset.
 *
 * GPUI clips children with a rectangular content mask, so content scrolled
 * under a rounded frame paints square into the corner notches: the regions
 * inside the frame's rect corners but outside its border arcs. The cover
 * fills each notch with the backdrop color, which reads as a rounded clip.
 * The frame's own border needs no help: gpui paints an element's border
 * after its children, so it already draws over both the scrolled content and
 * these covers.
 *
 * Like `ScrollableMask`, it must be a sibling of the scrolled element so it
 * does not move with the scroll offset.
 */
class RoundedFrameCover extends Element {

    final cornerRadii:Array<Null<AbsoluteLength>>;

    var _backdrop:Null<Hsla> = null;

    var _frameBorder:Float = 0.;

    var coverBounds:Bounds = new Bounds();

    /** Corners top left, top right, bottom right, bottom left. */
    @:allow(gpui.base)
    function new(topLeft:Null<AbsoluteLength>, topRight:Null<AbsoluteLength>, bottomLeft:Null<AbsoluteLength>, bottomRight:Null<AbsoluteLength>) {
        cornerRadii = [topLeft, topRight, bottomLeft, bottomRight];
    }

    /** A frame with the same radius on all four corners. */
    public static function uniform(radius:Float):RoundedFrameCover {
        final r = AbsoluteLength.Pixels(radius);
        return new RoundedFrameCover(r, r, r, r);
    }

    /**
     * The frame's border width, when the cover is a child of the bordered
     * element itself: the cover's bounds are then the content box, so the
     * painted notches are grown outward by this width to reach the border
     * box.
     */
    public function frameBorder(width:Float):RoundedFrameCover {
        _frameBorder = width;
        return this;
    }

    /**
     * The color behind the frame, used to fill the corner notches.
     * Defaults to the theme background.
     */
    public function backdrop(color:Hsla):RoundedFrameCover {
        _backdrop = color;
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        // Same layout trick as `ScrollableMask`: absolute and parent-sized.
        final style = new Style();
        style.position = Absolute;
        style.flexGrow = 1.0;
        style.flexShrink = 1.0;
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        // Shift up by one height to cover the viewport, like `ScrollableMask`.
        coverBounds = new Bounds(new Point(bounds.origin.x, bounds.origin.y - bounds.size.height), bounds.size);
    }

    public function paint(id:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        var bounds = coverBounds;
        if (_frameBorder != 0.) {
            bounds = new Bounds(
                new Point(bounds.origin.x - _frameBorder, bounds.origin.y - _frameBorder),
                new gpui.Size(bounds.size.width + _frameBorder * 2., bounds.size.height + _frameBorder * 2.)
            );
        }
        final remSize = window.remSize();
        inline function resolve(corner:Null<AbsoluteLength>):Null<Float> {
            if (corner == null) return null;
            final radius = corner.toPixels(remSize);
            return radius == 0. ? null : radius;
        }
        final topLeft = resolve(cornerRadii[0]);
        final topRight = resolve(cornerRadii[1]);
        final bottomLeft = resolve(cornerRadii[2]);
        final bottomRight = resolve(cornerRadii[3]);
        if (topLeft == null && topRight == null && bottomLeft == null && bottomRight == null) {
            return;
        }

        final backdrop = _backdrop != null ? _backdrop : BaseTheme.global(cx).tokens.colors.background;
        final corners:Array<{corner:Point, xDir:Float, yDir:Float, radius:Null<Float>}> = [
            {corner: bounds.origin, xDir: 1., yDir: 1., radius: topLeft},
            {corner: bounds.topRight(), xDir: -1., yDir: 1., radius: topRight},
            {corner: bounds.bottomRight(), xDir: -1., yDir: -1., radius: bottomRight},
            {corner: new Point(bounds.origin.x, bounds.bottomRight().y), xDir: 1., yDir: -1., radius: bottomLeft}
        ];
        for (entry in corners) {
            if (entry.radius == null) continue;
            final path = cornerNotchPath(entry.corner, entry.xDir, entry.yDir, entry.radius);
            if (path != null) {
                window.paintPath(path, backdrop);
            }
        }
    }

    /**
     * The notch at one frame corner: the square of side `radius` anchored at
     * `corner`, minus the quarter disc of the border arc. `xDir`/`yDir` point
     * from the corner toward the frame's inside (`±1`).
     */
    @:allow(gpui.base)
    static function cornerNotchPath(corner:Point, xDir:Float, yDir:Float, radius:Float):Null<Path> {
        final builder = PathBuilder.fill();
        builder.moveTo(corner);
        builder.lineTo(new Point(corner.x + radius * xDir, corner.y));
        builder.arcTo(
            new Point(radius, radius),
            0.,
            false,
            // The quarter arc nearest the corner: counterclockwise when the two
            // inward directions agree in sign, clockwise otherwise.
            xDir * yDir < 0.,
            new Point(corner.x, corner.y + radius * yDir)
        );
        builder.close();
        try {
            return builder.build();
        }
        catch (e:Dynamic) {
            return null;
        }
    }

}

/**
 * Make a scrollable mask element to cover the parent view with the mouse wheel event listening.
 *
 * When the mouse wheel is scrolled, will move the `scrollHandle` scrolling with the `axis` direction.
 * You can use this `scrollHandle` to control what you want to scroll.
 * This is only can handle once axis scrolling.
 *
 * Axis-dominant wheel events are consumed in the capture phase, so the mask
 * wins over ancestor scrollers (e.g. `list`) that register their listeners
 * after their children; events dominated by the other axis keep
 * propagating. The mask stays inert while occluded.
 *
 * Dominance is decided per gesture, not per event: a precise (trackpad) delta
 * locks onto the axis its gesture started on, so mid-swipe wobble cannot flip
 * which mask consumes the events. Line deltas keep the per-event comparison.
 *
 * At the scroll edge the two axes differ, matching platform scrollers:
 * a vertical mask hands the event over to the ancestor scroller, while a
 * horizontal mask keeps consuming it.
 *
 * A mouse wheel has no horizontal axis, so a horizontal mask leaves it to the
 * parent. Over a native horizontal scroller, `verticalWheel` scrolls
 * sideways with it instead.
 */
class ScrollableMask extends Element {

    /**
     * Offsets closer than this count as unchanged, so a sub-pixel residue left at
     * an edge does not read as room to scroll.
     */
    static inline final CLAIM_EPSILON:Float = 0.5;

    /** `LAST_HORIZONTAL_SCROLL_CLAIM` (a thread local in Rust). */
    @:allow(gpui.base)
    static var lastHorizontalScrollClaimValue:Null<HorizontalScrollClaim> = null;

    /**
     * The last scroll step a horizontal `ScrollableMask` used to move its
     * content, i.e. one that changed the clamped offset rather than pushing
     * against an edge.
     *
     * Hosts that put their own pan gesture over GPUI content (e.g. a swipe that
     * opens a side drawer on mobile) use it to let a horizontal strip such as a
     * markdown table scroll first: while the strip still has room in the swipe's
     * direction it claims the swipe; once it reaches that edge the claims stop and
     * the host may take over.
     */
    public static function lastHorizontalScrollClaim():Null<HorizontalScrollClaim> {
        return lastHorizontalScrollClaimValue;
    }

    final axis:Axis;

    var _id:ElementId;

    final scrollHandle:ScrollbarHandle;

    /**
     * Only turn a plain wheel's vertical lines into horizontal scrolling,
     * leaving every other event to the scroller below.
     */
    var verticalWheelOnly:Bool = false;

    var _debug:Null<Hsla> = null;

    var hitbox:Null<Hitbox> = null;

    /** Create a new scrollable mask element. */
    public function new(axis:Axis, scrollHandle:ScrollbarHandle, ?pos:haxe.PosInfos) {
        this.axis = axis;
        this.scrollHandle = scrollHandle;
        _id = ElementId.CodeLocation(pos.fileName, pos.lineNumber);
    }

    /**
     * Create a mask over a native horizontal scroller (one with
     * `overflowXScroll` and a locked scroll axis, such as a strip of tabs)
     * that scrolls it sideways with a plain mouse wheel's vertical lines, the
     * only axis such a wheel has.
     *
     * Once the scroller cannot move that way, the wheel goes on to the parent,
     * so a page still scrolls past the strip. Trackpad gestures and
     * horizontal wheels are left to the scroller, with its own axis lock and
     * bounce.
     */
    public static function verticalWheel(scrollHandle:ScrollbarHandle, ?pos:haxe.PosInfos):ScrollableMask {
        final result = new ScrollableMask(Horizontal, scrollHandle, pos);
        result.verticalWheelOnly = true;
        return result;
    }

    /**
     * Set a specific element id, default is the call site.
     *
     * Only needed when one call site creates several masks of the same axis,
     * which would otherwise share their gesture axis lock.
     */
    public function id(id:ElementIdArg):ScrollableMask {
        _id = id;
        return this;
    }

    /** Enable the debug border, to show the mask bounds. */
    public function debug():ScrollableMask {
        _debug = yellow();
        return this;
    }

    /**
     * A horizontal scroll viewport that only consumes horizontal wheel deltas.
     *
     * GPUI's native `overflowXScroll` maps vertical wheel input onto horizontal
     * scrolling when there is no vertical overflow. This wrapper keeps the visual
     * clipping and scroll offset, while delegating wheel input to `ScrollableMask`
     * so vertical wheel events can continue bubbling to the parent scroller.
     */
    @:allow(gpui)
    static function horizontalScrollArea(id:ElementIdArg, scrollHandle:ScrollHandle, style:StyleRefinement, child:IntoElement):Div {
        final id:ElementId = id;

        // The mask must be a sibling of the scrolled element (like in Table), not
        // a child of it: children are prepainted with the scroll offset applied,
        // which would slide the mask away from the viewport as the content
        // scrolls, leaving the uncovered part to the parent scroller.
        //
        // The frame cover is a sibling for the same reason: it keeps the rounded
        // corners clean at every scroll offset (see `RoundedFrameCover`).
        final frame = new RoundedFrameCover(style.cornerRadiusTopLeft, style.cornerRadiusTopRight, style.cornerRadiusBottomLeft, style.cornerRadiusBottomRight);

        return div()
            .wFull()
            .relative()
            .child(
                div()
                    .id(id)
                    .wFull()
                    .refineStyle(style)
                    .overflowHidden()
                    .trackScroll(scrollHandle)
                    .child(child)
            )
            .child(new ScrollableMask(Horizontal, scrollHandle).id(id))
            .child(frame);
    }

    // An id is needed to keep the gesture's axis lock across frames. The axis
    // suffix keeps both masks of one scroller apart when they share an id.
    override public function elementId():Null<ElementId> {
        return ElementId.NamedChild(_id, axis == Horizontal ? 'horizontal' : 'vertical');
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        // Cover the parent whatever its layout: pinned to its top-left corner
        // rather than left at a static position that depends on whether the
        // parent stacks its children in a column or a row.
        style.position = Absolute;
        style.insetTop = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(0.)));
        style.insetLeft = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(0.)));
        style.flexGrow = 1.0;
        style.flexShrink = 1.0;
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        hitbox = window.insertHitbox(bounds, Normal);
    }

    static inline function clampOffset(value:Float, max:Float):Float {
        return value < -max ? -max : (value > 0. ? 0. : value);
    }

    public function paint(globalId:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        final isHorizontal = axis == Horizontal;
        final verticalWheel = verticalWheelOnly;
        final lineHeight = window.lineHeight();
        final bounds = hitbox.bounds;
        final ongoingScroll:OngoingScroll = globalId != null
            ? window.withElementState(globalId, OngoingScroll, (box, _) -> {
                if (box.value == null) box.value = new OngoingScroll();
                return box.value;
            })
            : new OngoingScroll();
        final debug = _debug;
        final scrollHandle = this.scrollHandle;
        final hitboxId = hitbox.id;

        window.withContentMask(new ContentMask(bounds), window -> {
            if (debug != null) {
                window.paintQuad(quad(bounds, Corners.all(0.), transparentWhite(), Edges.all(1.0), debug, Solid));
            }

            final viewId = window.currentView();
            window.onMouseEvent(Scroll, (event, phase, window, cx) -> {
                final event:ScrollEvent = cast event;
                // Handle in the capture phase: ancestor scrollers such as
                // `list` register their wheel listeners after their children
                // paint, so in the bubble phase (reverse registration order)
                // they run first and would consume the vertical component of
                // a trackpad swipe before this mask could stop the
                // propagation.
                //
                // `shouldHandleScroll` (instead of a raw bounds check) keeps
                // the mask inert when it is occluded, e.g. below an open
                // dialog or context menu.
                if (!(phase == Capture && window.shouldHitboxIdHandleScroll(hitboxId))) {
                    return;
                }

                var offset = scrollHandle.offset();
                var delta = event.delta.pixelDelta(lineHeight);

                // A plain mouse wheel's vertical lines move the scroller
                // sideways; once it is at its edge the parent scrolls
                // instead, as for a vertical mask.
                if (verticalWheel) {
                    final lines = switch event.delta {
                        case Lines(lines): lines;
                        case Pixels(_): return;
                    };
                    if (lines.x != 0. || lines.y == 0. || !Math.isFinite(lines.y)) {
                        return;
                    }
                    final axisMax = Math.max(scrollHandle.contentSize().width - scrollHandle.viewportBounds().size.width, 0.);
                    final current = clampOffset(offset.x, axisMax);
                    final newOffset = clampOffset(current + delta.y, axisMax);
                    if (newOffset == current) {
                        return;
                    }

                    scrollHandle.setOffset(new Point(newOffset, offset.y));
                    cx.notify(viewId);
                    cx.stopPropagation();
                    return;
                }

                // Lock the gesture to the axis it started on, so a diagonal
                // trackpad swipe cannot flip which mask consumes it from one
                // event to the next. Line deltas carry no touch phase.
                if (event.delta.precise()) {
                    delta = ScrollBounce.lockAxis(ongoingScroll, delta, event.touchPhase, cx);
                }

                // Limit for only one way scrolling at same time.
                // When use MacBook touchpad we may get both x and y delta,
                // only allows the one that more to scroll.
                if (delta.x != 0. && delta.y != 0.) {
                    if (Math.abs(delta.x) > Math.abs(delta.y)) {
                        delta = new Point(delta.x, 0.);
                    }
                    else {
                        delta = new Point(0., delta.y);
                    }
                }

                if (!isHorizontal) {
                    // The current offset must be clamped too: after a
                    // bubbled event, the scrolled element's own listener
                    // pushes the shared offset beyond the edge unclamped
                    // (the div only clamps on prepaint), and that
                    // transient overscroll would read as "room to scroll".
                    final axisMax = Math.max(scrollHandle.contentSize().height - scrollHandle.viewportBounds().size.height, 0.);
                    final current = clampOffset(offset.y, axisMax);
                    final newOffset = clampOffset(current + delta.y, axisMax);
                    if (newOffset == current) {
                        // At the edge or no overflow: bubble to the parent.
                        return;
                    }

                    scrollHandle.setOffset(new Point(offset.x, newOffset));
                    cx.notify(viewId);
                    cx.stopPropagation();
                    return;
                }

                // Record whether this step actually moves the content (see
                // `lastHorizontalScrollClaim`). The current offset is clamped
                // for comparison only: the next offset must use the raw
                // value, which may sit past the edge until prepaint.
                if (delta.x != 0.) {
                    final axisMax = Math.max(scrollHandle.contentSize().width - scrollHandle.viewportBounds().size.width, 0.);
                    final current = clampOffset(offset.x, axisMax);
                    final moved = clampOffset(offset.x + delta.x, axisMax) - current;
                    if (Math.abs(moved) >= CLAIM_EPSILON) {
                        lastHorizontalScrollClaimValue = new HorizontalScrollClaim(cx.backgroundExecutor().now(), moved);
                    }
                }

                offset = new Point(offset.x + delta.x, offset.y);

                // NOTE: `setOffset` does not clamp (clamping happens in the
                // div's prepaint), so any non-zero horizontal-dominant delta
                // passes this guard: even at the scroll edge the event is
                // consumed rather than turned into a parent scroll.
                if (!offset.equals(scrollHandle.offset())) {
                    scrollHandle.setOffset(offset);
                    cx.notify(viewId);
                    cx.stopPropagation();
                }
            });
            return null;
        });
    }

}
