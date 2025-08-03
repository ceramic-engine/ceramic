package elements;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Visual;

/**
 * A visual component that renders an X-shaped cross icon.
 * 
 * Creates a cross (×) shape using two rotated quads positioned at 45-degree angles.
 * Commonly used for close buttons, delete actions, or cancel indicators in UI.
 * 
 * The cross automatically scales to fit within the visual's bounds while maintaining
 * proper proportions. Both the line thickness and overall scale can be customized.
 * 
 * Example usage:
 * ```haxe
 * var closeButton = new CrossX();
 * closeButton.size(24, 24);
 * closeButton.color = Color.RED;
 * closeButton.thickness = 3;
 * ```
 * 
 * @see elements.Window For usage in window close buttons
 */
class CrossX extends Visual {

    /**
     * First quad component forming one diagonal line of the cross.
     */
    var quad0:Quad;

    /**
     * Second quad component forming the other diagonal line of the cross.
     */
    var quad1:Quad;

    /**
     * The thickness of the cross lines in pixels.
     * Default value is 2.
     * Marked with @content to trigger recomputation when changed.
     */
    @content public var thickness:Float = 2;

    /**
     * Scale factor applied to the cross shape within its bounds.
     * Default value is 1 (no scaling).
     * Values < 1 make the cross smaller within its container.
     * Marked with @content to trigger recomputation when changed.
     */
    @content public var internalScale:Float = 1;

    /**
     * The color of the cross.
     * Applies to both diagonal lines.
     * Default is Color.WHITE.
     */
    public var color(default, set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color != color) {
            this.color = color;
            quad0.color = color;
            quad1.color = color;
        }
        return color;
    }

    /**
     * Sets the width of the cross container.
     * Triggers content recomputation to maintain proper proportions.
     */
    override function set_width(width:Float):Float {
        if (this.width != width) {
            super.set_width(width);
            contentDirty = true;
        }
        return width;
    }

    /**
     * Sets the height of the cross container.
     * Triggers content recomputation to maintain proper proportions.
     */
    override function set_height(height:Float):Float {
        if (this.height != height) {
            super.set_height(height);
            contentDirty = true;
        }
        return height;
    }

    /**
     * Creates a new CrossX visual component.
     * Initializes with a 16x16 size and white color.
     */
    public function new() {

        super();

        quad0 = new Quad();
        quad0.color = this.color;
        quad0.anchor(0.5, 0.5);
        quad0.rotation = 45;
        add(quad0);

        quad1 = new Quad();
        quad1.color = this.color;
        quad1.anchor(0.5, 0.5);
        quad1.rotation = -45;
        add(quad1);

        size(16, 16);

        contentDirty = true;

    }

    /**
     * Computes the content layout of the cross.
     * Positions and sizes the two diagonal quads based on current dimensions,
     * thickness, and internal scale settings.
     * 
     * The quads are sized to 70% of the container width to create proper
     * visual balance and ensure the cross fits nicely within its bounds.
     */
    override function computeContent() {

        contentDirty = false;

        quad0.pos(width * 0.5, height * 0.5);
        quad0.size(width * 0.7, thickness);
        quad0.scale(internalScale);

        quad1.pos(quad0.x, quad0.y);
        quad1.size(quad0.width, quad0.height);
        quad1.scale(internalScale);

    }

}