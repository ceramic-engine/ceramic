package elements;

import ceramic.Filter;
import ceramic.LayoutAlign;
import ceramic.View;
import ceramic.ViewLayoutMask;
import ceramic.Visual;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

/**
 * A view container that displays and manages a single visual element with scaling and filtering options.
 * 
 * This class provides a wrapper view for displaying visual elements with various scaling modes,
 * content alignment options, and optional filter effects. It handles the lifecycle of the
 * contained visual and can automatically destroy it when removed.
 * 
 * ## Features
 * 
 * - Multiple scaling modes: FIT, FILL, CUSTOM
 * - Content alignment control
 * - Optional filter effects
 * - Automatic visual lifecycle management
 * - Configurable destruction behavior
 * 
 * ## Scaling Modes
 * 
 * - `FIT`: Scales the visual to fit within the container while maintaining aspect ratio
 * - `FILL`: Stretches the visual to completely fill the container
 * - `CUSTOM`: Uses a manually specified scale value
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Create a container with a visual
 * var container = new VisualContainerView();
 * container.visual = mySprite;
 * container.scaling = VisualContainerViewScaling.FIT;
 * container.contentAlign = CENTER;
 * 
 * // Add a filter effect
 * var filter = new Filter();
 * container.filter = filter;
 * 
 * // Custom scaling
 * container.scaling = VisualContainerViewScaling.CUSTOM;
 * container.visualScale = 2.0; // 200% scale
 * ```
 * 
 * @see VisualContainerViewScaling
 * @see Filter
 * @see Visual
 * @see LayoutAlign
 */
class VisualContainerView extends View implements Observable {

/// Public properties

    /**
     * Whether to automatically destroy the visual when it's removed from this container.
     * When true, the visual will be destroyed when replaced or when the container is cleared.
     * When false, the visual will only be deactivated but not destroyed.
     * 
     * @default true
     */
    public var destroyVisualOnRemove:Bool = true;

    /**
     * Whether to automatically destroy the filter when it's removed from this container.
     * When true, the filter will be destroyed when replaced or set to null.
     * When false, the filter will only be removed but not destroyed.
     * 
     * @default true
     */
    public var destroyFilterOnRemove:Bool = true;

    /**
     * Optional filter effect to apply to the contained visual.
     * 
     * When set, the visual is rendered through the filter, which can apply
     * various visual effects. The filter is automatically managed and can
     * be destroyed when replaced if destroyFilterOnRemove is true.
     * 
     * @see Filter
     */
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
     * Controls how the visual content is aligned within the container.
     * 
     * This property determines the positioning of the contained visual
     * when it doesn't fill the entire container space.
     * 
     * @default CENTER
     * @see LayoutAlign
     */
    @observe public var contentAlign:LayoutAlign = CENTER;

    /**
     * The scale factor to apply to the visual when using CUSTOM scaling mode.
     * 
     * This value is only used when the scaling property is set to CUSTOM.
     * In other scaling modes, the scale is automatically calculated.
     * 
     * @default 1.0
     * @see scaling
     */
    @observe public var visualScale:Float = 1.0;

    /**
     * Determines how the visual is scaled within the container.
     * 
     * - FIT: Scales the visual to fit within the container while maintaining aspect ratio
     * - FILL: Stretches the visual to completely fill the container (may distort aspect ratio)
     * - CUSTOM: Uses the manually specified visualScale value
     * 
     * @default FIT
     * @see VisualContainerViewScaling
     * @see visualScale
     */
    @observe public var scaling:VisualContainerViewScaling = VisualContainerViewScaling.FIT;

    /**
     * The visual element to display within this container.
     * 
     * When set, the visual is added to the container (or filter content if a filter is active)
     * and its lifecycle is managed according to the destroyVisualOnRemove setting.
     * The visual is automatically activated when added and positioned according to the
     * current scaling and alignment settings.
     * 
     * @see destroyVisualOnRemove
     * @see filter
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

    /**
     * The computed scale value for FIT scaling mode.
     * This is calculated automatically based on the container and visual dimensions.
     * @private
     */
    var computedVisualScale:Float = 1.0;

/// Lifecycle

    /**
     * Creates a new visual container view.
     * 
     * Initializes the container with default settings and sets up automatic
     * visual scale updates when properties change.
     */
    public function new() {

        super();

        autorun(updateVisualScale);

    }

    /**
     * Clears the container by removing the visual and calling the parent clear method.
     * 
     * This will destroy the visual if destroyVisualOnRemove is true,
     * or simply deactivate it if false.
     */
    override function clear() {

        visual = null;

        super.clear();

    }

    /**
     * Updates the visual's scale based on the current scaling mode.
     * 
     * Calculates and applies the appropriate scale factor based on the scaling mode:
     * - CUSTOM: Uses the visualScale property
     * - FIT: Uses the computed scale to fit within the container
     * - FILL: Scale is handled in layout() for stretching
     * 
     * @private
     */
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

    /**
     * Computes the size of the container and calculates the visual scale for FIT mode.
     * 
     * This method is called during layout to determine the container's size and
     * calculate the appropriate scale factor for the contained visual when using FIT scaling.
     * 
     * @param parentWidth Available width from the parent
     * @param parentHeight Available height from the parent
     * @param layoutMask Layout constraints mask
     * @param persist Whether to persist the computed values
     * @private
     */
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

    /**
     * Performs layout of the container's elements.
     * 
     * Positions and sizes the filter (if present) and the visual element.
     * For FILL scaling mode, applies separate X and Y scaling to stretch
     * the visual to completely fill the available space.
     * 
     * @private
     */
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
