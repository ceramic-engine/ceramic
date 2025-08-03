package elements;

/**
 * Defines the visual style options for input fields in the Elements UI system.
 * 
 * This enum controls how text fields, select fields, and other input elements
 * are rendered, allowing different presentations for different contexts.
 * 
 * ## Available Styles
 * 
 * - `DEFAULT`: Standard input style with full borders and background
 * - `OVERLAY`: Transparent/floating style for overlaying on backgrounds
 * - `MINIMAL`: Reduced visual elements for a cleaner look
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var textField = new TextFieldView();
 * textField.inputStyle = InputStyle.MINIMAL;
 * 
 * var colorPicker = new ColorFieldView();
 * colorPicker.inputStyle = InputStyle.OVERLAY;
 * ```
 */
enum InputStyle {

    /**
     * The default input style with standard borders, background, and padding.
     * This is the most common style for form inputs and provides clear visual
     * boundaries and interaction states.
     */
    DEFAULT;

    /**
     * An overlay-optimized style with transparent or semi-transparent backgrounds.
     * Useful when input fields need to float over content without obscuring it,
     * such as in floating panels or HUD interfaces.
     */
    OVERLAY;

    /**
     * A minimalistic style with reduced visual elements.
     * Removes most decorative elements, keeping only essential interaction
     * indicators. Good for dense interfaces or when the input context is clear.
     */
    MINIMAL;

}