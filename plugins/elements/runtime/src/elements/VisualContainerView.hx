package elements;

import ceramic.Filter;
import ceramic.LayoutAlign;
import ceramic.View;
import ceramic.ViewLayoutMask;
import ceramic.Visual;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

class VisualContainerView extends View implements Observable {

/// Public properties

    public var destroyVisualOnRemove:Bool = true;

    public var destroyFilterOnRemove:Bool = true;

    public var filter(default, set):Filter = null;
    function set_filter(filter:Filter):Filter {
        if (this.filter != filter) {
            var visual = this.visual;
            if (this.filter != null) {
                var filterContent = filter.content;
                if (visual != null && visual.parent == filterContent) {
                    filterContent.remove(visual);
                }
                if (destroyFilterOnRemove) {
                    this.filter.destroy();
                }
                else if (this.filter.parent == this) {
                    remove(this.filter);
                }
                this.filter = null;
            }
            this.filter = filter;
            if (filter != null) {

                var filterContent = filter.content;
                if (visual != null && visual.parent != filterContent) {
                    filterContent.add(visual);
                }

                add(filter);
            }
            else {
                if (visual != null && visual.parent != this) {
                    add(visual);
                }
            }
            layoutDirty = true;
        }
        return filter;
    }

    /**
     * Content alignment
     * TODO use it
     */
    @observe public var contentAlign:LayoutAlign = CENTER;

    /**
     * Visual scale (ignored unless `scaling` is `CUSTOM`)
     */
    @observe public var visualScale:Float = 1.0;

    /**
     * How the visual is scaled depending on its constraints
     */
    @observe public var scaling:VisualContainerViewScaling = VisualContainerViewScaling.FIT;

    /**
     * The actual visual to display
     */
    @observe public var visual(default,set):Visual = null;
    function set_visual(visual:Visual):Visual {
        if (this.visual != visual || (visual != null && visual.parent != this)) {
            var prevVisual = this.visual;
            if (prevVisual != null && prevVisual != visual) {
                if (prevVisual.parent == this || (filter != null && prevVisual.parent == filter.content)) {
                    prevVisual.parent.remove(prevVisual);
                    if (destroyVisualOnRemove) {
                        prevVisual.destroy();
                    }
                    else {
                        prevVisual.active = false;
                    }
                }
            }
            this.visual = visual;
        }
        if (visual != null) {
            var visualParent:Visual = filter != null ? filter.content : this;
            if (visual.parent != visualParent) {
                visualParent.add(visual);
                layoutDirty = true;
            }
            visual.active = true;
        }
        return visual;
    }

/// Internal

    var computedVisualScale:Float = 1.0;

/// Lifecycle

    public function new() {

        super();

        autorun(updateVisualScale);

    }

    override function clear() {

        visual = null;

        super.clear();

    }

    function updateVisualScale() {

        var scaling = this.scaling;
        var visualScale = this.visualScale;

        var scale = switch scaling {
            case CUSTOM: visualScale;
            case FIT: computedVisualScale;
            case FILL: 1.0;
        }

        var visual = this.visual;

        unobserve();

        if (visual != null && scaling != FILL) {
            visual.scale(scale);
        }

        reobserve();

    }

/// Layout

    override function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool) {

        super.computeSize(parentWidth, parentHeight, layoutMask, persist);

        if (visual != null) {
            computedVisualScale = computeSizeWithIntrinsicBounds(
                parentWidth, parentHeight, layoutMask, persist, visual.width, visual.height
            );
        }
        else {
            computedVisualScale = 1.0;
        }

        updateVisualScale();

    }

    override function layout() {

        var availableWidth = width - paddingLeft - paddingRight;
        var availableHeight = height - paddingTop - paddingBottom;

        if (filter != null) {
            filter.pos(0, 0);
            filter.size(width, height);
        }

        if (visual != null) {

            visual.anchor(0.5, 0.5);
            visual.pos(
                paddingLeft + availableWidth * 0.5,
                paddingTop + availableHeight * 0.5
            );

            var visualWidth = visual.width;
            var visualHeight = visual.height;
            if (visualWidth > 0 && visualHeight > 0) {
                switch (scaling) {
                    case FILL:
                        visual.scale(
                            availableWidth / visualWidth,
                            availableHeight / visualHeight
                        );

                    default:
                        // Nothing to do
                }
            }
        }

    }

}
