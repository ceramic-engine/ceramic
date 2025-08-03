package elements;

import ceramic.Component;
import ceramic.Point;
import ceramic.Quad;
import ceramic.Shortcuts.*;
import ceramic.Text;
import ceramic.Triangle;
import ceramic.Visual;
import elements.Context.context;
import tracker.Observable;

/**
 * A tooltip component that displays informational text when hovering over visual elements.
 * 
 * This class provides a tooltip implementation that can be attached to any visual element
 * as a component. The tooltip displays text content in a styled bubble with a pointer
 * triangle, appearing on hover and disappearing when the pointer leaves the element.
 * 
 * ## Features
 * 
 * - Automatic positioning relative to the target element
 * - Theme-based styling with customizable appearance
 * - Speech bubble design with pointer triangle
 * - Hover-based show/hide behavior
 * - Component-based attachment system
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Add a tooltip to any visual element
 * var button = new Button();
 * Tooltip.tooltip(button, "Click me to save your work");
 * 
 * // Update tooltip content
 * Tooltip.tooltip(button, "Updated tooltip text");
 * 
 * // Remove tooltip
 * Tooltip.tooltip(button, null);
 * 
 * // Create tooltip manually
 * var myTooltip = new Tooltip("Custom tooltip content");
 * someVisual.component('tooltip', myTooltip);
 * ```
 * 
 * @see Component
 * @see Theme
 * @see Visual
 */
class Tooltip extends Visual implements Component implements Observable {

    /**
     * Shared point instance for coordinate calculations.
     * Used to avoid allocating new Point objects during positioning calculations.
     * @private
     */
    static var _point:Point = new Point(0, 0);

    /**
     * The theme used for styling this tooltip.
     * If null, the context's default theme will be used.
     */
    @observe public var theme:Theme = null;

    /**
     * The text content displayed in the tooltip.
     * This is the main message shown to the user.
     */
    @observe public var content:String;

    /**
     * The visual element this tooltip is attached to.
     * @private
     */
    var entity:Visual;

    /**
     * The text visual that displays the tooltip content.
     * @private
     */
    var text:Text;

    /**
     * The background bubble quad for the tooltip.
     * @private
     */
    var bubble:Quad;

    /**
     * The triangle pointer that points to the target element.
     * @private
     */
    var bubbleTriangle:Triangle;

    /**
     * Adds, updates, or removes a tooltip from a visual element.
     * 
     * This static method provides a convenient way to manage tooltips on visual elements.
     * It automatically creates, updates, or removes tooltip components as needed.
     * 
     * @param visual The visual element to attach the tooltip to
     * @param content The tooltip text to display, or null to remove the tooltip
     * 
     * ## Examples
     * ```haxe
     * // Add a tooltip
     * Tooltip.tooltip(myButton, "Click to save");
     * 
     * // Update tooltip content
     * Tooltip.tooltip(myButton, "Click to save (Ctrl+S)");
     * 
     * // Remove tooltip
     * Tooltip.tooltip(myButton, null);
     * ```
     */
    public static function tooltip(visual:Visual, content:String) {

        if (content == null) {
            visual.removeComponent('tooltip');
        }
        else {
            var tooltipComponent:Tooltip = cast visual.component('tooltip');
            if (tooltipComponent == null) {
                tooltipComponent = new Tooltip(content);
                visual.component('tooltip', tooltipComponent);
            }
            else {
                tooltipComponent.content = content;
            }
        }

    }

    /**
     * Creates a new tooltip with the specified content.
     * 
     * The tooltip is automatically added to the context view with high depth
     * to ensure it appears above other UI elements. The visual structure includes
     * a background bubble, pointer triangle, and text content.
     * 
     * @param content The text content to display in the tooltip
     */
    public function new(content:String) {

        super();

        this.content = content;
        depth = 21;
        context.view.add(this);

        anchor(0, 0.5);

        bubble = new Quad();
        bubble.depth = 1;
        add(bubble);

        bubbleTriangle = new Triangle();
        bubbleTriangle.depth = 1;
        add(bubbleTriangle);

        text = new Text();
        text.fitWidth = 100;
        text.depth = 2;
        text.preRenderedSize = 20;
        text.pointSize = 11;
        text.align = CENTER;
        add(text);

        autorun(updateTextContent);
        autorun(updateStyle);

    }

    /**
     * Binds this tooltip as a component to its entity.
     * 
     * Sets up the hover behavior for showing and hiding the tooltip.
     * The tooltip appears when the pointer enters the entity and disappears when it leaves.
     * Positioning is automatically calculated relative to the entity's center.
     * 
     * @private
     */
    function bindAsComponent() {

        active = false;

        entity.onPointerOver(this, _ -> {
            if (screen.isPointerDown)
                return;

            active = true;

            var gap = 24;

            entity.visualToScreen(entity.width * 0.5, entity.height * 0.5, _point);
            if (parent != null)
                parent.screenToVisual(_point.x, _point.y, _point);
            pos(_point.x, gap + _point.y);
        });

        entity.onPointerOut(this, _ -> {
            active = false;
        });

    }

    /**
     * Updates the layout and positioning based on the current text content.
     * 
     * Recalculates the size and positions of all visual elements (text, bubble, triangle)
     * to accommodate the current content. The tooltip is automatically sized to fit
     * the text with appropriate padding.
     * 
     * @private
     */
    function updateTextContent() {

        text.content = this.content;

        var pad = 6;
        var triangleSize = 5;
        var offsetX = -(text.width + pad * 2) * 0.5;

        text.pos(offsetX + pad, triangleSize + pad);

        size(text.width + pad * 2, text.height + pad * 2);

        bubble.size(width, height);
        bubble.pos(offsetX, triangleSize);

        bubbleTriangle.anchor(0.5, 1);
        bubbleTriangle.size(8, triangleSize);
        bubbleTriangle.pos(0, triangleSize);

    }

    /**
     * Updates the visual styling of the tooltip based on the current theme.
     * 
     * Applies theme colors and fonts to all visual elements. If no custom theme
     * is set, uses the context's default theme. The bubble and triangle use
     * overlay colors with appropriate alpha values.
     * 
     * @private
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        text.color = theme.lightTextColor;
        text.font = theme.mediumFont;

        bubble.color = theme.overlayBackgroundColor;
        bubble.alpha = theme.overlayBackgroundAlpha;

        bubbleTriangle.color = bubble.color;
        bubbleTriangle.alpha = bubble.alpha;

    }

}