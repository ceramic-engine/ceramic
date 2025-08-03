package elements;

/**
 * Window item types enumeration.
 * 
 * Represents the different types of UI elements that can be added to
 * a Window in the Elements UI framework. Each type corresponds to a
 * specific interactive control or display element.
 * 
 * This enum abstract uses integers for efficient storage and comparison
 * while providing type safety at compile time.
 * 
 * @see Window
 * @see WindowItem
 */
enum abstract WindowItemKind(Int) from Int to Int {

    /**
     * Unknown or unspecified item type.
     * Used as a default value when the item type hasn't been set.
     */
    var UNKNOWN;

    /**
     * Dropdown selection field.
     * Allows the user to select one option from a list of choices.
     * Typically displays the current selection and shows a dropdown
     * menu when clicked.
     * 
     * @see SelectFieldView
     */
    var SELECT;

    /**
     * Text input field.
     * Allows the user to enter and edit single-line text.
     * Supports standard text editing operations like selection,
     * copy/paste, and cursor movement.
     * 
     * @see TextFieldView
     */
    var EDIT_TEXT;

    /**
     * Floating-point number input field.
     * Specialized text field for entering decimal numbers.
     * Often includes value validation and formatting.
     * 
     * @see TextFieldView
     */
    var EDIT_FLOAT;

    /**
     * Integer number input field.
     * Specialized text field for entering whole numbers.
     * Typically restricts input to digits and optional sign.
     * 
     * @see TextFieldView
     */
    var EDIT_INT;

    /**
     * Color picker field.
     * Allows the user to select a color using various methods
     * like HSB/HSL gradients, RGB values, or hex codes.
     * 
     * @see ColorFieldView
     * @see ColorPickerView
     */
    var EDIT_COLOR;

    #if plugin_dialogs

    /**
     * Directory selection field.
     * Opens a system dialog to browse and select a directory.
     * Only available when the dialogs plugin is enabled.
     * 
     * @see FilePickerView
     */
    var EDIT_DIR;

    /**
     * File selection field.
     * Opens a system dialog to browse and select a file.
     * Only available when the dialogs plugin is enabled.
     * 
     * @see FilePickerView
     */
    var EDIT_FILE;

    #end

    /**
     * Floating-point slider control.
     * Allows selecting a decimal value by dragging a slider handle
     * within a defined range. More intuitive than text input for
     * continuous values.
     * 
     * @see SliderFieldView
     */
    var SLIDE_FLOAT;

    /**
     * Integer slider control.
     * Allows selecting a whole number by dragging a slider handle
     * within a defined range. Values snap to integer increments.
     * 
     * @see SliderFieldView
     */
    var SLIDE_INT;

    /**
     * Clickable button.
     * Triggers an action when clicked. Can display text and/or icons.
     * 
     * @see Button
     */
    var BUTTON;

    /**
     * Checkbox control.
     * Toggle switch for boolean values. Shows a checkmark or
     * similar indicator when selected.
     * 
     * @see BooleanFieldView
     */
    var CHECK;

    /**
     * Static text label.
     * Displays non-interactive text. Used for labels, descriptions,
     * or informational content.
     * 
     * @see LabelView
     * @see TextView
     */
    var TEXT;

    /**
     * Custom visual element.
     * Container for any Visual-based content. Allows embedding
     * arbitrary Ceramic visuals within the UI layout.
     * 
     * @see VisualContainerView
     */
    var VISUAL;

    /**
     * Empty space.
     * Adds vertical spacing between items in the window.
     * Useful for visual grouping and layout control.
     */
    var SPACE;

    /**
     * Horizontal line separator.
     * Draws a line to visually separate sections of the UI.
     * 
     * @see Separator
     */
    var SEPARATOR;

    /**
     * List view container.
     * Displays multiple items in a scrollable list format.
     * Can be used for selection or display purposes.
     * 
     * @see ListView
     * @see SelectListView
     */
    var LIST;

    /**
     * Tabbed container.
     * Organizes content into multiple tabs/pages that can be
     * switched between by clicking tab headers.
     * 
     * @see TabsLayout
     */
    var TABS;

}
