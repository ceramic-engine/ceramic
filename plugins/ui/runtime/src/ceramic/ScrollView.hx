package ceramic;

import ceramic.ScrollDirection;
import ceramic.Scroller;

/**
 * A view that provides scrolling functionality for content that exceeds its bounds.
 *
 * ScrollView wraps a Scroller component and manages a content view that can be
 * larger than the scroll view itself. It supports both horizontal and vertical
 * scrolling, with optional paging behavior.
 *
 * Key features:
 * - Horizontal or vertical scrolling
 * - Optional paging with configurable page size and spacing
 * - Momentum-based scrolling with customizable thresholds
 * - Automatic content size management
 *
 * @example
 * ```haxe
 * var scrollView = new ScrollView();
 * scrollView.viewSize(300, 400);
 * scrollView.contentSize = 800; // Content is taller than view
 * scrollView.direction = VERTICAL;
 *
 * // Add content to the contentView
 * var content = new View();
 * content.viewSize(300, 800);
 * content.size(300, 800);
 * scrollView.contentView.add(content);
 * ```
 *
 * @see Scroller The underlying scrolling component
 * @see PagerView For page-based scrolling with view recycling
 */
class ScrollView extends View {

/// Properties

    /**
     * The underlying Scroller component that handles touch interaction
     * and scroll physics. This is automatically created and managed.
     */
    public var scroller:Scroller;

    /**
     * The view that contains the scrollable content.
     * All scrollable items should be added as children to this view.
     * The content view is automatically sized based on contentSize and direction.
     */
    public var contentView(default,set):View;
    function set_contentView(contentView:View):View {
        if (this.contentView == contentView) return contentView;
        if (this.contentView != null && this.contentView.customParentView == this) {
            this.contentView.customParentView = null;
        }
        this.contentView = contentView;
        if (this.contentView != null) {
            this.contentView.customParentView = this;
        }
        return contentView;
    }

    /**
     * The size of the scrollable content in the scroll direction.
     * - For VERTICAL scrolling: sets the height of contentView
     * - For HORIZONTAL scrolling: sets the width of contentView
     * Values less than 0 are clamped to 0.
     * Default: -1 (uses view size)
     */
    public var contentSize(default,set):Float = -1;
    inline function set_contentSize(contentSize:Float):Float {
        if (this.contentSize == contentSize) return contentSize;
        contentSize = Math.max(0, contentSize);
        this.contentSize = contentSize;
        layoutDirty = true;
        return contentSize;
    }

    /**
     * The scroll direction (HORIZONTAL or VERTICAL).
     * This determines which axis is scrollable.
     */
    public var direction(get,set):ScrollDirection;
    inline function get_direction():ScrollDirection {
        return scroller.direction;
    }
    inline function set_direction(direction:ScrollDirection):ScrollDirection {
        return scroller.direction = direction;
    }

    /**
     * Enable paging of the scroller so that
     * everytime we stop dragging, it snaps to the closest page.
     * When enabled, the scroll view will snap to page boundaries
     * defined by pageSize.
     * Default: false
     */
    public var pagingEnabled(get,set):Bool;
    inline function get_pagingEnabled():Bool {
        return scroller.pagingEnabled;
    }
    inline function set_pagingEnabled(pagingEnabled:Bool):Bool {
        return scroller.pagingEnabled = pagingEnabled;
    }

    /**
     * When `pagingEnabled` is `true`, this is the size of a page.
     * If kept to `-1` (default), it will use the scroller size.
     * - For VERTICAL: page height
     * - For HORIZONTAL: page width
     * Default: -1 (uses view dimensions)
     */
    public var pageSize(get,set):Float;
    inline function get_pageSize():Float {
        return scroller.pageSize;
    }
    function set_pageSize(pageSize:Float):Float {
        return scroller.pageSize = pageSize;
    }

    /**
     * When `pagingEnabled` is `true`, this is the spacing
     * between each page. This adds extra space between pages
     * that is not part of the page content.
     * Default: 0
     */
    public var pageSpacing(get,set):Float;
    inline function get_pageSpacing():Float {
        return scroller.pageSpacing;
    }
    function set_pageSpacing(pageSpacing:Float):Float {
        return scroller.pageSpacing = pageSpacing;
    }

    /**
     * When `pagingEnabled` is `true`, this threshold value
     * will be used to move to a sibling page if the momentum
     * is equal or above it. Lower values make it easier to
     * flip between pages with small gestures.
     * If kept to `-1` (default), it will use the page size.
     * Default: -1
     */
    public var pageMomentumThreshold(get,set):Float;
    inline function get_pageMomentumThreshold():Float {
        return scroller.pageMomentumThreshold;
    }
    inline function set_pageMomentumThreshold(pageMomentumThreshold:Float):Float {
        return scroller.pageMomentumThreshold = pageMomentumThreshold;
    }

/// Lifecycle

    /**
     * Create a new ScrollView.
     * Automatically initializes the content view and scroller components.
     */
    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        initContentView();
        initScroller();

    }

    /**
     * Initialize the content view that will hold scrollable content.
     * Sets up the parent-child relationship for proper event handling.
     */
    function initContentView() {

        contentView = new View();
        contentView.customParentView = this;

    }

    /**
     * Initialize the scroller component with the content view.
     * The scroller handles all touch interaction and scrolling physics.
     */
    function initScroller() {

        scroller = new Scroller(contentView);
        add(scroller);

    }

    /**
     * Layout the scroll view components.
     * - Positions the scroller to fill the entire view
     * - Sizes the content view based on direction and contentSize
     * - Ensures content is at least as large as the view itself
     */
    override function layout() {

        scroller.pos(0, 0);
        scroller.size(width, height);

        if (direction == VERTICAL) {
            contentView.height = Math.max(height, contentSize);
        } else {
            contentView.width = Math.max(width, contentSize);
        }

    }

}
