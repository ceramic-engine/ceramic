package elements;

#if plugin_dialogs
import ceramic.Dialogs;
import ceramic.DialogsFileFilter;
#end

import ceramic.Color;
import ceramic.EditText;
import ceramic.KeyBinding;
import ceramic.KeyBindings;
import ceramic.KeyCode;
import ceramic.LayersLayout;
import ceramic.SelectText;
import ceramic.Shortcuts.*;
import ceramic.TextAlign;
import ceramic.TextView;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using StringTools;

/**
 * A flexible text input field view with support for various input types and validation.
 * 
 * This class extends BaseTextFieldView to provide a complete text field implementation
 * with support for different input types (text, numeric, file/directory dialogs),
 * styling options, placeholder text, and various layout configurations.
 * 
 * ## Features
 * 
 * - Multiple input types: TEXT, NUMERIC, DIR, FILE
 * - Placeholder text support
 * - Multiline text editing
 * - Text alignment options
 * - Disabled state handling
 * - Theme-based styling
 * - Dialog integration for file/directory selection (when plugin_dialogs is available)
 * 
 * ## Input Types
 * 
 * - `TEXT`: Standard text input
 * - `NUMERIC`: Numeric input with validation
 * - `DIR`: Directory picker (requires plugin_dialogs)
 * - `FILE`: File picker (requires plugin_dialogs)
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Create a basic text field
 * var textField = new TextFieldView(TEXT);
 * textField.placeholder = "Enter your name";
 * textField.textAlign = CENTER;
 * 
 * // Create a numeric field
 * var numericField = new TextFieldView(NUMERIC);
 * numericField.placeholder = "Enter a number";
 * 
 * // Create a multiline text area
 * var textArea = new TextFieldView(TEXT);
 * textArea.multiline = true;
 * textArea.placeholder = "Enter description";
 * 
 * #if plugin_dialogs
 * // Create a directory picker
 * var dirField = new TextFieldView(DIR("Select Project Directory"));
 * 
 * // Create a file picker
 * var fileField = new TextFieldView(FILE("Select Image", [
 *     { name: "Images", extensions: ["png", "jpg", "gif"] }
 * ]));
 * #end
 * ```
 * 
 * @see BaseTextFieldView
 * @see TextFieldKind
 * @see Theme
 * @see InputStyle
 */
class TextFieldView extends BaseTextFieldView {

    /**
     * The theme used for styling this text field.
     * If null, the context's default theme will be used.
     */
    @observe public var theme:Theme = null;

/// Overrides

    override function didLostFocus() {

        super.didLostFocus();

        if (textValue == '' || (kind == NUMERIC && textValue == '-')) {
            setEmptyValue(this);
        }

    }

/// Public properties

    /**
     * Whether this text field supports multiline text input.
     * When true, the text field will accept and display multiple lines of text.
     * 
     * @default false
     */
    public var multiline(default,set):Bool = false;
    function set_multiline(multiline:Bool):Bool {
        this.multiline = multiline;
        if (editText != null)
            editText.multiline = multiline;
        return multiline;
    }

    /**
     * The placeholder text displayed when the field is empty.
     * This text provides a hint to the user about what to enter.
     */
    @observe public var placeholder:String = '';

    /**
     * The visual style of the input field.
     * Controls the appearance and rendering style of the text field.
     * 
     * @see InputStyle
     */
    @observe public var inputStyle:InputStyle = DEFAULT;

    /**
     * The text alignment within the field.
     * Controls how text is aligned horizontally within the input area.
     */
    @observe public var textAlign:TextAlign = LEFT;

    /**
     * Whether the text field is disabled.
     * When disabled, the field cannot be edited or interacted with.
     */
    @observe public var disabled:Bool = false;

/// Internal properties

    /**
     * The layers layout container for organizing visual elements.
     * @private
     */
    var layers:LayersLayout;

    /**
     * The text view used to display the placeholder text.
     * @private
     */
    var placeholderView:TextView;

    /**
     * The type of text field, determining its input behavior.
     * This is set during construction and cannot be changed afterward.
     */
    public var kind(default, null):TextFieldKind;

    /**
     * Creates a new text field view.
     * 
     * @param kind The type of text field to create (TEXT, NUMERIC, DIR, FILE)
     */
    public function new(kind:TextFieldKind = TEXT) {

        super();

        this.kind = kind != null ? kind : TEXT;

        padding(6, 6, 6, 6);

        layers = new LayersLayout();
        layers.viewSize(fill(), auto());
        add(layers);

        textView = new TextView();
        textView.minHeight = 15;
        textView.viewSize(fill(), auto());
        textView.verticalAlign = CENTER;
        textView.onResize(this, clipText);
        autorun(() -> {
            textView.align = textAlign;
        });
        textView.pointSize = 12;
        textView.preRenderedSize = 20;
        textView.maxLineDiff = -1;
        layers.add(textView);

        placeholderView = new TextView();
        placeholderView.minHeight = 15;
        placeholderView.viewSize(fill(), auto());
        placeholderView.verticalAlign = CENTER;
        placeholderView.skewX = 10;
        placeholderView.offsetX = 1;
        autorun(() -> {
            placeholderView.align = textAlign;
        });
        placeholderView.pointSize = 12;
        placeholderView.preRenderedSize = 20;
        placeholderView.maxLineDiff = -1;
        layers.add(placeholderView);

        switch kind {
            case TEXT | NUMERIC:
                var theme = this.theme;
                if (theme == null)
                    theme = context.theme;
                editText = new EditText(theme.focusedFieldSelectionColor, theme.lightTextColor);
                editText.container = this;
                textView.text.component('editText', editText);
                editText.onUpdate(this, updateFromEditText);
                editText.onStop(this, handleStopEditText);
                editText.onSubmit(this, handleEditTextSubmit);
            #if plugin_dialogs
            case DIR(title):
                editText = null;
                onPointerDown(this, _ -> {
                    focus();
                    app.onceUpdate(this, _ -> {
                        app.onceUpdate(this, _ -> {
                            Dialogs.openDirectory(title != null ? title : 'Select directory', path -> {
                                trace('Selected directory: $path');
                                if (path != null) {
                                    setTextValue(this, path);
                                }
                            });
                        });
                    });
                });
            case FILE(title, filters):
                editText = null;
                onPointerDown(this, _ -> {
                    focus();
                    app.onceUpdate(this, _ -> {
                        app.onceUpdate(this, _ -> {
                            Dialogs.openFile(title != null ? title : 'Select file', filters, path -> {
                                trace('Selected file: $path');
                                if (path != null) {
                                    setTextValue(this, path);
                                }
                            });
                        });
                    });
                });
            #end
        }

        autorun(updateStyle);
        autorun(updateFromTextValue);
        autorun(updatePlaceholder);

        if (editText != null) {
            onDisabledChange(this, (disabled, _) -> {
                editText.disabled = disabled;
            });
        }

        bindKeyBindings();

    }

/// Public API

    /**
     * Focuses the text field, making it ready for text input.
     * If the field is disabled, this method has no effect.
     */
    override function focus() {

        super.focus();

        if (!disabled) {
            if (editText != null) {
                editText.focus();
            }
        }

    }

/// Layout

    override function layout() {

        super.layout();

    }

    /**
     * Clips the text to fit within the specified dimensions.
     * 
     * @param width The width to clip to
     * @param height The height to clip to
     * @private
     */
    function clipText(width:Float, height:Float) {

        var text = textView.text;
        text.clipTextX = 0;
        text.clipTextY = 0;
        text.clipTextWidth = width + 2;
        text.clipTextHeight = this.height;

    }

/// Internal

    /**
     * Handles when text editing stops.
     * Releases focus if there are no active suggestions.
     * @private
     */
    function handleStopEditText() {

        // Release focus when stopping edition
        if (focused && (suggestions == null || suggestions.length == 0)) {
            screen.focusedVisual = null;
        }

    }

    /**
     * Updates the placeholder display based on current state.
     * The placeholder is shown when the field is empty and either unfocused or disabled.
     * @private
     */
    function updatePlaceholder() {

        var displayedText = textValue;
        var placeholder = this.placeholder;
        var focused = this.focused;
        var disabled = this.disabled;

        unobserve();

        placeholderView.content = placeholder != null ? placeholder : '';
        placeholderView.visible = (displayedText == '' && (!focused || disabled));

        reobserve();

    }

    /**
     * Updates the visual style of the text field based on the current theme and state.
     * Applies different styling for OVERLAY vs DEFAULT input styles,
     * and handles disabled and focused states.
     * @private
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (editText != null) {
            editText.selectionColor = theme.focusedFieldSelectionColor;
            editText.textCursorColor = theme.lightTextColor;
        }

        if (inputStyle == OVERLAY) {
            color = Color.WHITE;
            alpha = 0.1;

            borderSize = 0;
            borderPosition = INSIDE;
            transparent = false;

            textView.textColor = theme.fieldTextColor;
            textView.font = theme.mediumFont;

            placeholderView.textColor = theme.fieldPlaceholderColor;
            placeholderView.font = theme.mediumFont;
        }
        else {
            color = theme.darkBackgroundColor;
            alpha = 1;

            borderSize = 1;
            borderPosition = INSIDE;
            transparent = false;

            textView.textColor = theme.fieldTextColor;
            textView.font = theme.mediumFont;

            placeholderView.textColor = theme.fieldPlaceholderColor;
            placeholderView.font = theme.mediumFont;

            if (disabled) {
                borderColor = theme.mediumBorderColor;
                textView.text.alpha = 0.5;
            }
            else {
                textView.text.alpha = 1;
                if (focused) {
                    borderColor = theme.focusedFieldBorderColor;
                }
                else {
                    borderColor = theme.lightBorderColor;
                }
            }
        }

    }

}

/**
 * Defines the different types of text field inputs available.
 * 
 * Each kind determines the behavior and user interface of the text field:
 * - TEXT: Standard text input
 * - NUMERIC: Numeric input with validation
 * - DIR: Directory selection dialog (requires plugin_dialogs)
 * - FILE: File selection dialog (requires plugin_dialogs)
 */
enum TextFieldKind {

    /**
     * Standard text input field.
     * Allows any text input without special validation.
     */
    TEXT;

    /**
     * Numeric input field.
     * Validates input to ensure only numeric values are accepted.
     */
    NUMERIC;

    #if plugin_dialogs

    /**
     * Directory picker field.
     * When clicked, opens a directory selection dialog.
     * 
     * @param title Optional title for the directory selection dialog
     */
    DIR(?title:String);

    /**
     * File picker field.
     * When clicked, opens a file selection dialog.
     * 
     * @param title Optional title for the file selection dialog
     * @param filters Optional array of file filters to restrict selectable file types
     */
    FILE(?title:String, ?filters:Array<DialogsFileFilter>);

    #end

}
