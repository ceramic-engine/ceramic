package ceramic;

import ceramic.ScrollDirection;
import ceramic.Scroller;

class ScrollView extends View {

/// Properties

    public var scroller:Scroller;

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

    public var contentSize(default,set):Float = -1;
    inline function set_contentSize(contentSize:Float):Float {
        if (this.contentSize == contentSize) return contentSize;
        contentSize = Math.max(0, contentSize);
        this.contentSize = contentSize;
        layoutDirty = true;
        return contentSize;
    }

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
     * between each page.
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
     * is equal or above it.
     * If kept to `-1` (default), it will use the page size.
     */
    public var pageMomentumThreshold(get,set):Float;
    inline function get_pageMomentumThreshold():Float {
        return scroller.pageMomentumThreshold;
    }
    inline function set_pageMomentumThreshold(pageMomentumThreshold:Float):Float {
        return scroller.pageMomentumThreshold = pageMomentumThreshold;
    }

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        initContentView();
        initScroller();

    }

    function initContentView() {

        contentView = new View();
        contentView.customParentView = this;

    }

    function initScroller() {

        scroller = new Scroller(contentView);
        add(scroller);

    }

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
