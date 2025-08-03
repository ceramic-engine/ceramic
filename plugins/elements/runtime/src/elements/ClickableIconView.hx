package elements;

import ceramic.Click;
import ceramic.Color;
import ceramic.LongPress;
import ceramic.Transform;
import elements.Context.context;

/**
 * An interactive icon button that responds to clicks and hover states.
 * 
 * Extends EntypoIconView to add interactive behavior:
 * - Click detection with visual feedback
 * - Long press support
 * - Hover state with color changes
 * - Disabled state support
 * - Theme-aware styling
 * - Subtle press animation (1px downward shift)
 * 
 * Commonly used for toolbar buttons, action icons, and interactive UI elements.
 * 
 * Example usage:
 * ```haxe
 * var deleteButton = new ClickableIconView();
 * deleteButton.icon = TRASH;
 * deleteButton.onClick(() -> deleteItem());
 * deleteButton.onLongPress(() -> showDeleteOptions());
 * ```
 * 
 * @see EntypoIconView
 * @see Click
 * @see LongPress
 */
class ClickableIconView extends EntypoIconView {

    /**
     * The theme to use for styling. If null, uses the global context theme.
     */
    @observe public var theme:Theme = null;

    /**
     * Internal hover state tracking.
     */
    @observe var hover:Bool = false;

    /**
     * Whether the icon button is disabled.
     * Disabled buttons don't respond to clicks and appear dimmed.
     */
    @observe public var disabled:Bool = false;

    /**
     * Whether to apply hover styling (color change on hover).
     * Set to false for icons that should maintain constant appearance.
     */
    @observe public var hoverStyle:Bool = true;

    /**
     * Event emitted when the icon is clicked.
     */
    @event function click();

    /**
     * Event emitted when the icon is long-pressed.
     */
    @event function longPress();

    /**
     * Creates a new ClickableIconView.
     * 
     * Sets up:
     * - Click and long press detection
     * - Hover state tracking
     * - Press animation (1px downward shift)
     * - Theme-based styling updates
     */
    public function new() {

        super();

        transform = new Transform();

        var click = new Click();
        component('click', click);
        click.onClick(this, () -> {
            emitClick();
        });

        var longPress = new LongPress(info -> {
            emitLongPress();
        }, click);
        component('longPress', longPress);

        onPointerDown(this, _ -> {
            transform.ty = 1;
            transform.changedDirty = true;
        });
        onPointerUp(this, _ -> {
            transform.ty = 0;
            transform.changedDirty = true;
        });

        onPointerOver(this, _ -> {
            hover = true;
        });

        onPointerOut(this, _ -> {
            hover = false;
        });

        autorun(() -> {
            touchable = !disabled;
        });
        autorun(updateStyle);

    }

    /**
     * Updates the icon color based on current state and theme.
     * 
     * Color logic:
     * - Normal: Slightly dimmed icon color (70% blend with background)
     * - Hover: Full icon color
     * - Disabled: 50% blend with dark background
     * - No hover style: Always full icon color
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        var textColor = hover || !hoverStyle ? theme.iconColor : Color.interpolate(theme.mediumBackgroundColor, theme.iconColor, 0.7);

        if (disabled) {
            textColor = Color.interpolate(textColor, theme.darkBackgroundColor, 0.5);
        }

        this.textColor = textColor;

    }

}