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
    /**
     * The area the widget is placed in (Monaco's page): null for the
     * window, the editor's bounds with the Cityscape option
     * `overflowWidgetsBounds: 'editor'` (see `EditorWidgets.overflowPage`),
     * the widget then never leaving them.
     */
    @:optional var page:Null<Bounds>;
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
 * The window is Monaco's page; with `anchors.page` (the editor, Cityscape's
 * `overflowWidgetsBounds: 'editor'`) that area takes its place in every
 * rule, the boxes are kept inside it and what is still larger is clipped.
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

    // Elements laid out with the widget but placed by a callback against it
    // (the suggest widget's details next to its list)
    final attachedElements:Array<AnyElement> = [];
    final attachedPlacers:Array<(widget:Bounds, size:Size) -> Point> = [];
    final attachedLayoutIds:Array<LayoutId> = [];

    var beforeRenderSize:Null<Size> = null;

    /**
     * `above`: the `hover.above` option (Monaco's preference when there is
     * room on both sides).
     */
    public function new(anchors:ContentWidgetAnchors, above:Bool) {
        this.anchors = anchors;
        this.above = above;
    }

    // Parameter hints (step 7, cs7-rest-snip): a list of preferences
    var preferenceList:Null<Array<ContentWidgetPositionPreference>> = null;

    /**
     * Places the widget like a content widget of Monaco with these
     * preferences (`IContentWidgetPosition.preference`, `ABOVE` or
     * `BELOW`) instead of the hover's rule: `_prepareRenderWidget`'s
     * first pass takes the first side where the widget fits
     * (`_layoutBoxInPage`: 22 pixels from the top or the bottom of the
     * window), its second pass the first preference.
     */
    public function preferences(list:Array<ContentWidgetPositionPreference>):ContentWidgetPositioner {
        preferenceList = list;
        return this;
    }

    /**
     * `_prepareRenderWidget` with `_layoutBoxInPage` for a widget of
     * `height` (the side only; `place` gives the box).
     */
    public static function preferredSide(preferences:Array<ContentWidgetPositionPreference>, widgetHeight:Float, primary:Bounds, page:Bounds):ContentWidgetPositionPreference {
        // Leave some clearance to the top/bottom
        final TOP_PADDING = 22;
        final BOTTOM_PADDING = 22;
        // positions in the page (the window, or the editor)
        final absoluteAboveTop = primary.origin.y - page.origin.y - widgetHeight;
        final absoluteBelowTop = primary.origin.y - page.origin.y + primary.size.height;
        final fitsAbove = (absoluteAboveTop >= TOP_PADDING);
        final fitsBelow = (absoluteBelowTop + widgetHeight <= page.size.height - BOTTOM_PADDING);
        // Do two passes, first for perfect fit, second picks first option
        for (pass in 1...3) {
            for (pref in preferences) {
                if (pref == ABOVE && (pass == 2 || fitsAbove)) {
                    return ABOVE;
                }
                if (pref == BELOW && (pass == 2 || fitsBelow)) {
                    return BELOW;
                }
            }
        }
        return BELOW;
    }

    /**
     * The size the widget is placed with (Monaco's `IContentWidget.beforeRender`
     * result, `_cachedDomNodeOffsetWidth/Height`) instead of its laid out
     * size. The widget is still drawn at its laid out size, from the top
     * left corner of the box found for this size.
     */
    public function beforeRender(size:Size):ContentWidgetPositioner {
        beforeRenderSize = size;
        return this;
    }

    /**
     * Adds an element laid out with the widget (at its natural size, out of
     * the flow) but placed by `place`, which gets the window bounds of the
     * widget once placed and the laid out size of the element and returns
     * the window position of the element (an overlay widget anchored on a
     * content widget, like the suggest widget's details).
     */
    public function attach(child:IntoElement, place:(widget:Bounds, size:Size) -> Point):ContentWidgetPositioner {
        if (child != null) {
            attachedElements.push(child);
            attachedPlacers.push(place);
        }
        return this;
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
     * The page of a content widget: `anchors.page`, else the window.
     */
    public static function pageOf(anchors:ContentWidgetAnchors, windowSize:Size):Bounds {
        final page = anchors.page;
        return page != null ? page : new Bounds(new Point(0, 0), windowSize);
    }

    /**
     * `_availableVerticalSpaceAbove`: from the top of the page (the window,
     * or the editor) to the line, less `TOP_HEIGHT`.
     */
    public static function availableVerticalSpaceAbove(primary:Bounds, page:Bounds):Float {
        return primary.origin.y - page.origin.y - TOP_HEIGHT;
    }

    /**
     * `_availableVerticalSpaceBelow`: from the bottom of the line to the
     * bottom of the page, less `BOTTOM_HEIGHT`.
     */
    public static function availableVerticalSpaceBelow(primary:Bounds, page:Bounds):Float {
        final mouseBottom = primary.origin.y - page.origin.y + primary.size.height;
        return page.size.height - mouseBottom - BOTTOM_HEIGHT;
    }

    /**
     * `_findPositionPreference`.
     */
    public static function findPositionPreference(widgetHeight:Float, primary:Bounds, page:Bounds, above:Bool):ContentWidgetPositionPreference {
        final maxHeightBelow = Math.min(availableVerticalSpaceBelow(primary, page), widgetHeight);
        final maxHeightAbove = Math.min(availableVerticalSpaceAbove(primary, page), widgetHeight);
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
    public static function place(anchors:ContentWidgetAnchors, size:Size, page:Bounds, preference:ContentWidgetPositionPreference):Bounds {
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
        final minLimit = Math.max(page.origin.x + LEFT_PADDING, editor.origin.x - width);
        final maxLimit = Math.min(editor.origin.x + editor.size.width + width, page.origin.x + page.size.width - RIGHT_PADDING);
        var absoluteLeft = left;
        if (absoluteLeft + width > maxLimit) {
            absoluteLeft -= absoluteLeft - (maxLimit - width);
        }
        if (absoluteLeft < minLimit) {
            absoluteLeft -= absoluteLeft - minLimit;
        }

        // _layoutBoxInPage: aboveTop, belowTop
        var top = preference == BELOW ? primary.origin.y + primary.size.height : primary.origin.y - height;

        // `overflowWidgetsBounds: 'editor'`: kept inside the editor (over
        // the line when the room on its side is too small; what is still
        // too large is clipped when painted)
        if (anchors.page != null) {
            final page = anchors.page;
            absoluteLeft = Math.max(page.origin.x, Math.min(absoluteLeft, page.origin.x + page.size.width - width));
            top = Math.max(page.origin.y, Math.min(top, page.origin.y + page.size.height - height));
        }
        return new Bounds(new Point(absoluteLeft, top), size);
    }

    /**
     * The highest a widget placed by `findPositionPreference` can be inside
     * the page: the room on the larger side (used to cap the widgets with
     * `overflowWidgetsBounds: 'editor'`).
     */
    public static function maxHeightInPage(primary:Bounds, page:Bounds):Float {
        return Math.max(0, Math.max(availableVerticalSpaceAbove(primary, page), availableVerticalSpaceBelow(primary, page)));
    }

    /**
     * The highest a widget placed by `preferences` (`_layoutBoxInPage`, 22
     * pixels of clearance) can be inside the page: the room on the larger
     * side.
     */
    public static function maxHeightInPageWithPreferences(primary:Bounds, page:Bounds):Float {
        final above = primary.origin.y - page.origin.y - 22;
        final below = page.origin.y + page.size.height - (primary.origin.y + primary.size.height) - 22;
        return Math.max(0, Math.max(above, below));
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        childLayoutIds.resize(0);
        for (child in childElements) {
            childLayoutIds.push(child.requestLayout(window, cx));
        }
        attachedLayoutIds.resize(0);
        for (child in attachedElements) {
            attachedLayoutIds.push(child.requestLayout(window, cx));
        }
        final style = new Style();
        style.position = Position.Absolute;
        style.display = Display.Flex;
        if (attachedLayoutIds.length == 0) {
            return window.requestLayout(style, childLayoutIds, cx);
        }
        // each element at its natural height (no stretch to the tallest)
        style.alignItems = glaze.AlignItems.FlexStart;
        style.optionMask |= glaze.StyleRefinement.ALIGN_ITEMS;
        return window.requestLayout(style, childLayoutIds.concat(attachedLayoutIds), cx);
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
        final page = pageOf(anchors, window.viewportSize());
        final placementSize = beforeRenderSize != null ? beforeRenderSize : size;
        final preference = preferenceList != null ? preferredSide(preferenceList, placementSize.height, anchors.primary, page) : findPositionPreference(placementSize.height, anchors.primary, page, above);
        final box = place(anchors, placementSize, page, preference);
        final placed = beforeRenderSize != null ? new Bounds(box.origin, size) : box;
        if (onPlacementCallback != null) {
            onPlacementCallback(new ContentWidgetPlacement(placed, preference));
        }
        // `overflowWidgetsBounds: 'editor'`: nothing shows or takes the
        // mouse outside the editor
        final page = anchors.page;
        if (page == null) {
            prepaintChildren(placed, bounds, window, cx);
        }
        else {
            window.withContentMask(new glaze.ContentMask(page), window -> {
                prepaintChildren(placed, bounds, window, cx);
                return null;
            });
        }
    }

    function prepaintChildren(placed:Bounds, bounds:Bounds, window:Window, cx:App):Void {
        window.insertHitbox(clip(placed), HitboxBehavior.BlockMouse);
        final offset = new Point(glaze.util.MathUtil.round(placed.origin.x - bounds.origin.x), glaze.util.MathUtil.round(placed.origin.y - bounds.origin.y));
        window.withElementOffset(offset, window -> {
            for (child in childElements) {
                child.prepaint(window, cx);
            }
            return null;
        });
        for (i in 0...attachedElements.length) {
            final childBounds = window.layoutBounds(attachedLayoutIds[i]);
            // kept inside the editor like the widget (`overflowWidgetsBounds: 'editor'`)
            final origin = keepInPage(attachedPlacers[i](placed, childBounds.size), childBounds.size, anchors.page);
            window.insertHitbox(clip(new Bounds(origin, childBounds.size)), HitboxBehavior.BlockMouse);
            final childOffset = new Point(glaze.util.MathUtil.round(origin.x - childBounds.origin.x), glaze.util.MathUtil.round(origin.y - childBounds.origin.y));
            final child = attachedElements[i];
            window.withElementOffset(childOffset, window -> {
                child.prepaint(window, cx);
                return null;
            });
        }
    }

    /**
     * `origin` moved so that a box of `size` stays inside `page` (as far as
     * it can: its top left corner wins), unchanged without page.
     */
    public static function keepInPage(origin:Point, size:Size, page:Null<Bounds>):Point {
        if (page == null) {
            return origin;
        }
        return new Point(
            Math.max(page.origin.x, Math.min(origin.x, page.origin.x + page.size.width - size.width)),
            Math.max(page.origin.y, Math.min(origin.y, page.origin.y + page.size.height - size.height))
        );
    }

    /**
     * The part of `b` inside the page when it is the editor's.
     */
    function clip(b:Bounds):Bounds {
        final page = anchors.page;
        if (page == null) {
            return b;
        }
        final left = Math.max(b.origin.x, page.origin.x);
        final top = Math.max(b.origin.y, page.origin.y);
        final right = Math.min(b.origin.x + b.size.width, page.origin.x + page.size.width);
        final bottom = Math.min(b.origin.y + b.size.height, page.origin.y + page.size.height);
        return new Bounds(new Point(left, top), new Size(Math.max(0, right - left), Math.max(0, bottom - top)));
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final page = anchors.page;
        if (page == null) {
            paintChildren(window, cx);
        }
        else {
            window.withContentMask(new glaze.ContentMask(page), window -> {
                paintChildren(window, cx);
                return null;
            });
        }
    }

    function paintChildren(window:Window, cx:App):Void {
        for (child in childElements) {
            child.paint(window, cx);
        }
        for (child in attachedElements) {
            child.paint(window, cx);
        }
    }

}
