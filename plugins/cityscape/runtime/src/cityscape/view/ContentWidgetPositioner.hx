// Ported from vscode src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts
// (the placement of a content widget that may overflow the editor:
// `_layoutBoxInPage`, `_layoutHorizontalSegmentInPage`,
// `_reduceAnchorCoordinates`, `_prepareRenderWidget`) and
// src/vs/editor/contrib/hover/browser/resizableContentWidget.ts (the side
// of the hover: `_availableVerticalSpaceAbove`, `_availableVerticalSpaceBelow`,
// `_findPositionPreference`)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Display;
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

/**
 * Monaco's `ContentWidgetPositionPreference` (the ones a hover uses).
 */
enum abstract ContentWidgetPositionPreference(Int) {
    /** Place the content widget exactly at a position. */
    var EXACT = 0;
    /** Place the content widget above a position. */
    var ABOVE = 1;
    /** Place the content widget below a position. */
    var BELOW = 2;
}

/**
 * Where a content widget ended up (window coordinates) and on which side.
 */
class ContentWidgetPlacement {

    public final bounds:Bounds;
    public final preference:ContentWidgetPositionPreference;

    public function new(bounds:Bounds, preference:ContentWidgetPositionPreference) {
        this.bounds = bounds;
        this.preference = preference;
    }

}

/**
 * What a content widget is placed against, in window coordinates: the line
 * boxes of its primary and secondary positions (Monaco's anchors), the
 * editor's bounds and the editor's typical full width character width.
 */
typedef ContentWidgetAnchors = {
    /** The line box of the primary position (`showAtPosition`). */
    var primary:Bounds;
    /** The line box of the secondary position (`showAtSecondaryPosition`), on the line of the primary one, or null. */
    var secondary:Null<Bounds>;
    /** The window bounds of the editor (Monaco's view DOM node). */
    var editor:Bounds;
    var typicalFullwidthCharacterWidth:Float;
}

/**
 * Places a content widget that may leave the editor (`allowEditorOverflow`,
 * like the hover) next to its anchors once its size is known, like Monaco:
 *
 * - the side: `resizableContentWidget.ts` `_findPositionPreference`, from the
 *   room above (the line's top minus 30 pixels) and below (the window's
 *   height minus the line's bottom minus 24 pixels) and the `above`
 *   preference (the `hover.above` option): above when it fits there (or
 *   below when `above` is false and it fits below), else the other side;
 * - the box: `contentWidgets.ts` `_prepareRenderWidget` with a single
 *   preference, so the widget always takes that side (its second pass):
 *   right above the line (its bottom on the line's top) or right below it,
 *   its left on the secondary anchor kept within a widget's width of the
 *   primary one (`_reduceAnchorCoordinates`), then kept 15 pixels from the
 *   window's sides and within a widget's width of the editor
 *   (`_layoutHorizontalSegmentInPage`).
 *
 * Children are laid out like the kit's `Positioner` (out of the flow, at
 * their natural size) and blocked from the mouse behind them.
 */
class ContentWidgetPositioner extends Element implements ParentElement {

    /** resizableContentWidget.ts `TOP_HEIGHT` */
    public static inline final TOP_HEIGHT = 30;
    /** resizableContentWidget.ts `BOTTOM_HEIGHT` */
    public static inline final BOTTOM_HEIGHT = 24;
    /** contentWidgets.ts `_layoutHorizontalSegmentInPage` clearances */
    public static inline final LEFT_PADDING = 15;
    public static inline final RIGHT_PADDING = 15;

    final anchors:ContentWidgetAnchors;
    final above:Bool;
    var onPlacementCallback:Null<(placement:ContentWidgetPlacement) -> Void> = null;

    final childElements:Array<AnyElement> = [];
    final childLayoutIds:Array<LayoutId> = [];

    /**
     * `above`: the `hover.above` option (Monaco's preference when there is
     * room on both sides).
     */
    public function new(anchors:ContentWidgetAnchors, above:Bool) {
        this.anchors = anchors;
        this.above = above;
    }

    /**
     * Called with the placement before the children prepaint.
     */
    public function onPlacement(callback:(placement:ContentWidgetPlacement) -> Void):ContentWidgetPositioner {
        onPlacementCallback = callback;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) {
            childElements.push(element);
        }
    }

    public function child(child:IntoElement):ContentWidgetPositioner {
        if (child != null) childElements.push(child);
        return this;
    }

    /**
     * `_availableVerticalSpaceAbove`: from the top of the window (Monaco's
     * page) to the line, less `TOP_HEIGHT`.
     */
    public static function availableVerticalSpaceAbove(primary:Bounds):Float {
        return primary.origin.y - TOP_HEIGHT;
    }

    /**
     * `_availableVerticalSpaceBelow`: from the bottom of the line to the
     * bottom of the window, less `BOTTOM_HEIGHT`.
     */
    public static function availableVerticalSpaceBelow(primary:Bounds, windowHeight:Float):Float {
        final mouseBottom = primary.origin.y + primary.size.height;
        return windowHeight - mouseBottom - BOTTOM_HEIGHT;
    }

    /**
     * `_findPositionPreference`.
     */
    public static function findPositionPreference(widgetHeight:Float, primary:Bounds, windowHeight:Float, above:Bool):ContentWidgetPositionPreference {
        final maxHeightBelow = Math.min(availableVerticalSpaceBelow(primary, windowHeight), widgetHeight);
        final maxHeightAbove = Math.min(availableVerticalSpaceAbove(primary), widgetHeight);
        final maxHeight = Math.min(Math.max(maxHeightAbove, maxHeightBelow), widgetHeight);
        final height = Math.min(widgetHeight, maxHeight);
        if (above) {
            return height <= maxHeightAbove ? ABOVE : BELOW;
        }
        return height <= maxHeightBelow ? BELOW : ABOVE;
    }

    /**
     * The window bounds of a widget of `size` (`_reduceAnchorCoordinates`,
     * `_layoutBoxInPage`, `_layoutHorizontalSegmentInPage`, then the side).
     */
    public static function place(anchors:ContentWidgetAnchors, size:Size, windowSize:Size, preference:ContentWidgetPositionPreference):Bounds {
        final width = size.width;
        final height = size.height;
        final primary = anchors.primary;

        // _reduceAnchorCoordinates
        var left = primary.origin.x;
        final secondary = anchors.secondary;
        if (secondary != null) {
            left = secondary.origin.x;
            if (left < primary.origin.x) {
                left = Math.max(left, primary.origin.x - width + anchors.typicalFullwidthCharacterWidth);
            }
            else {
                left = Math.min(left, primary.origin.x + width - anchors.typicalFullwidthCharacterWidth);
            }
        }

        // _layoutHorizontalSegmentInPage
        final editor = anchors.editor;
        final minLimit = Math.max(LEFT_PADDING, editor.origin.x - width);
        final maxLimit = Math.min(editor.origin.x + editor.size.width + width, windowSize.width - RIGHT_PADDING);
        var absoluteLeft = left;
        if (absoluteLeft + width > maxLimit) {
            absoluteLeft -= absoluteLeft - (maxLimit - width);
        }
        if (absoluteLeft < minLimit) {
            absoluteLeft -= absoluteLeft - minLimit;
        }

        // _layoutBoxInPage: aboveTop, belowTop
        final top = preference == BELOW ? primary.origin.y + primary.size.height : primary.origin.y - height;
        return new Bounds(new Point(absoluteLeft, top), size);
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
        var minX = Math.POSITIVE_INFINITY;
        var minY = Math.POSITIVE_INFINITY;
        var maxX = 0.0;
        var maxY = 0.0;
        for (childLayoutId in childLayoutIds) {
            final childBounds = window.layoutBounds(childLayoutId);
            minX = Math.min(minX, childBounds.origin.x);
            minY = Math.min(minY, childBounds.origin.y);
            maxX = Math.max(maxX, childBounds.origin.x + childBounds.size.width);
            maxY = Math.max(maxY, childBounds.origin.y + childBounds.size.height);
        }
        final size = new Size(maxX - minX, maxY - minY);
        final windowSize = window.viewportSize();
        final preference = findPositionPreference(size.height, anchors.primary, windowSize.height, above);
        final placed = place(anchors, size, windowSize, preference);
        if (onPlacementCallback != null) {
            onPlacementCallback(new ContentWidgetPlacement(placed, preference));
        }
        window.insertHitbox(placed, HitboxBehavior.BlockMouse);
        final offset = new Point(glaze.util.MathUtil.round(placed.origin.x - bounds.origin.x), glaze.util.MathUtil.round(placed.origin.y - bounds.origin.y));
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

}
