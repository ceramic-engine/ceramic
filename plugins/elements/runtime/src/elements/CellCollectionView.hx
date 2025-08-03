package elements;

import ceramic.CollectionView;
import ceramic.Filter;
import ceramic.Scroller;
import ceramic.Shortcuts.*;
import elements.Context.context;
import elements.Scrollbar;
import tracker.Autorun.unobserve;
import tracker.Observable;

/**
 * A themed collection view for displaying cells with built-in scrolling and filtering.
 * 
 * This collection view extends the base CollectionView with additional features:
 * - Theme support with automatic styling based on the current theme
 * - Built-in scrollbar with custom styling
 * - Render filtering for pixel-perfect rendering at native screen density
 * - Border styling that adapts to input-style vs regular display mode
 * - Automatic detection of scrolling state
 * 
 * The view uses a Filter to ensure crisp rendering at the device's native pixel density,
 * which is particularly important for text-heavy cell content.
 * 
 * @see CollectionView
 * @see Scrollbar
 * @see Theme
 */
class CellCollectionView extends CollectionView implements Observable {

    /**
     * The theme to use for styling this collection view.
     * If null, uses the global context theme.
     */
    @observe public var theme:Theme = null;

    /**
     * Whether the collection view is currently being scrolled.
     * This is automatically updated based on the scroller status.
     */
    @observe public var scrolling(default,null):Bool = false;

    /**
     * When true, applies input-style theming with different border configuration.
     * Input style typically has lighter borders and transparent background.
     */
    @observe public var inputStyle:Bool = false;

    /**
     * Filter used to render content at native screen density.
     */
    var filter:Filter;

    /**
     * Creates a new CellCollectionView instance.
     * 
     * Initializes the view with:
     * - Full parent size (fill)
     * - Native density filtering for crisp rendering
     * - Custom scrollbar with theme support
     * - Automatic border depth management
     * - Platform-specific drag behavior (disabled on desktop)
     */
    public function new() {

        super();

        filter = new Filter();
        filter.density = screen.nativeDensity;
        add(filter);

        viewSize(fill(), fill());
        transparent = false;
        contentView.transparent = true;
        contentView.borderPosition = OUTSIDE;
        borderPosition = INSIDE;
        scroller.allowPointerOutside = false;
        var scrollbar = new Scrollbar();
        scroller.scrollbar = scrollbar;
        scrollbar.autorun(() -> {
            var theme = this.theme;
            unobserve();
            scrollbar.theme = theme;
        });
        filter.textureFilter = NEAREST;
        filter.content.add(scroller);

        #if !(ios || android)
        scroller.dragEnabled = false;
        #end

        contentView.onLayout(this, updateBorderDepth);

        autorun(updateStyle);

        app.onUpdate(this, handleUpdate);

    }

    /**
     * Updates the filter density and scrolling state.
     * Called every frame to ensure the filter matches the current screen density
     * and to track whether scrolling is active.
     * 
     * @param delta Time elapsed since last frame (not used)
     */
    function handleUpdate(delta:Float) {

        filter.density = screen.nativeDensity;
        scrolling = (scroller.status != IDLE);

    }

    /**
     * Positions and sizes the filter to match the collection view dimensions.
     * Also handles nested scroller detection to prevent filter conflicts.
     */
    override function layout() {

        filter.pos(0, 0);
        filter.size(width, height);

        // Prevent nested filters messing scroll events
        // TODO: find a better solution?
        if (firstParentWithClass(Scroller) != null) {
            filter.enabled = false;
            clip = this;
        }
        else {
            filter.enabled = true;
            clip = null;
        }

        super.layout();

    }

    /**
     * Updates the border rendering depth to ensure it appears above all cell content.
     * Called whenever the content view layout changes.
     */
    function updateBorderDepth() {

        borderDepth = contentView.children.length + 10;

    }

    /**
     * Updates the visual styling based on the current theme and inputStyle setting.
     * 
     * In input style mode:
     * - Transparent background
     * - Light border colors
     * - Borders on top and bottom
     * 
     * In regular mode:
     * - Dark background color from theme
     * - Medium border color
     * - Border only on top of content
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (inputStyle) {
            transparent = true;
            contentView.borderTopSize = 1;
            borderBottomSize = 1;
            borderTopSize = 1;
            borderBottomColor = theme.lightBorderColor;
        }
        else {
            transparent = false;
            color = theme.darkBackgroundColor;
            borderSize = 0;
            contentView.borderTopSize = 1;
            borderBottomSize = 0;
            borderTopSize = 0;
            borderBottomColor = theme.mediumBorderColor;
        }

        contentView.borderTopColor = theme.mediumBorderColor;
        contentView.borderBottomColor = theme.mediumBorderColor;

    }

}
