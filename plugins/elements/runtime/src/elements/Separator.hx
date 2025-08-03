package elements;

import ceramic.Quad;
import ceramic.View;
import elements.Context.context;
import tracker.Observable;

/**
 * A horizontal line separator for visually dividing content sections.
 * 
 * Separator renders as a horizontal line positioned in the center of its container,
 * with customizable thickness. It's commonly used in layouts to create visual
 * separation between groups of related content.
 * 
 * The separator automatically centers itself vertically within its bounds and
 * extends the full width of the container.
 * 
 * Usage example:
 * ```haxe
 * var separator = new Separator();
 * separator.size(200, 10);
 * separator.thickness = 2;
 * add(separator);
 * ```
 */
class Separator extends View implements Observable {

    /** Custom theme override for this separator. If null, uses the global context theme */
    @observe public var theme:Theme = null;

    /** 
     * Thickness of the separator line in pixels.
     * 
     * Setting this property triggers a layout update to apply the new thickness.
     */
    public var thickness(default, set):Float = 1;
    function set_thickness(thickness:Float):Float {
        if (this.thickness != thickness) {
            this.thickness = thickness;
            layoutDirty = true;
        }
        return thickness;
    }

    /** The quad that renders the separator line */
    var quad:Quad;

    /**
     * Creates a new Separator.
     * 
     * Sets up the line quad with transparent background and initializes
     * automatic style updates based on theme changes.
     */
    public function new() {

        super();

        transparent = true;

        quad = new Quad();
        add(quad);

        autorun(updateStyle);

    }

    /**
     * Positions and sizes the separator line.
     * 
     * Centers the line vertically within the container and stretches it
     * to fill the full width with the specified thickness.
     */
    override function layout() {

        quad.pos(0, height * 0.5);
        quad.size(width, thickness);

    }

    /**
     * Updates the visual style of the separator based on the current theme.
     * 
     * Sets the line color using the theme's medium border color.
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        quad.color = theme.mediumBorderColor;

    }

}
