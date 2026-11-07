// Ported from gpui-kit 0.8.1: crates/base/src/positioner.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Decorations;
import glaze.Display;
import glaze.Edges;
import glaze.Element;
import glaze.GlobalElementId;
import glaze.HitboxBehavior;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.ParentElement;
import glaze.Point;
import glaze.Position;
import glaze.Size;
import glaze.Style;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;
import glaze.util.MathUtil;

/**
 * Shared popup positioning.
 *
 * Every anchored surface in Base resolves its position here so that flipping,
 * alignment, and viewport clamping cannot drift apart between popups,
 * tooltips, and menus.
 */
enum abstract Align(Int) {

    /** Align with the trigger's leading edge. */
    var Start = 0;

    /** Center on the trigger (the default). */
    var Center = 1;

    /** Align with the trigger's trailing edge. */
    var End = 2;

}

/**
 * How a popup derives its position.
 */
enum PositionerStrategy {

    /**
     * Place `anchor`'s corner of the popup at `position`, then clamp into the
     * viewport. This reproduces GPUI's `anchored` corner behavior and does not
     * flip to the opposite side.
     */
    Corner(anchor:Anchor, position:Point);

    /**
     * Place the popup on `placement`'s side of the trigger, flipping to the
     * opposite side when it does not fit, then clamp into the viewport.
     */
    Side(triggerBounds:Bounds, placement:Null<Placement>, align:Align, offset:Float);

}

/**
 * The bounds a popup resolved to, and the side it ended up on.
 */
class ResolvedPosition {

    /** Final popup bounds in window coordinates. */
    public final bounds:Bounds;

    /**
     * The side the popup was placed on. `null` for corner positioning, which
     * has no notion of a side.
     */
    public final placement:Null<Placement>;

    public function new(bounds:Bounds, placement:Null<Placement>) {
        this.bounds = bounds;
        this.placement = placement;
    }

    public function equals(other:ResolvedPosition):Bool {
        return bounds.equals(other.bounds) && placement == other.placement;
    }

}

/**
 * A mutable cell holding a point (Rust `Rc<Cell<Point<Pixels>>>`).
 */
class PointCell {

    public var value:Point;

    public function new(value:Point) {
        this.value = value;
    }

}

/**
 * An unstyled element that positions its children as an anchored popup.
 *
 * This owns measurement, side selection, alignment, and viewport clamping. It
 * installs no presentation of its own and adds no wrapper element around its
 * children.
 */
class Positioner extends Element implements ParentElement {

    @:allow(glaze.kit.base)
    var strategy:PositionerStrategy;

    var cornerPosition:Null<PointCell> = null;

    var onPositionCallback:Null<(ResolvedPosition) -> Void> = null;

    var marginValue:Float = 4.;

    var occludeValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    // Rust `PositionerState`
    final childLayoutIds:Array<LayoutId> = [];

    function new(strategy:PositionerStrategy) {
        this.strategy = strategy;
    }

    /**
     * Places the popup on a side of `triggerBounds`, flipping when needed.
     */
    public static function side(triggerBounds:Bounds):Positioner {
        return new Positioner(Side(triggerBounds, null, Center, 0.));
    }

    /**
     * Places `anchor`'s corner of the popup at `position`.
     *
     * This is the corner-anchoring path used by triggers that were written
     * against GPUI's `anchored` element. It clamps into the viewport without
     * changing the requested anchor.
     */
    public static function corner(anchor:Anchor, position:Point):Positioner {
        return new Positioner(Corner(anchor, position));
    }

    /**
     * Updates the requested corner position. It has no effect on a
     * side-positioned popup.
     */
    public function position(position:Point):Positioner {
        switch strategy {
            case Corner(anchor, _):
                strategy = Corner(anchor, position);
            case _:
        }
        return this;
    }

    /**
     * Sets the preferred side. Only meaningful for `Positioner.side`.
     */
    public function placement(placement:Placement):Positioner {
        switch strategy {
            case Side(triggerBounds, _, align, offset):
                strategy = Side(triggerBounds, placement, align, offset);
            case _:
        }
        return this;
    }

    /**
     * Sets the alignment along the chosen side. Only meaningful for
     * `Positioner.side`.
     */
    public function align(align:Align):Positioner {
        switch strategy {
            case Side(triggerBounds, placement, _, offset):
                strategy = Side(triggerBounds, placement, align, offset);
            case _:
        }
        return this;
    }

    /**
     * Sets the gap between the trigger and the popup. Only meaningful for
     * `Positioner.side`.
     */
    public function offset(offset:Float):Positioner {
        switch strategy {
            case Side(triggerBounds, placement, align, _):
                strategy = Side(triggerBounds, placement, align, offset);
            case _:
        }
        return this;
    }

    // Read after trigger prepaint so an open popup follows a moving trigger.
    @:allow(glaze.kit.base)
    function trackedCornerPosition(position:PointCell):Positioner {
        cornerPosition = position;
        return this;
    }

    /**
     * Observe resolved geometry before children prepaint.
     */
    public function onPosition(callback:(ResolvedPosition) -> Void):Positioner {
        onPositionCallback = callback;
        return this;
    }

    /**
     * Blocks the mouse over the positioned popup.
     *
     * Off by default, because a tooltip that swallowed the pointer would
     * un-hover the very trigger keeping it open. An interactive surface (a
     * popover, a menu, a dropdown) wants it on: what the surface covers is
     * the surface's, not the panel underneath.
     */
    public function occlude():Positioner {
        occludeValue = true;
        return this;
    }

    /**
     * Sets the minimum distance kept between the popup and the viewport edge.
     */
    public function margin(margin:Float):Positioner {
        marginValue = margin;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) {
            childElements.push(element);
        }
    }

    public function child(child:IntoElement):Positioner {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Positioner {
        for (child in children) {
            if (child != null) childElements.push(child);
        }
        return this;
    }

    /**
     * The part of the window's viewport that is frame rather than content, per
     * side.
     *
     * A window drawn with client-side decorations pads its content by the client
     * inset to make room for a shadow, except along an edge that is tiled against
     * the screen. A server-decorated window has no frame of its own.
     */
    @:allow(tests)
    static function frameInsets(decorations:Decorations, clientInset:Float):Edges {
        return switch decorations {
            case Server: new Edges();
            case Client(tiling): new Edges(
                    tiling.top ? 0. : clientInset,
                    tiling.right ? 0. : clientInset,
                    tiling.bottom ? 0. : clientInset,
                    tiling.left ? 0. : clientInset
                );
        }
    }

    /**
     * Resolves the bounds of a popup of `popupSize`.
     *
     * Side placement picks the preferred side when the popup fits, otherwise the
     * opposite side, otherwise whichever side has more room. The result is always
     * clamped into the viewport, keeping `margin` from each edge.
     */
    @:allow(tests)
    static function resolve(strategy:PositionerStrategy, popupSize:Size, viewportSize:Size, margin:Edges):ResolvedPosition {
        return switch strategy {
            case Corner(anchor, position):
                new ResolvedPosition(clamp(Bounds.fromAnchorAndSize(anchor, position, popupSize), viewportSize, margin), null);
            case Side(triggerBounds, placement, align, offset):
                final placement = resolvePlacement(triggerBounds, popupSize, viewportSize, margin, placement);
                final origin = sideOrigin(triggerBounds, popupSize, placement, align, offset);
                new ResolvedPosition(clamp(new Bounds(origin, popupSize), viewportSize, margin), placement);
        }
    }

    static function resolvePlacement(triggerBounds:Bounds, popupSize:Size, viewportSize:Size, margin:Edges, preferred:Null<Placement>):Placement {
        final rightLimit = Math.max(viewportSize.width - margin.right, margin.left);
        final bottomLimit = Math.max(viewportSize.height - margin.bottom, margin.top);
        final availableLeft = Math.max(triggerBounds.left() - margin.left, 0.);
        final availableRight = Math.max(rightLimit - triggerBounds.right(), 0.);
        final availableAbove = Math.max(triggerBounds.top() - margin.top, 0.);
        final availableBelow = Math.max(bottomLimit - triggerBounds.bottom(), 0.);

        if (preferred == Placement.Right) {
            if (popupSize.width <= availableRight) return Placement.Right;
            if (popupSize.width <= availableLeft) return Placement.Left;
            if (availableRight >= availableLeft) return Placement.Right;
            return Placement.Left;
        }
        if (preferred == Placement.Left) {
            if (popupSize.width <= availableLeft) return Placement.Left;
            if (popupSize.width <= availableRight) return Placement.Right;
            if (availableLeft >= availableRight) return Placement.Left;
            return Placement.Right;
        }
        if (preferred == Placement.Bottom) {
            if (popupSize.height <= availableBelow) return Placement.Bottom;
            if (popupSize.height <= availableAbove) return Placement.Top;
            if (availableBelow >= availableAbove) return Placement.Bottom;
            return Placement.Top;
        }
        // Placement.Top or none
        if (popupSize.height <= availableAbove) return Placement.Top;
        if (popupSize.height <= availableBelow) return Placement.Bottom;
        if (availableBelow >= availableAbove) return Placement.Bottom;
        return Placement.Top;
    }

    static function sideOrigin(triggerBounds:Bounds, popupSize:Size, placement:Placement, align:Align, offset:Float):Point {
        final alignedX = switch align {
            case Start: triggerBounds.left();
            case Center: triggerBounds.center().x - popupSize.width / 2;
            case End: triggerBounds.right() - popupSize.width;
        };
        final alignedY = switch align {
            case Start: triggerBounds.top();
            case Center: triggerBounds.center().y - popupSize.height / 2;
            case End: triggerBounds.bottom() - popupSize.height;
        };

        return switch placement {
            case Top: new Point(alignedX, triggerBounds.top() - popupSize.height - offset);
            case Bottom: new Point(alignedX, triggerBounds.bottom() + offset);
            case Left: new Point(triggerBounds.left() - popupSize.width - offset, alignedY);
            case Right: new Point(triggerBounds.right() + offset, alignedY);
        }
    }

    static function clamp(bounds:Bounds, viewportSize:Size, margin:Edges):Bounds {
        final rightLimit = Math.max(viewportSize.width - margin.right, margin.left);
        final bottomLimit = Math.max(viewportSize.height - margin.bottom, margin.top);

        var x = bounds.origin.x;
        var y = bounds.origin.y;
        final width = bounds.size.width;
        final height = bounds.size.height;
        if (x + width > rightLimit) {
            x -= x + width - rightLimit;
        }
        if (x < margin.left) {
            x = margin.left;
        }
        if (y + height > bottomLimit) {
            y -= y + height - bottomLimit;
        }
        if (y < margin.top) {
            y = margin.top;
        }

        return new Bounds(new Point(x, y), bounds.size);
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        childLayoutIds.resize(0);
        for (child in childElements) {
            childLayoutIds.push(child.requestLayout(window, cx));
        }
        final style = new Style();
        style.position = Position.Absolute;
        style.display = Display.Flex;
        return window.requestLayout(style, childLayoutIds, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (childLayoutIds.length == 0) {
            return;
        }

        var childMin = new Point(PIXELS_MAX, PIXELS_MAX);
        var childMax = new Point(0, 0);
        for (childLayoutId in childLayoutIds) {
            final childBounds = window.layoutBounds(childLayoutId);
            childMin = childMin.min(childBounds.origin);
            childMax = childMax.max(childBounds.bottomRight());
        }

        final popupSize = new Size(childMax.x - childMin.x, childMax.y - childMin.y);
        // Rust reads `window.window_decorations()` and `window.client_inset()`:
        // the port's windows have no client side decorations (server, no inset).
        final frame = frameInsets(Decorations.Server, 0.);
        var strategy = this.strategy;
        if (cornerPosition != null) {
            switch strategy {
                case Corner(anchor, _):
                    strategy = Corner(anchor, cornerPosition.value);
                case _:
            }
        }
        final margin = marginValue;
        final position = resolve(strategy, popupSize, window.viewportSize(), frame.map(inset -> inset + margin));
        if (onPositionCallback != null) {
            onPositionCallback(position);
        }
        // Ahead of the children so it blocks what is behind the popup without
        // blocking the popup's own content.
        if (occludeValue) {
            window.insertHitbox(position.bounds, HitboxBehavior.BlockMouse);
        }

        final offset = new Point(MathUtil.round(position.bounds.origin.x - bounds.origin.x), MathUtil.round(position.bounds.origin.y - bounds.origin.y));

        window.withElementOffset(offset, window -> {
            for (child in childElements) {
                child.prepaint(window, cx);
            }
            return null;
        });
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        for (child in childElements) {
            child.paint(window, cx);
        }
    }

    /** Rust `Pixels::MAX` (`f32::MAX`). */
    static inline final PIXELS_MAX:Float = 3.4028234663852886e38;

}
