package elements;

import ceramic.EditText;
import ceramic.Point;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.TouchInfo;
import ceramic.View;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;

using StringTools;

/**
 * A numeric input field with an integrated slider for intuitive value adjustment.
 * 
 * SliderFieldView combines a text input field with a horizontal slider, allowing users
 * to either type values directly or drag the slider handle. The component supports
 * numeric ranges, rounding precision, and can be disabled. The slider provides visual
 * feedback and makes it easy to explore value ranges.
 * 
 * Key features:
 * - Text input with numeric validation
 * - Integrated horizontal slider with draggable handle
 * - Configurable min/max value ranges
 * - Precision rounding support
 * - Keyboard focus and tab navigation
 * - Optional text input disabling (slider-only mode)
 * - Visual feedback for hover, focus, and disabled states
 * 
 * Usage example:
 * ```haxe
 * var slider = new SliderFieldView(0, 100); // min: 0, max: 100
 * slider.value = 50;
 * slider.round = 1; // round to integers
 * slider.enabledTextInput = true;
 * slider.onValueChange(this, (value, prev) -> {
 *     trace('Value changed to: ' + value);
 * });
 * add(slider);
 * ```
 */
class SliderFieldView extends BaseTextFieldView {

    /** Custom theme override for this slider field. If null, uses the global context theme */
    @observe public var theme:Theme = null;

    /** Reusable point for coordinate calculations during slider interaction */
    static var _point = new Point();

/// Public properties

    /** The current numeric value of the slider */
    @observe public var value:Float = 0.0;

    /** Minimum allowed value for the slider */
    @observe public var minValue:Float = 0.0;

    /** Maximum allowed value for the slider */
    @observe public var maxValue:Float = 0.0;

    /** Whether the text input portion is enabled for direct typing */
    @observe public var enabledTextInput:Bool = true;

    /** Visual style of the field (DEFAULT, OVERLAY, or MINIMAL) */
    @observe public var inputStyle:InputStyle = DEFAULT;

    /** Whether the entire slider field is disabled and non-interactive */
    @observe public var disabled(default, set):Bool = false;
    function set_disabled(disabled:Bool):Bool {
        if (this.disabled != disabled) {
            this.disabled = disabled;
            touchable = !disabled;
            if (editText != null) {
                editText.disabled = disabled;
            }
            if (disabled && unobservedFocused) {
                screen.focusedVisual = null;
            }
        }
        return disabled;
    }

    /**
     * Precision for value rounding.
     * 
     * - `-1`: No rounding (default)
     * - `1`: Round to integers  
     * - `10`: Round to tenths (0.1)
     * - `100`: Round to hundredths (0.01)
     * - etc.
     */
    public var round:Int = -1;

/// Internal properties

    /** Container view for the slider track and handle */
    var sliderContainer:View;

    /** The draggable handle/indicator of the slider */
    var sliderSquare:View;

    /**
     * Creates a new SliderFieldView with the specified value range.
     * 
     * @param minValue Minimum value for the slider (default: 0)
     * @param maxValue Maximum value for the slider (default: 1)
     */
    public function new(minValue:Float = 0, maxValue:Float = 1) {

        super();

        padding(6, 6, 6, 6);
        borderPosition = INSIDE;

        this.minValue = minValue;
        this.maxValue = maxValue;

        direction = HORIZONTAL;
        align = LEFT;

        textView = new TextView();
        textView.minHeight = 15;
        textView.viewSize(50, auto());
        textView.verticalAlign = CENTER;
        textView.align = LEFT;
        textView.pointSize = 12;
        textView.preRenderedSize = 20;
        textView.onResize(this, clipText);
        autorun(() -> {
            textView.active = enabledTextInput;
        });
        add(textView);

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        editText = new EditText(theme.focusedFieldSelectionColor, theme.lightTextColor);
        editText.container = textView;
        textView.text.component('editText', editText);
        editText.onUpdate(this, updateFromEditText);
        editText.onStop(this, handleStopEditText);
        editText.onSubmit(this, handleEditTextSubmit);

        sliderContainer = new View();
        sliderContainer.depth = 1;
        sliderContainer.viewSize(fill(), 15);
        sliderContainer.transparent = false;
        add(sliderContainer);

        sliderSquare = new View();
        sliderSquare.transparent = false;
        sliderSquare.size(19, 15);
        sliderSquare.depth = 1;
        sliderContainer.add(sliderSquare);

        sliderContainer.onPointerDown(this, handleSliderDown);
        sliderContainer.onLayout(this, layoutSliderContainer);

        autorun(updateStyle);
        autorun(updateFromTextValue);
        autorun(updateFromValue);

        bindKeyBindings();

    }

/// Layout

    /**
     * Handles focus events for the slider field.
     * 
     * When the field gains focus, the text input is also focused for immediate editing.
     */
    override function focus() {

        super.focus();

        if (!focused) {
            editText.focus();
        }

    }

    override function didLostFocus() {

        super.didLostFocus();

        if (textView.content == '' || textView.content == '-') {
            var emptyValue:Float = 0;
            if (emptyValue < minValue)
                emptyValue = minValue;
            if (emptyValue > maxValue)
                emptyValue = maxValue;

            emptyValue = applyRound(emptyValue);

            setValue(this, emptyValue);
            updateFromValue();
        }
        else if (textView.content.endsWith('.')) {
            updateFromValue();
        }

        screen.offPointerMove(handleSliderMove);
        screen.offPointerUp(handleSliderUp);

    }

    /**
     * Clips the text display to fit within the available text area.
     * 
     * @param width Available width for text
     * @param height Available height for text
     */
    function clipText(width:Float, height:Float) {

        var text = textView.text;
        text.clipTextX = 0;
        text.clipTextY = 0;
        text.clipTextWidth = width - 6;
        text.clipTextHeight = this.height;

    }

/// Overrides

    override function layout() {

        super.layout();

    }

    /**
     * Positions the slider handle based on the current value.
     * 
     * Calculates the handle position as a proportion of the value within the min/max range,
     * accounting for container padding and handle width.
     */
    function layoutSliderContainer() {

        var minX = sliderContainer.paddingLeft;
        var maxX = (sliderContainer.width - sliderSquare.width - sliderContainer.paddingRight);
        var usedValue = value;

        if (usedValue < minValue)
            usedValue = minValue;
        if (usedValue > maxValue)
            usedValue = maxValue;

        sliderSquare.pos(
            minX + (maxX - minX) * (usedValue - minValue) / (maxValue - minValue),
            sliderContainer.paddingTop
        );

    }

/// Internal

    function handleStopEditText() {

        // Release focus when stopping edition
        if (focused) {
            if (screen.focusedVisual != null) {
                if (!screen.focusedVisual.hasIndirectParent(this) || screen.focusedVisual.hasIndirectParent(textView)) {
                    screen.focusedVisual = null;
                }
            }
        }

    }

    function updateFromValue() {

        var value = this.value;

        unobserve();

        var displayedText = '' + value;
        if (editText != null)
            editText.updateText(displayedText);
        if (textValue != displayedText)
            textValue = displayedText;
        textView.content = displayedText;

        sliderContainer.layoutDirty = true;

        reobserve();

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (editText != null) {
            editText.selectionColor = theme.focusedFieldSelectionColor;
            editText.textCursorColor = theme.lightTextColor;
        }

        if (inputStyle == MINIMAL) {
            transparent = true;
            borderSize = 0;
        }
        else {
            transparent = false;
            color = theme.darkBackgroundColor;
            borderSize = 1;
        }

        textView.textColor = theme.fieldTextColor;
        textView.font = theme.mediumFont;

        if (inputStyle == MINIMAL) {
            sliderSquare.color = theme.darkTextColor;
            sliderContainer.color = theme.mediumBackgroundColor;
            sliderContainer.borderSize = 1;
            sliderContainer.borderPosition = INSIDE;
            sliderContainer.borderDepth = 0;
            sliderContainer.borderColor = theme.darkBorderColor;
        }
        else if (disabled) {
            sliderSquare.color = theme.darkerTextColor;
            sliderContainer.color = theme.darkBackgroundColor;
            borderColor = theme.mediumBorderColor;
            sliderContainer.borderSize = 0;
            textView.textAlpha = 0.5;
        }
        else if (focused) {
            sliderSquare.color = theme.mediumTextColor;
            sliderContainer.color = theme.lightBackgroundColor;
            borderColor = theme.focusedFieldBorderColor;
            sliderContainer.borderSize = 0;
            textView.textAlpha = 1;
        }
        else {
            sliderSquare.color = theme.darkTextColor;
            sliderContainer.color = theme.mediumBackgroundColor;
            borderColor = theme.lightBorderColor;
            sliderContainer.borderSize = 0;
            textView.textAlpha = 1;
        }

    }

    /**
     * Applies rounding to a value based on the round precision setting.
     * 
     * @param value The value to round
     * @return The rounded value
     */
    function applyRound(value:Float):Float {

        if (round == 1) {
            value = Math.round(value);
        }
        else if (round > 1) {
            value = Math.round(value * round) / round;
        }

        return value;

    }

/// Slider

    /**
     * Handles mouse/touch down events on the slider.
     * 
     * Starts slider interaction, sets initial value, and begins tracking pointer movement.
     * 
     * @param info Touch/mouse interaction information
     */
    function handleSliderDown(info:TouchInfo) {

        sliderContainer.screenToVisual(info.x, info.y, _point);
        setValueFromSliderX(_point.x);

        screen.onPointerMove(this, handleSliderMove);
        screen.oncePointerUp(this, handleSliderUp);

    }

    /**
     * Handles pointer movement during slider dragging.
     * 
     * Updates the slider value based on the current pointer position.
     * 
     * @param info Touch/mouse interaction information
     */
    function handleSliderMove(info:TouchInfo) {

        sliderContainer.screenToVisual(info.x, info.y, _point);
        setValueFromSliderX(_point.x);

    }

    /**
     * Handles pointer release events, ending slider interaction.
     * 
     * Removes pointer tracking listeners when slider dragging ends.
     * 
     * @param info Touch/mouse interaction information
     */
    function handleSliderUp(info:TouchInfo) {

        screen.offPointerMove(handleSliderMove);
        screen.offPointerUp(handleSliderUp);

    }

    /**
     * Converts a horizontal slider position to a value within the min/max range.
     * 
     * Calculates the proportional value based on slider position, applies range limits
     * and rounding, then updates the field value.
     * 
     * @param sliderX Horizontal position within the slider container
     */
    function setValueFromSliderX(sliderX:Float) {

        var leftMargin = sliderContainer.paddingLeft + sliderSquare.width * 0.5;
        var rightMargin = sliderContainer.paddingRight + sliderSquare.width * 0.5;

        var newValue =
            minValue
            +
            (maxValue - minValue)
            *
            (sliderX - leftMargin)
            /
            (sliderContainer.width - leftMargin - rightMargin);

        if (newValue < minValue)
            newValue = minValue;
        if (newValue > maxValue)
            newValue = maxValue;

        newValue = applyRound(newValue);

        setValue(this, newValue);
        updateFromValue();

    }

}
