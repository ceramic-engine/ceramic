package elements;

import ceramic.Color;
import ceramic.EditText;
import ceramic.LayersLayout;
import ceramic.Point;
import ceramic.Quad;
import ceramic.RowLayout;
import ceramic.ScanCode;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.View;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using StringTools;

class ColorFieldView extends FieldView {

    static var _point = new Point();

    static var RE_HEX_COLOR = ~/^[0-F][0-F][0-F][0-F][0-F][0-F]$/;

    static var RE_HEX_COLOR_ANY_LENGTH = ~/^[0-F]+$/;

/// Hooks

    public dynamic function setValue(field:ColorFieldView, value:Color):Void {

        this.value = value;

    }

/// Public properties

    @observe public var value:Color = Color.WHITE;

/// Internal properties

    @observe var pickerVisible:Bool = false;

    var container:RowLayout;

    var textView:TextView;

    var textPrefixView:TextView;

    var editText:EditText;

    var colorPreview:View;

    var pickerContainer:View;

    var pickerView:ColorPickerView;

    var bubbleTriangle:BiBorderedTriangle;

    var bubbleTopBorderLeft:Quad;

    var bubbleTopBorderRight:Quad;

    var updatingFromPicker:Int = 0;

    public function new() {

        super();
        transparent = false;
        color = Color.YELLOW;

        direction = HORIZONTAL;
        align = LEFT;

        container = new RowLayout();
        container.viewSize(fill(), auto());
        container.padding(6, 6, 6, 6);
        container.borderSize = 1;
        container.borderPosition = INSIDE;
        container.transparent = false;
        add(container);

        pickerContainer = new View();
        pickerContainer.transparent = true;
        pickerContainer.viewSize(0, 0);
        pickerContainer.active = false;
        pickerContainer.depth = 25;
        context.view.add(pickerContainer);

        // var filler = new View();
        // filler.transparent = true;
        // filler.viewSize(fill(), fill());
        // add(filler);

        textPrefixView = new TextView();
        textPrefixView.viewSize(auto(), auto());
        textPrefixView.align = LEFT;
        textPrefixView.pointSize = 12;
        textPrefixView.preRenderedSize = 20;
        textPrefixView.content = '#';
        textPrefixView.verticalAlign = CENTER;
        textPrefixView.padding(0, 3, 0, 2);
        textPrefixView.text.component(new ItalicText());
        container.add(textPrefixView);

        textView = new TextView();
        textView.viewSize(54, auto());
        textView.align = LEFT;
        textView.verticalAlign = CENTER;
        textView.pointSize = 12;
        textView.preRenderedSize = 20;
        container.add(textView);

        var theme = context.theme;

        editText = new EditText(theme.focusedFieldSelectionColor, theme.lightTextColor);
        editText.container = textView;
        textView.text.component('editText', editText);
        editText.onUpdate(this, updateFromEditText);
        editText.onStop(this, handleStopEditText);

        colorPreview = new View();
        colorPreview.viewSize(fill(), 15);
        colorPreview.transparent = false;
        colorPreview.padding(0, 0, 3, 0);
        container.add(colorPreview);

        autorun(updateStyle);
        autorun(updateFromValue);
        autorun(updatePickerContainer);

        container.onLayout(this, layoutContainer);
        pickerContainer.onLayout(this, layoutPickerContainer);

        colorPreview.onPointerDown(this, _ -> togglePickerVisible());

        app.onUpdate(this, _ -> updatePickerVisibility());
        app.onPostUpdate(this, _ -> updatePickerPosition());

        // If the field is put inside a scrolling layout right after being initialized,
        // check its scroll transform to update position instantly (without loosing a frame)
        app.onceUpdate(this, function(_) {
            var scrollingLayout = getScrollingLayout();
            if (scrollingLayout != null) {
                scrollingLayout.scroller.scrollTransform.onChange(this, updatePickerPosition);
            }
        });

        // Some keyboard shortcuts
        input.onKeyDown(this, key -> {
            if (key.scanCode == ScanCode.ESCAPE) {
                pickerVisible = false;
            }
            else if (focused && key.scanCode == ScanCode.ENTER) {
                pickerVisible = true;
            }
            else if (focused && key.scanCode == ScanCode.SPACE) {
                pickerVisible = !pickerVisible;
            }
        });

    }

/// Layout

    override function focus() {

        super.focus();

        if (!focused) {
            editText.focus();
        }

    }

    override function didLostFocus() {

        if (textView.content == '') {
            var emptyValue:Color = Color.WHITE;
            setValue(this, emptyValue);
            updateFromValue();
        }
        else if (!RE_HEX_COLOR.match(textView.content)) {
            updateFromValue();
        }

    }

/// Layout

    override function layout() {

        super.layout();

    }

    function layoutContainer() {

        //

    }

    function updatePickerVisibility() {

        if (pickerView == null || !pickerVisible)
            return;

        if (FieldSystem.shared.focusedField == this)
            return;

        var parent = screen.focusedVisual;
        var keepFocus = false;
        while (parent != null) {
            if (parent == pickerView) {
                keepFocus = true;
                break;
            }
            parent = parent.parent;
        }

        if (!keepFocus) {
            pickerVisible = false;
        }

    }

    function updatePickerPosition() {

        if (!pickerContainer.active)
            return;

        var scrollingLayout = getScrollingLayout();

        colorPreview.visualToScreen(
            colorPreview.width * 0.5,
            colorPreview.height * 0.5,
            _point
        );

        var x = _point.x;
        var y = _point.y;

        // if (scrollingLayout != null && scrollingLayout.filter != null && scrollingLayout.filter.enabled) {
        //     scrollingLayout.visualToScreen(0, 0, _point);
        //     x += _point.x;
        //     y += _point.y;
        // }

        context.view.screenToVisual(x, y, _point);
        x = _point.x;
        y = _point.y;

        // Clip if needed
        if (pickerView != null) {
            if (scrollingLayout != null) {
                scrollingLayout.screenToVisual(0, 0, _point);
                context.view.screenToVisual(_point.x, _point.y, _point);
                if (y + _point.y < 0) {
                    pickerContainer.clip = scrollingLayout;
                }
                else {
                    pickerContainer.clip = null;
                }
            }
            else {
                pickerContainer.clip = null;
            }
        }
        else {
            pickerContainer.clip = null;
        }

        if (x != pickerContainer.x || y != pickerContainer.y)
            pickerContainer.layoutDirty = true;

        pickerContainer.pos(x, y);

    }

    function layoutPickerContainer() {

        if (pickerView != null) {

            // Margin between bubble right border and editor bounds
            var editorMargin = 9;

            var previewMargin = 12;

            pickerView.autoComputeSizeIfNeeded(true);

            pickerView.visualToScreen(pickerView.width, pickerView.height, _point);
            context.view.screenToVisual(_point.x, _point.y, _point);

            pickerView.x = Math.max(
                Math.min(
                    context.view.width - pickerView.width - editorMargin - pickerContainer.x,
                    pickerView.width * -0.5
                ),
                -pickerContainer.x + editorMargin
            );

            var availableHeightAfter = context.view.height - pickerContainer.y - colorPreview.height * 0.5 - editorMargin - previewMargin;

            bubbleTriangle.size(14, 7);

            if (pickerView.height <= availableHeightAfter) {
                pickerView.y = colorPreview.height * 0.5 + previewMargin;
                bubbleTriangle.pos(0, pickerView.y);
                bubbleTriangle.rotation = 0;
                pickerView.borderTopSize = 0;
                pickerView.borderBottomSize = 1;

                bubbleTopBorderLeft.pos(-1, -1);
                bubbleTopBorderLeft.size(0.5 - pickerView.x - bubbleTriangle.width * 0.5, 1);
                bubbleTopBorderRight.pos(-pickerView.x + bubbleTriangle.width * 0.5, -1);
                bubbleTopBorderRight.size(1 + pickerView.width - bubbleTriangle.width * 0.5 + pickerView.x, 1);
            }
            else {
                pickerView.y = -pickerView.height - colorPreview.height * 0.5 - previewMargin;
                bubbleTriangle.pos(0, pickerView.y + pickerView.height);
                bubbleTriangle.rotation = 180;
                pickerView.borderTopSize = 1;
                pickerView.borderBottomSize = 0;

                bubbleTopBorderLeft.pos(-1, pickerView.height);
                bubbleTopBorderLeft.size(0.5 - pickerView.x - bubbleTriangle.width * 0.5, 1);
                bubbleTopBorderRight.pos(-pickerView.x + bubbleTriangle.width * 0.5, pickerView.height);
                bubbleTopBorderRight.size(1 + pickerView.width - bubbleTriangle.width * 0.5 + pickerView.x, 1);
            }
        }

    }

/// Internal

    override function destroy() {

        super.destroy();

        if (pickerContainer != null) {
            pickerContainer.destroy();
            pickerContainer = null;
        }

    }

    function updateFromEditText(text:String) {

        if (text == '')
            return;

        if (text.startsWith('#'))
            text = text.substr(1);
        if (text.startsWith('0x'))
            text = text.substr(2);
        if (text.length == 8)
            text = text.substr(0, 6);

        if (RE_HEX_COLOR.match(text)) {
            setValue(this, Color.fromString('0x' + text));
        }

        if (!RE_HEX_COLOR_ANY_LENGTH.match(text) || text.length > 6) {
            updateFromValue();
        }

    }

    function handleStopEditText() {

        //

    }

    function updateFromValue() {

        var value = this.value;

        unobserve();

        var displayedText = value.toHexString(false);
        editText.updateText(displayedText);
        textView.content = displayedText;

        colorPreview.color = value;
        colorPreview.layoutDirty = true;

        reobserve();

    }

    function updateStyle() {

        var theme = context.theme;

        if (editText != null) {
            editText.selectionColor = theme.focusedFieldSelectionColor;
            editText.textCursorColor = theme.lightTextColor;
        }

        container.color = theme.darkBackgroundColor;

        textView.textColor = theme.fieldTextColor;
        textView.font = theme.mediumFont;

        textPrefixView.textColor = theme.darkTextColor;
        textPrefixView.font = theme.mediumFont;

        if (focused || pickerVisible) {
            container.borderColor = theme.focusedFieldBorderColor;
        }
        else {
            container.borderColor = theme.lightBorderColor;
        }

    }

/// Picker

    function togglePickerVisible() {

        pickerVisible = !pickerVisible;

    }

    function updatePickerContainer() {

        var pickerVisible = this.pickerVisible;
        var value = this.value;

        unobserve();

        if (pickerVisible) {

            if (pickerView == null) {
                pickerView = new ColorPickerView();
                pickerView.depth = 10;
                pickerView.onColorValueChange(pickerView, (color, _) -> {
                    updatingFromPicker++;
                    this.setValue(this, color);
                    app.onceUpdate(this, _ -> {
                        updatingFromPicker--;
                    });
                });
                pickerContainer.add(pickerView);

                bubbleTopBorderLeft = new Quad();
                pickerView.add(bubbleTopBorderLeft);

                bubbleTopBorderRight = new Quad();
                pickerView.add(bubbleTopBorderRight);

                bubbleTriangle = new BiBorderedTriangle();
                bubbleTriangle.anchor(0.5, 1);
                bubbleTriangle.borderSize = 1.5;
                bubbleTriangle.autorun(() -> {
                    var theme = context.theme;
                    var overlayBorderColor = theme.overlayBorderColor;
                    var overlayBorderAlpha = theme.overlayBorderAlpha;
                    bubbleTriangle.innerColor = theme.overlayBackgroundColor;
                    bubbleTriangle.innerAlpha = theme.overlayBackgroundAlpha;
                    bubbleTriangle.borderColor = overlayBorderColor;
                    bubbleTriangle.borderAlpha = overlayBorderAlpha;
                    bubbleTopBorderLeft.color = overlayBorderColor;
                    bubbleTopBorderLeft.alpha = overlayBorderAlpha;
                    bubbleTopBorderRight.color = overlayBorderColor;
                    bubbleTopBorderRight.alpha = overlayBorderAlpha;
                });
                pickerContainer.add(bubbleTriangle);

                pickerContainer.active = true;
                updatePickerPosition();
            }

            if (updatingFromPicker == 0) {
                pickerView.setColorFromRGB(
                    value.red, value.green, value.blue
                );
            }

        }
        else if (!pickerVisible && pickerView != null) {

            pickerView.destroy();
            pickerView = null;

            bubbleTriangle.destroy();
            bubbleTriangle = null;

            pickerContainer.active = false;
        }

        reobserve();

    }

}
