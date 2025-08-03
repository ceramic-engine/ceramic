package elements;

import ceramic.Color;
import ceramic.ColumnLayout;
import ceramic.Quad;
import ceramic.ReadOnlyArray;
import elements.Context.context;
import elements.TabFocus;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using ceramic.Extensions;

/**
 * A specialized column layout designed for forms in the Elements UI framework.
 * 
 * FormLayout extends ColumnLayout to provide form-specific styling and behavior:
 * - Automatic background rendering for form sections
 * - Integrated tab focus navigation
 * - Theme-aware styling with proper spacing and padding
 * - Support for custom item backgrounds and window backgrounds
 * 
 * The layout automatically divides the form into three background sections:
 * - Top background (above first item)
 * - Individual item backgrounds (optional, between items)
 * - Bottom background (below last item)
 * 
 * @see ColumnLayout
 * @see TabFocus
 */
class FormLayout extends ColumnLayout implements Observable {

    /**
     * Empty array constant used for reflection method calls.
     */
    static final EMPTY_ARRAY:ReadOnlyArray<Dynamic> = [];

    /**
     * Custom theme for this form. If null, uses the global context theme.
     */
    @observe public var theme:Theme = null;

    /**
     * Tab focus component for keyboard navigation within the form.
     */
    @component public var tabFocus:TabFocus;

    /**
     * Background quad for the top section of the form.
     */
    var backgroundTop:Quad = null;

    /**
     * Array of background quads for individual form items.
     */
    var backgrounds:Array<Quad> = null;

    /**
     * Background quad for the bottom section of the form.
     */
    var backgroundBottom:Quad = null;

/// Lifecycle

    /**
     * Creates a new FormLayout instance.
     * 
     * Initializes the form with:
     * - Non-transparent background
     * - Tab focus navigation
     * - Automatic style and background updates
     */
    public function new() {

        super();

        transparent = false;

        tabFocus = new TabFocus();

        autorun(updateStyle);
        autorun(computeBackgrounds);

    }

    /**
     * Destroys the form layout and all its background components.
     * 
     * Cleans up:
     * - All item background quads
     * - Top background quad
     * - Bottom background quad
     */
    override function destroy() {

        if (backgrounds != null) {
            var _backgrounds = backgrounds;
            backgrounds = null;
            for (i in 0..._backgrounds.length) {
                var background = _backgrounds.unsafeGet(i);
                if (background != null) {
                    background.destroy();
                }
            }
        }

        if (backgroundTop != null) {
            backgroundTop.destroy();
            backgroundTop = null;
        }

        if (backgroundBottom != null) {
            backgroundBottom.destroy();
            backgroundBottom = null;
        }

        super.destroy();

    }

/// Layout

    /**
     * Performs form layout, positioning all backgrounds and items.
     * 
     * The layout process:
     * 1. Calls parent layout to position items
     * 2. Updates background components
     * 3. Positions top background from top edge to first item
     * 4. Positions item backgrounds centered on each item
     * 5. Positions bottom background from last item to bottom edge
     */
    override function layout() {

        super.layout();

        computeBackgrounds();

        if (backgroundTop != null) {
            backgroundTop.pos(0, 0);
            backgroundTop.size(width, paddingTop - Math.floor(itemSpacing * 0.5));
        }

        var usedY:Float = backgroundTop.y + backgroundTop.height;
        if (subviews != null && subviews.length > 0) {

            for (i in 0...subviews.length) {
                var view = subviews.unsafeGet(i);

                var background = backgrounds[i];
                var backgroundY = view.y + view.height * view.anchorY - Math.floor(itemSpacing * 0.5);
                var backgroundHeight = view.height + itemSpacing;

                if (background != null) {
                    background.pos(
                        view.x + view.width * view.anchorX - paddingLeft,
                        backgroundY
                    );
                    background.size(
                        width,
                        backgroundHeight
                    );
                }

                usedY = backgroundY + backgroundHeight;
            }
        }

        if (backgroundBottom != null) {
            backgroundBottom.pos(0, usedY);
            backgroundBottom.size(width, height - usedY);
        }

    }

/// Internal

    /**
     * Computes and updates all background components based on current theme settings.
     * 
     * This method:
     * - Creates or updates background quads as needed
     * - Applies theme colors and alpha values
     * - Respects individual item theme overrides
     * - Handles items that render their own backgrounds
     * - Activates/deactivates backgrounds based on theme settings
     */
    function computeBackgrounds() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (theme.backgroundInFormLayout) {

            var windowBackgroundColor = theme.windowBackgroundColor;
            var windowBackgroundAlpha = theme.windowBackgroundAlpha;

            unobserve();

            if (backgroundTop == null) {
                backgroundTop = new Quad();
                backgroundTop.depth = 0.5;
                add(backgroundTop);
            }

            if (subviews != null && subviews.length > 0) {

                if (backgrounds == null) {
                    backgrounds = [];
                }

                var subTheme:Theme = null;

                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);

                    reobserve();
                    subTheme = view.getProperty('theme');
                    unobserve();

                    if (subTheme == null)
                        subTheme = theme;

                    reobserve();
                    windowBackgroundColor = subTheme.windowBackgroundColor;
                    windowBackgroundAlpha = subTheme.windowBackgroundAlpha;
                    unobserve();

                    if (i == 0) {
                        backgroundTop.color = windowBackgroundColor;
                        backgroundTop.alpha = windowBackgroundAlpha;
                    }

                    var renderWindowBackground = Reflect.field(view, 'renderWindowBackground');
                    if (renderWindowBackground == null || Reflect.callMethod(view, renderWindowBackground, EMPTY_ARRAY.original) == false) {
                        var background = backgrounds[i];

                        if (background == null) {
                            background = new Quad();
                            background.depth = 0.5;
                            add(background);
                            backgrounds[i] = background;
                        }
                        else {
                            background.active = true;
                        }

                        background.color = windowBackgroundColor;
                        background.alpha = windowBackgroundAlpha;
                    }
                    else {
                        if (backgrounds.length == i)
                            backgrounds.push(null);
                    }
                }
            }
            else {
                backgroundTop.color = windowBackgroundColor;
                backgroundTop.alpha = windowBackgroundAlpha;
            }

            if (backgroundBottom == null) {
                backgroundBottom = new Quad();
                backgroundBottom.depth = 0.5;
                add(backgroundBottom);
            }

            backgroundBottom.color = windowBackgroundColor;
            backgroundBottom.alpha = windowBackgroundAlpha;

            layoutDirty = true;
        }
        else {

            unobserve();

            if (backgroundTop != null) {
                backgroundTop.active = false;
            }
            if (backgroundBottom != null) {
                backgroundBottom.active = false;
            }
        }

        if (backgrounds != null) {
            var len = subviews != null ? subviews.length : 0;
            if (len > 0) {
                for (i in len...backgrounds.length) {
                    var background = backgrounds.unsafeGet(i);
                    if (background != null) {
                        background.active = false;
                    }
                }
            }
        }

    }

    /**
     * Updates the form's visual style based on the current theme.
     * 
     * Applies:
     * - Background color from theme
     * - Item spacing for proper form layout
     * - Padding around form content
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        color = theme.mediumBackgroundColor;
        itemSpacing = theme.formItemSpacing;
        padding(theme.formPadding);

    }

}
