package elements;

import ceramic.Filter;
import ceramic.ScrollView;
import ceramic.Shortcuts.*;
import ceramic.View;
import ceramic.ViewLayoutMask;
import elements.Context.context;
import tracker.Observable;

/**
 * A scrollable container that wraps a layout view with optional filtering and borders.
 * 
 * ScrollingLayout provides a scrollable viewport for any layout view, with additional
 * features like density-aware filtering, automatic scrolling bounds management, and
 * optional view culling for performance optimization.
 * 
 * Key features:
 * - Generic layout view support (any View subclass)
 * - Automatic content sizing and scroll bounds
 * - Optional border rendering
 * - View culling for large lists (via checkChildrenOfView)
 * - Platform-specific scroll behavior (touch vs desktop)
 * 
 * Usage example:
 * ```haxe
 * var layout = new ColumnLayout();
 * var scrollingLayout = new ScrollingLayout(layout, true); // with borders
 * scrollingLayout.size(300, 200);
 * scrollingLayout.checkChildrenOfView = layout; // enable view culling
 * add(scrollingLayout);
 * ```
 */
class ScrollingLayout<T:View> extends ScrollView implements Observable {

    /** Custom theme override for this scrolling layout. If null, uses the global context theme */
    @observe public var theme:Theme = null;

    /** The wrapped layout view that provides the scrollable content */
    public var layoutView(default, null):T;

    /** 
     * Optional view whose children will be culled when outside the visible area.
     * 
     * When set, children of this view that are completely outside the scroll viewport
     * will have their visibility set to false for performance optimization. This is
     * particularly useful for large lists or grids.
     */
    public var checkChildrenOfView:View = null;

    /** Density-aware filter for crisp rendering at different screen densities */
    public var filter(default, null):Filter;

    /**
     * Creates a new ScrollingLayout wrapping the provided layout view.
     * 
     * @param layoutView The layout view to make scrollable
     * @param withBorders Whether to add visual borders (top border on content, bottom border on container)
     */
    public function new(layoutView:T, withBorders:Bool = false) {

        super();

        filter = new Filter();
        filter.density = screen.nativeDensity;
        add(filter);

        this.layoutView = layoutView;
        contentView.add(layoutView);

        viewSize(fill(), fill());
        transparent = true;
        contentView.transparent = true;
        //clip = this;
        scroller.allowPointerOutside = false;
        scroller.bounceMinDuration = 0;
        scroller.bounceDurationFactor = 0;
        filter.content.add(scroller);

        if (withBorders) {
            contentView.borderTopSize = 1;
            contentView.borderPosition = OUTSIDE;
            borderBottomSize = 1;
            borderPosition = INSIDE;
        }

        #if !(ios || android)
        scroller.dragEnabled = false;
        #end

        autorun(updateStyle);

        app.onPostUpdate(this, handlePostUpdate);

    }

    /**
     * Performs layout of the scrolling content and manages scroll bounds.
     * 
     * This method:
     * - Sizes the filter and scroller to match the container
     * - Computes the layout view size based on scroll direction
     * - Ensures scroll position stays within valid bounds
     * - Updates content view size to match layout view
     */
    override function layout() {

        filter.pos(0, 0);
        filter.size(width, height);

        scroller.pos(0, 0);
        scroller.size(width, height);

        // Needed on C# target
        var layoutView:View = cast this.layoutView;

        if (direction == VERTICAL) {
            layoutView.computeSize(width, height, ViewLayoutMask.INCREASE_HEIGHT, true);
            layoutView.size(layoutView.computedSize.computedWidth, Math.max(layoutView.computedSize.computedHeight, height));

            if (layoutView.computedSize.computedHeight - scroller.scrollY < height) {
                scroller.scrollY = layoutView.computedSize.computedHeight - height;
            }

        } else {
            layoutView.computeSize(width, height, ViewLayoutMask.INCREASE_WIDTH, true);
            layoutView.size(Math.max(layoutView.computedSize.computedWidth, width), layoutView.computedSize.computedHeight);

            if (layoutView.computedSize.computedWidth - scroller.scrollX < width) {
                scroller.scrollX = layoutView.computedSize.computedWidth - width;
            }
        }

        contentView.size(layoutView.width, layoutView.height);

        scroller.scrollToBounds();

    }

    /**
     * Handles post-update logic including view culling and density updates.
     * 
     * Updates the filter density for crisp rendering and performs view culling
     * if checkChildrenOfView is set. Views outside the visible scroll area
     * are hidden for performance.
     * 
     * @param delta Time delta since last update
     */
    function handlePostUpdate(delta:Float) {

        filter.density = screen.nativeDensity;

        if (checkChildrenOfView != null) {
            if (checkChildrenOfView.destroyed) {
                checkChildrenOfView = null;
                return;
            }
            var views = checkChildrenOfView.subviews;
            if (views == null)
                return;
            for (i in 0...views.length) {
                var view = views[i];
                if (!view.active)
                    continue;

                var viewY = view.y;
                var viewHeight = view.height;
                if (viewY + viewHeight < scroller.scrollY || viewY > height + scroller.scrollY) {
                    view.visible = false;
                }
                else {
                    view.visible = true;
                }
            }
        }

    }

    /**
     * Updates the visual style based on the current theme.
     * 
     * Currently only updates the border alpha for window-style borders.
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        borderAlpha = theme.windowBorderAlpha;

    }

}
