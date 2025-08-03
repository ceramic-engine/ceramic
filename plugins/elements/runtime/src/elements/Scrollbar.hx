package elements;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Visual;
import elements.Context.context;
import tracker.Observable;

/**
 * A basic scrollbar visual component that provides visual feedback for scrollable content.
 * 
 * The Scrollbar displays as a rectangular indicator that changes appearance based on
 * user interaction (hover, press states). It consists of an inner quad with configurable
 * insets and responds to pointer events for interactive feedback.
 * 
 * Usage example:
 * ```haxe
 * var scrollbar = new Scrollbar();
 * scrollbar.size(12, 100);
 * scrollbar.inset(1, 1, 1, 1); // top, right, bottom, left
 * add(scrollbar);
 * ```
 */
class Scrollbar extends Visual implements Observable {

    /** Custom theme override for this scrollbar. If null, uses the global context theme */
    @observe public var theme:Theme = null;

    /** Whether the mouse pointer is currently hovering over the scrollbar */
    @observe var hover:Bool = false;

    /** Whether the scrollbar is currently being pressed/clicked */
    @observe var pressed:Bool = false;

    /** Left inset for the inner quad relative to the scrollbar bounds */
    var insetLeft:Float = 1;

    /** Right inset for the inner quad relative to the scrollbar bounds */
    var insetRight:Float = 1;

    /** Top inset for the inner quad relative to the scrollbar bounds */
    var insetTop:Float = 1;

    /** Bottom inset for the inner quad relative to the scrollbar bounds */
    var insetBottom:Float = 1;

    /** The inner quad that provides the visual appearance of the scrollbar */
    var quad:Quad;

    override function set_width(width:Float):Float {
        super.set_width(width);
        quad.width = width - insetLeft - insetRight;
        return width;
    }

    override function set_height(height:Float):Float {
        super.set_height(height);
        quad.height = height - insetTop - insetBottom;
        return height;
    }

    /**
     * Set the insets for the inner quad on all sides.
     * 
     * @param insetTop Top inset in pixels
     * @param insetRight Right inset in pixels
     * @param insetBottom Bottom inset in pixels
     * @param insetLeft Left inset in pixels
     */
    public function inset(insetTop:Float, insetRight:Float, insetBottom:Float, insetLeft:Float):Void {
        this.insetTop = insetTop;
        this.insetRight = insetRight;
        this.insetBottom = insetBottom;
        this.insetLeft = insetLeft;
        quad.width = width - insetLeft - insetRight;
        quad.height = height - insetTop - insetBottom;
    }

    /**
     * Creates a new Scrollbar instance.
     * 
     * Sets up the inner quad with default insets, configures pointer event handlers
     * for hover and press states, and initializes with a default size of 12x12 pixels.
     */
    public function new() {

        super();

        quad = new Quad();
        quad.pos(insetLeft, insetTop);
        add(quad);

        onPointerDown(this, _ -> {
            pressed = true;
        });

        onPointerUp(this, _ -> {
            pressed = false;
        });

        onPointerOver(this, _ -> {
            hover = true;
        });

        onPointerOut(this, _ -> {
            hover = false;
        });

        autorun(updateStyle);

        size(12, 12);

    }

    /**
     * Updates the visual style of the scrollbar based on current state.
     * 
     * Colors the inner quad differently based on pressed/hover states:
     * - Pressed: Darker color (50% interpolation between background and text)
     * - Hover: Medium color (25% interpolation)
     * - Normal: Light background color
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (pressed) {
            quad.color = Color.interpolate(theme.lightBackgroundColor, theme.darkTextColor, 0.5);
        }
        else if (hover) {
            quad.color = Color.interpolate(theme.lightBackgroundColor, theme.darkTextColor, 0.25);
        }
        else {
            quad.color = theme.lightBackgroundColor;
        }

    }

}