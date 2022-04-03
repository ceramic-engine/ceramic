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

class SliderFieldView extends BaseTextFieldView {

    static var _point = new Point();

/// Public properties

    @observe public var value:Float = 0.0;

    @observe public var minValue:Float = 0.0;

    @observe public var maxValue:Float = 0.0;

    @observe public var enabledTextInput:Bool = true;

    @observe public var inputStyle:InputStyle = DEFAULT;

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

    public var round:Int = -1;

/// Internal properties

    var sliderContainer:View;

    var sliderSquare:View;

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

        var theme = context.theme;

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

        var theme = context.theme;

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

    function handleSliderDown(info:TouchInfo) {

        sliderContainer.screenToVisual(info.x, info.y, _point);
        setValueFromSliderX(_point.x);

        screen.onPointerMove(this, handleSliderMove);
        screen.oncePointerUp(this, handleSliderUp);

    }

    function handleSliderMove(info:TouchInfo) {

        sliderContainer.screenToVisual(info.x, info.y, _point);
        setValueFromSliderX(_point.x);

    }

    function handleSliderUp(info:TouchInfo) {

        screen.offPointerMove(handleSliderMove);
        screen.offPointerUp(handleSliderUp);

    }

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
