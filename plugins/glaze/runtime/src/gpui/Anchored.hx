// Ported from gpui-pre 0.3.10: src/elements/anchored.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.MathUtil;

/**
 * An anchored element that can be used to display UI that
 * will avoid overflowing the window bounds. Create one with `Prelude.anchored()`.
 * Its children should have no margin to avoid measurement issues.
 */
class Anchored extends Element implements ParentElement {

    final childElements:Array<AnyElement> = [];

    var anchorCorner:Anchor = Anchor.TopLeft;

    var fitMode:AnchoredFitMode = AnchoredFitMode.SwitchAnchor;

    var anchorPosition:Null<Point> = null;

    var positionModeValue:AnchoredPositionMode = AnchoredPositionMode.Window;

    var offsetValue:Null<Point> = null;

    // Rust `AnchoredState`
    final childLayoutIds:Array<LayoutId> = [];

    public function new() {}

    /**
     * Sets which corner of the anchored element should be anchored to the current position.
     */
    public function anchor(anchor:Anchor):Anchored {
        anchorCorner = anchor;
        return this;
    }

    /**
     * Sets the position in window coordinates
     * (otherwise the location the anchored element is rendered is used).
     */
    public function position(anchor:Point):Anchored {
        anchorPosition = anchor;
        return this;
    }

    /**
     * Offset the final position by this amount.
     * Useful when you want to anchor to an element but offset from it, such as in PopoverMenu.
     */
    public function offset(offset:Point):Anchored {
        offsetValue = offset;
        return this;
    }

    /**
     * Sets the position mode for this anchored element. `Local` will have this
     * interpret its `position` as relative to the parent element,
     * while `Window` will have it interpret the position as relative to the window.
     */
    public function positionMode(mode:AnchoredPositionMode):Anchored {
        positionModeValue = mode;
        return this;
    }

    /**
     * Snap to window edge instead of switching anchor corner when an overflow would occur.
     */
    public function snapToWindow():Anchored {
        fitMode = AnchoredFitMode.SnapToWindow;
        return this;
    }

    /**
     * Snap to window edge and leave some margins.
     */
    public function snapToWindowWithMargin(edges:Edges):Anchored {
        fitMode = AnchoredFitMode.SnapToWindowWithMargin(edges);
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) {
            childElements.push(element);
        }
    }

    /**
     * Add a single child element to this element.
     */
    public function child(child:IntoElement):Anchored {
        childElements.push(child);
        return this;
    }

    /**
     * Add multiple child elements to this element.
     */
    public function children(children:Array<IntoElement>):Anchored {
        for (child in children) {
            childElements.push(child);
        }
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        childLayoutIds.resize(0);
        for (child in childElements) {
            childLayoutIds.push(child.requestLayout(window, cx));
        }

        final anchoredStyle = new Style();
        anchoredStyle.position = Position.Absolute;
        anchoredStyle.display = Display.Flex;

        return window.requestLayout(anchoredStyle, childLayoutIds, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (childLayoutIds.length == 0) {
            return;
        }

        var childrenBounds:Null<Bounds> = null;
        for (childLayoutId in childLayoutIds) {
            final childBounds = window.layoutBounds(childLayoutId);
            childrenBounds = childrenBounds == null ? childBounds : childrenBounds.union(childBounds);
        }

        final origin = getPosition(positionModeValue, anchorPosition, bounds);
        var desired = getBounds(positionModeValue, anchorPosition, anchorCorner, childrenBounds.size, bounds, offsetValue);

        final limits = new Bounds(new Point(0, 0), window.viewportSize());

        if (fitMode.match(SwitchAnchor)) {
            var anchor = anchorCorner;

            if (desired.left() < limits.left() || desired.right() > limits.right()) {
                final switched = Bounds.fromAnchorAndSize(anchor.otherSideAlong(Axis.Horizontal), origin, childrenBounds.size);
                if (!(switched.left() < limits.left() || switched.right() > limits.right())) {
                    anchor = anchor.otherSideAlong(Axis.Horizontal);
                    desired = switched;
                }
            }

            if (desired.top() < limits.top() || desired.bottom() > limits.bottom()) {
                final switched = Bounds.fromAnchorAndSize(anchor.otherSideAlong(Axis.Vertical), origin, childrenBounds.size);
                if (!(switched.top() < limits.top() || switched.bottom() > limits.bottom())) {
                    desired = switched;
                }
            }
        }

        // Rust `window.client_inset`: only set for client side decorations, not ported (0).
        final clientInset = 0.0;
        final margins = switch fitMode {
            case SnapToWindowWithMargin(edges): edges;
            case _: new Edges();
        }
        final edges = new Edges(margins.top + clientInset, margins.right + clientInset, margins.bottom + clientInset, margins.left + clientInset);

        // Snap the horizontal edges of the anchored element to the horizontal edges of the window if
        // its horizontal bounds overflow, aligning to the left if it is wider than the limits.
        var desiredX = desired.origin.x;
        var desiredY = desired.origin.y;
        final desiredWidth = desired.size.width;
        final desiredHeight = desired.size.height;
        if (desiredX + desiredWidth > limits.right()) {
            desiredX -= desiredX + desiredWidth - limits.right() + edges.right;
        }
        if (desiredX < limits.left()) {
            desiredX = limits.origin.x + edges.left;
        }

        // Snap the vertical edges of the anchored element to the vertical edges of the window if
        // its vertical bounds overflow, aligning to the top if it is taller than the limits.
        if (desiredY + desiredHeight > limits.bottom()) {
            desiredY -= desiredY + desiredHeight - limits.bottom() + edges.bottom;
        }
        if (desiredY < limits.top()) {
            desiredY = limits.origin.y + edges.top;
        }

        final offset = new Point(MathUtil.round(desiredX - bounds.origin.x), MathUtil.round(desiredY - bounds.origin.y));

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

    /**
     * Rust `AnchoredPositionMode::get_position_and_bounds` (the position).
     */
    static function getPosition(mode:AnchoredPositionMode, anchorPosition:Null<Point>, bounds:Bounds):Point {
        return switch mode {
            case AnchoredPositionMode.Window:
                anchorPosition != null ? anchorPosition : bounds.origin;
            case AnchoredPositionMode.Local:
                anchorPosition != null ? anchorPosition : new Point(0, 0);
        }
    }

    /**
     * Rust `AnchoredPositionMode::get_position_and_bounds` (the bounds).
     */
    static function getBounds(mode:AnchoredPositionMode, anchorPosition:Null<Point>, anchor:Anchor, size:Size, bounds:Bounds, offset:Null<Point>):Bounds {
        final offset = offset != null ? offset : new Point(0, 0);
        final anchorPosition = getPosition(mode, anchorPosition, bounds);

        return switch mode {
            case AnchoredPositionMode.Window:
                Bounds.fromAnchorAndSize(anchor, anchorPosition.add(offset), size);
            case AnchoredPositionMode.Local:
                Bounds.fromAnchorAndSize(anchor, bounds.origin.add(anchorPosition).add(offset), size);
        }
    }

}
