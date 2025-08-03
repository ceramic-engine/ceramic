package elements;

import ceramic.TextView;
import elements.Context.context;
import tracker.Observable;

/**
 * A themed text label for UI forms and layouts.
 * 
 * LabelView extends TextView with theme integration and automatic styling
 * based on the current theme and state. It provides consistent text
 * appearance across the UI with support for bold text and disabled states.
 * 
 * Features:
 * - Automatic theme-based styling
 * - Bold text support
 * - Disabled state with appropriate visual feedback
 * - Consistent font and color management
 * - Automatic sizing with fill width and minimum height
 * 
 * Example usage:
 * ```haxe
 * var label = new LabelView();
 * label.content = "Username:";
 * label.bold = true;
 * label.disabled = false;
 * ```
 * 
 * @see TextView
 * @see Theme
 */
class LabelView extends TextView implements Observable {

    /** Custom theme override for this label */
    @observe public var theme:Theme = null;

    /** Whether to display the text in bold font */
    @observe public var bold:Bool = false;

    /** Whether the label appears disabled (affects text color) */
    @observe public var disabled:Bool = false;

    /**
     * Creates a new LabelView instance.
     * 
     * Initializes the label with default properties:
     * - Full width with auto height
     * - Minimum height of 16 pixels
     * - Left alignment with center vertical alignment
     * - 12pt text size with 20pt pre-rendered size
     * - Automatic style updates based on theme changes
     */
    public function new() {

        super();

        viewSize(fill(), auto());
        minHeight = 16;
        align = LEFT;
        verticalAlign = CENTER;
        pointSize = 12;
        preRenderedSize = 20;

        autorun(updateStyle);

    }

    /**
     * Updates the visual styling based on current theme and state.
     * 
     * Applies appropriate styling from the current theme:
     * - Text color: darkTextColor when disabled, lightTextColor when enabled
     * - Font: boldFont when bold is true, mediumFont otherwise
     * 
     * Falls back to the global context theme if no custom theme is set.
     * This method is called automatically when theme, bold, or disabled properties change.
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (disabled) {
            textColor = theme.darkTextColor;
        }
        else {
            textColor = theme.lightTextColor;
        }

        font = bold ? theme.boldFont : theme.mediumFont;

    }

}
