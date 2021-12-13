package elements;

import ceramic.Color;
import ceramic.GeometryUtils;
import ceramic.LayersLayout;
import ceramic.ReadOnlyArray;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.TouchInfo;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using ceramic.VisualTransition;

class ColorPickerView extends LayersLayout implements Observable implements RelatedToFieldView {

    static final FIELD_ROW_WIDTH = 41.0;

    static final FIELD_ADVANCE = 26.0;

    static final BUTTON_ADVANCE = 24.0;

    static final FIELD_Y_GAP = 1.0;

    static final PADDING = 6.0;

    static final GRADIENT_SIZE = 158.0;

    static final SPECTRUM_WIDTH = 12.0;

    static final PALETTE_COLOR_SIZE = ColorPickerPaletteColorView.PALETTE_COLOR_SIZE;

    static final PALETTE_COLOR_GAP = 2.0;

    static var _tuple:Array<Float> = [0, 0, 0];

/// Public properties

    @observe public var colorValue(default, null):Color = Color.WHITE;

/// Internal

    @compute function draggingColorPreview():ColorPickerPaletteColorView {

        var paletteColorPreviews = this.paletteColorPreviews;

        if (paletteColorPreviews == null)
            return null;

        for (i in 0...paletteColorPreviews.length) {
            var instance = paletteColorPreviews[i];
            if (instance.dragging)
                return instance;
        }

        return null;

    }

    @compute function draggingColorDropIndex():Int {

        var draggingColorPreview = this.draggingColorPreview;
        var paletteColors = this.paletteColors;
        if (draggingColorPreview == null || paletteColors.length == 0) {
            return -1;
        }

        var dragX = draggingColorPreview.offsetX + draggingColorPreview.dragDrop.dragX;
        var dragY = draggingColorPreview.offsetY + draggingColorPreview.dragDrop.dragY;

        var bestIndex = -1;
        var bestDistance = 999999999.0;

        var w = getColorPickerWidth();
        var availableWidth = w - PADDING * 2;

        var x = -(PALETTE_COLOR_SIZE + PALETTE_COLOR_GAP);
        var y = PADDING + GRADIENT_SIZE;

        for (i in 0...paletteColors.length) {
            x += PALETTE_COLOR_SIZE + PALETTE_COLOR_GAP;
            if (x + PALETTE_COLOR_SIZE > availableWidth) {
                x = 0;
                y += PALETTE_COLOR_SIZE + PALETTE_COLOR_GAP;
            }

            var distance = GeometryUtils.distance(
                dragX + PALETTE_COLOR_SIZE * 0.5, dragY + PALETTE_COLOR_SIZE * 0.5,
                x + PALETTE_COLOR_SIZE * 0.5, y + PALETTE_COLOR_SIZE * 0.5
            );
            if (distance < bestDistance) {
                bestIndex = i;
                bestDistance = distance;
            }
        }

        //log.info('distance=$bestDistance index=$bestIndex');

        return bestIndex;

    }

    @observe var paletteHeight:Float = 0;

    var hsluv(get, set):Bool;
    inline function get_hsluv():Bool return context.user.colorPickerHsluv;
    inline function set_hsluv(hsluv:Bool) return context.user.colorPickerHsluv = hsluv;

    var paletteColors(get, set):ReadOnlyArray<Color>;
    inline function get_paletteColors():ReadOnlyArray<Color> return context.user.paletteColors;
    inline function set_paletteColors(paletteColors:ReadOnlyArray<Color>) return context.user.paletteColors = paletteColors;

    var hsbGradientView:ColorPickerHSBGradientView;

    var hsbSpectrumView:ColorPickerHSBSpectrumView;

    var hsluvGradientView:ColorPickerHSLuvGradientView;

    var hsluvSpectrumView:ColorPickerHSLuvSpectrumView;

    var rgbRedField:TextFieldView;

    var rgbGreenField:TextFieldView;

    var rgbBlueField:TextFieldView;

    var rgbRedFieldValue:String = '255';

    var rgbGreenFieldValue:String = '255';

    var rgbBlueFieldValue:String = '255';

    var rgbLabel:TextView;

    var hslHueField:TextFieldView;

    var hslSaturationField:TextFieldView;

    var hslLightnessField:TextFieldView;

    var hslHueFieldValue:String = '0';

    var hslSaturationFieldValue:String = '0';

    var hslLightnessFieldValue:String = '0';

    var hslLabel:TextView;

    var updatingColor:Int = 0;

    var hslFieldsLocked:Int = 0;

    var paletteAddButton:Button;

    var colorModeButton:Button;

    var lastDraggingColorDropIndex:Int = -1;

    var lastDraggingColorPreview:ColorPickerPaletteColorView = null;

    @observe var paletteColorPreviews:Array<ColorPickerPaletteColorView> = [];

    public var colorFieldView(default, null):ColorFieldView;

/// Lifecycle

    public function new(?colorFieldView:ColorFieldView) {

        super();

        this.colorFieldView = colorFieldView;

        padding(PADDING);
        transparent = false;

        borderTopSize = 1;
        borderRightSize = 1;
        borderBottomSize = 1;
        borderLeftSize = 1;
        borderPosition = OUTSIDE;

        roundTranslation = 1;

        onPointerDown(this, _ -> {});
        onPointerOver(this, _ -> {});
        onPointerOut(this, _ -> {});

        component(new TabFocus());

        hsbGradientView = new ColorPickerHSBGradientView();
        hsbGradientView.viewSize(GRADIENT_SIZE, GRADIENT_SIZE);
        hsbGradientView.onUpdateColorFromPointer(this, () -> {
            setColorFromHSB(
                hsbGradientView.hue,
                hsbGradientView.getSaturationFromPointer(),
                hsbGradientView.getBrightnessFromPointer()
            );
        });
        add(hsbGradientView);

        hsluvGradientView = new ColorPickerHSLuvGradientView();
        hsluvGradientView.viewSize(GRADIENT_SIZE, GRADIENT_SIZE);
        hsluvGradientView.onUpdateColorFromPointer(this, () -> {
            setColorFromHSLuv(
                hsluvGradientView.getHueFromPointer(),
                hsluvGradientView.getSaturationFromPointer(),
                hsluvGradientView.lightness
            );
        });
        add(hsluvGradientView);

        hsbSpectrumView = new ColorPickerHSBSpectrumView();
        hsbSpectrumView.viewSize(SPECTRUM_WIDTH, GRADIENT_SIZE);
        hsbSpectrumView.offset(hsbGradientView.viewWidth + PADDING, 0);
        hsbSpectrumView.onMovingPointerChange(this, (moving, _) -> {
            hsbGradientView.movingSpectrum = moving;
        });
        hsbSpectrumView.onUpdateHueFromPointer(this, () -> {
            hsbGradientView.savePointerPosition();
            hsbGradientView.updateTintColor(hsbSpectrumView.hue);
            setColorFromHSB(
                hsbGradientView.hue,
                hsbGradientView.getSaturationFromPointer(),
                hsbGradientView.getBrightnessFromPointer()
            );
            hsbGradientView.restorePointerPosition();
        });
        add(hsbSpectrumView);

        hsluvSpectrumView = new ColorPickerHSLuvSpectrumView();
        hsluvSpectrumView.viewSize(SPECTRUM_WIDTH, GRADIENT_SIZE);
        hsluvSpectrumView.offset(hsluvGradientView.viewWidth + PADDING, 0);
        hsluvSpectrumView.onMovingPointerChange(this, (moving, _) -> {
            hsluvGradientView.movingSpectrum = moving;
        });
        hsluvSpectrumView.onUpdateHueFromPointer(this, () -> {
            hsluvGradientView.savePointerPosition();
            hsluvGradientView.updateGradientColors(hsluvSpectrumView.lightness);
            setColorFromHSLuv(
                hsluvGradientView.getHueFromPointer(),
                hsluvGradientView.getSaturationFromPointer(),
                hsluvGradientView.lightness
            );
            hsluvGradientView.restorePointerPosition();
        });
        add(hsluvSpectrumView);

        var offsetX = hsbGradientView.viewWidth.toFloat() + hsbSpectrumView.viewWidth.toFloat() + PADDING * 2;
        initRGBFields(offsetX);
        offsetX += FIELD_ROW_WIDTH + PADDING;
        var offsetY = initHSLFields(offsetX);

        offsetX = hsbGradientView.viewWidth.toFloat() + hsbSpectrumView.viewWidth.toFloat() + PADDING * 2;
        initPaletteUI(offsetX, offsetY);

        autorun(updateStyle);
        autorun(updateColorPreviews);
        autorun(updateSize);
        autorun(updateFromColorDrop);

    }

    function getColorPickerWidth() {

        return GRADIENT_SIZE + FIELD_ROW_WIDTH * 2 + SPECTRUM_WIDTH + PADDING * 5;

    }

    function updateSize() {

        var w = getColorPickerWidth();
        var h = GRADIENT_SIZE + PADDING * 2;

        var paletteHeight = this.paletteHeight;

        unobserve();

        if (paletteHeight > 0) {
            h += PADDING + paletteHeight;
        }

        viewSize(
            w,
            h
        );

        reobserve();

    }

    function initRGBFields(offsetX:Float) {

        rgbLabel = new TextView();
        rgbLabel.align = CENTER;
        rgbLabel.verticalAlign = CENTER;
        rgbLabel.pointSize = 12;
        rgbLabel.preRenderedSize = 20;
        rgbLabel.content = 'RGB';
        rgbLabel.offset(
            offsetX,
            0
        );
        rgbLabel.viewSize(FIELD_ROW_WIDTH, 12);
        add(rgbLabel);

        rgbRedField = createTextField(setColorFromRGBFields, 0, 256);
        rgbRedField.offset(
            offsetX,
            rgbLabel.offsetY + rgbLabel.viewHeight + PADDING
        );
        add(rgbRedField);

        rgbGreenField = createTextField(setColorFromRGBFields, 0, 256);
        rgbGreenField.offset(
            offsetX,
            rgbRedField.offsetY + FIELD_ADVANCE + FIELD_Y_GAP
        );
        add(rgbGreenField);

        rgbBlueField = createTextField(setColorFromRGBFields, 0, 256);
        rgbBlueField.offset(
            offsetX,
            rgbGreenField.offsetY + FIELD_ADVANCE + FIELD_Y_GAP
        );
        add(rgbBlueField);

        return rgbBlueField.offsetY + FIELD_ADVANCE + PADDING;

    }

    function initHSLFields(offsetX:Float) {

        hslLabel = new TextView();
        hslLabel.align = CENTER;
        hslLabel.verticalAlign = CENTER;
        hslLabel.pointSize = 12;
        hslLabel.preRenderedSize = 20;
        hslLabel.offset(
            offsetX,
            0
        );
        hslLabel.viewSize(FIELD_ROW_WIDTH, 12);
        add(hslLabel);

        hslLabel.autorun(() -> {
            var hsluv = this.hsluv;
            unobserve();

            if (hsluv) {
                hslLabel.content = 'HSLuv';
                hsbGradientView.active = false;
                hsbSpectrumView.active = false;
                hsluvGradientView.active = true;
                hsluvSpectrumView.active = true;
            }
            else {
                hslLabel.content = 'HSL';
                hsbGradientView.active = true;
                hsbSpectrumView.active = true;
                hsluvGradientView.active = false;
                hsluvSpectrumView.active = false;
            }
        });

        /*
        hslLabel.onPointerDown(this, _ -> {
            this.hsluv = !this.hsluv;
            setColorFromRGB(colorValue.red, colorValue.green, colorValue.blue);
        });
        */

        hslHueField = createTextField(setColorFromHSLFieldHue, 0, 360);
        hslHueField.offset(
            offsetX,
            hslLabel.offsetY + hslLabel.viewHeight + PADDING
        );
        add(hslHueField);

        hslSaturationField = createTextField(setColorFromHSLFieldSaturation, 0, 100);
        hslSaturationField.offset(
            offsetX,
            hslHueField.offsetY + FIELD_ADVANCE + FIELD_Y_GAP
        );
        add(hslSaturationField);

        hslLightnessField = createTextField(setColorFromHSLFieldLightness, 0, 100);
        hslLightnessField.offset(
            offsetX,
            hslSaturationField.offsetY + FIELD_ADVANCE + FIELD_Y_GAP
        );
        add(hslLightnessField);

        return hslLightnessField.offsetY + FIELD_ADVANCE + PADDING;

    }

    function initPaletteUI(offsetX:Float, offsetY:Float) {

        colorModeButton = new Button();
        colorModeButton.content = 'Color mode';
        colorModeButton.inputStyle = OVERLAY;
        colorModeButton.viewWidth = FIELD_ROW_WIDTH * 2 + PADDING;
        colorModeButton.offset(offsetX, offsetY);
        colorModeButton.onClick(this, switchColorMode);
        add(colorModeButton);

        offsetY += BUTTON_ADVANCE + PADDING;

        paletteAddButton = new Button();
        paletteAddButton.inputStyle = OVERLAY;
        paletteAddButton.viewWidth = FIELD_ROW_WIDTH * 2 + PADDING;
        paletteAddButton.offset(offsetX, offsetY);
        paletteAddButton.onClick(this, () -> {
            var colorIndex = paletteColors.indexOf(colorValue);
            if (colorIndex != -1) {
                context.user.removePaletteColor(colorIndex);
            }
            else {
                saveColor();
            }
        });
        paletteAddButton.autorun(() -> {
            var colorExists = paletteColors.indexOf(colorValue) != -1;
            unobserve();
            if (colorExists) {
                paletteAddButton.content = 'Delete color';
            }
            else {
                paletteAddButton.content = 'Save color';
            }
        });
        add(paletteAddButton);


    }

/// Layout

    override function layout() {

        super.layout();

    }

/// Public API

    public function setColorFromRGB(r:Int, g:Int, b:Int) {

        updatingColor++;

        colorValue = Color.fromRGB(r, g, b);

        // Update RGB fields
        updateRGBFields(colorValue);

        // Update HSL fields
        updateHSLFields(colorValue);

        // Update gradient & spectrum
        updateGradientAndSpectrum(colorValue);

        app.onceUpdate(this, _ -> {
            updatingColor--;
        });

    }

    public function setColorFromHSL(h:Float, s:Float, l:Float) {

        updatingColor++;

        colorValue = Color.fromHSL(h, s, l);

        // Update RGB fields
        updateRGBFields(colorValue);

        // Update HSL fields
        updateHSLFields(colorValue, h, s, l);

        // Update gradient & spectrum
        updateGradientAndSpectrum(colorValue, h, s, l);

        app.onceUpdate(this, _ -> {
            updatingColor--;
        });

    }

    public function setColorFromHSB(h:Float, s:Float, b:Float) {

        updatingColor++;

        colorValue = Color.fromHSB(h, s, b);

        // Update RGB fields
        updateRGBFields(colorValue);

        // Update HSL fields
        updateHSLFields(colorValue, h);

        // Update gradient & spectrum
        updateGradientAndSpectrum(colorValue, h);

        app.onceUpdate(this, _ -> {
            updatingColor--;
        });

    }

    public function setColorFromHSLuv(h:Float, s:Float, l:Float) {

        updatingColor++;

        colorValue = Color.fromHSLuv(h, s, l);

        // Update RGB fields
        updateRGBFields(colorValue);

        // Update HSL fields
        updateHSLFields(colorValue, h, s, l);

        // Update gradient & spectrum
        updateGradientAndSpectrum(colorValue, h, s, l);

        app.onceUpdate(this, _ -> {
            updatingColor--;
        });

    }

/// Internal

    function updateRGBFields(colorValue:Color) {

        rgbRedField.setTextValue(rgbRedField, '' + colorValue.red);
        rgbGreenField.setTextValue(rgbGreenField, '' + colorValue.green);
        rgbBlueField.setTextValue(rgbBlueField, '' + colorValue.blue);

    }

    function updateHSLFields(colorValue:Color, ?hue:Float, ?saturation:Float, ?lightness:Float) {

        if (hslFieldsLocked > 0)
            return;

        if (hsluv) {
            colorValue.getHSLuv(_tuple);
            if (hue == null)
                hue = _tuple[0];
            if (saturation == null)
                saturation = _tuple[1];
            if (lightness == null)
                lightness = _tuple[2];
        }
        else {
            if (hue == null)
                hue = colorValue.hue;
            if (saturation == null)
                saturation = colorValue.saturation;
            if (lightness == null)
                lightness = colorValue.lightness;
        }

        hslHueField.setTextValue(hslHueField, '' + Math.round(hue));
        hslSaturationField.setTextValue(hslSaturationField, '' + (Math.round(saturation * 1000) / 10));
        hslLightnessField.setTextValue(hslLightnessField, '' + (Math.round(lightness * 1000) / 10));

    }

    function updateGradientAndSpectrum(colorValue:Color, ?hue:Float, ?saturation:Float, ?lightness:Float) {

        if (hsluv) {
            colorValue.getHSLuv(_tuple);
            if (hue == null)
                hue = _tuple[0];
            if (saturation == null)
                saturation = _tuple[1];
            if (lightness == null)
                lightness = _tuple[2];

            // Update gradient
            hsluvGradientView.colorValue = colorValue;
            hsluvGradientView.updateGradientColors(lightness);
            hsbGradientView.colorValue = colorValue;
            hsbGradientView.updateTintColor(colorValue.hue);

            // Update spectrum
            hsluvSpectrumView.lightness = lightness;
            hsluvSpectrumView.hue = hue;
            hsbSpectrumView.hue = colorValue.hue;
        }
        else {
            if (hue == null)
                hue = colorValue.hue;
            if (saturation == null)
                saturation = colorValue.saturation;
            if (lightness == null)
                lightness = colorValue.lightness;
            colorValue.getHSLuv(_tuple);

            // Update gradient
            hsbGradientView.colorValue = colorValue;
            hsbGradientView.updateTintColor(hue);
            hsluvGradientView.colorValue = colorValue;
            hsluvGradientView.updateGradientColors(_tuple[2]);

            // Update spectrum
            hsbSpectrumView.hue = hue;
            hsluvSpectrumView.hue = _tuple[0];
            hsluvSpectrumView.lightness = _tuple[2];
        }

    }

    function setColorFromRGBFields() {

        if (rgbRedField.textValue == rgbRedFieldValue
            && rgbGreenField.textValue == rgbGreenFieldValue
            && rgbBlueField.textValue == rgbBlueFieldValue)
            return;

        rgbRedFieldValue = rgbRedField.textValue;
        rgbGreenFieldValue = rgbGreenField.textValue;
        rgbBlueFieldValue = rgbBlueField.textValue;

        if (updatingColor > 0)
            return;

        setColorFromRGB(
            Std.parseInt(rgbRedField.textValue),
            Std.parseInt(rgbGreenField.textValue),
            Std.parseInt(rgbBlueField.textValue)
        );

    }

    function setColorFromHSLFieldHue() {

        if (hslHueField.textValue == hslHueFieldValue)
            return;

        hslHueFieldValue = hslHueField.textValue;

        if (updatingColor > 0)
            return;

        hslFieldsLocked++;

        var hue = Std.parseFloat(hslHueField.textValue);
        var saturation = Std.parseFloat(hslSaturationField.textValue) * 0.01;

        if (hsluv) {
            setColorFromHSLuv(
                hue,
                saturation,
                hsluvGradientView.lightness
            );
        }
        else {
            hsbGradientView.savePointerPosition();
            hsbGradientView.updateTintColor(hue);
            setColorFromHSB(
                hsbGradientView.hue,
                hsbGradientView.getSaturationFromPointer(),
                hsbGradientView.getBrightnessFromPointer()
            );
            hsbGradientView.restorePointerPosition();
        }

        app.onceUpdate(this, _ -> {
            hslFieldsLocked--;
        });

    }

    function setColorFromHSLFieldSaturation() {

        if (hslSaturationField.textValue == hslSaturationFieldValue)
            return;

        hslSaturationFieldValue = hslSaturationField.textValue;

        if (updatingColor > 0)
            return;

        hslFieldsLocked++;

        var hue = Std.parseFloat(hslHueField.textValue);
        var saturation = Std.parseFloat(hslSaturationField.textValue) * 0.01;
        var lightness = Std.parseFloat(hslLightnessField.textValue) * 0.01;

        if (hsluv) {
            setColorFromHSLuv(
                hue,
                saturation,
                hsluvGradientView.lightness
            );
        }
        else {
            setColorFromHSL(
                hsbGradientView.hue,
                saturation,
                lightness
            );
        }

        app.onceUpdate(this, _ -> {
            hslFieldsLocked--;
        });

    }

    function setColorFromHSLFieldLightness() {

        if (hslLightnessField.textValue == hslLightnessFieldValue)
            return;

        hslLightnessFieldValue = hslLightnessField.textValue;

        if (updatingColor > 0)
            return;

        hslFieldsLocked++;

        var saturation = Std.parseFloat(hslSaturationField.textValue) * 0.01;
        var lightness = Std.parseFloat(hslLightnessField.textValue) * 0.01;

        if (hsluv) {
            hsluvGradientView.savePointerPosition();
            hsluvGradientView.updateGradientColors(lightness);
            setColorFromHSLuv(
                hsluvGradientView.getHueFromPointer(),
                hsluvGradientView.getSaturationFromPointer(),
                hsluvGradientView.lightness
            );
            hsluvGradientView.restorePointerPosition();
        }
        else {
            setColorFromHSL(
                hsbGradientView.hue,
                saturation,
                lightness
            );
        }

        app.onceUpdate(this, _ -> {
            hslFieldsLocked--;
        });

    }

    /*
    function setColorFromHSLFields() {

        if (updatingFromHSL > 0 || updatingFromHSB > 0 || updatingFromRGB > 0)
            return;

        setColorFromHSL(
            Std.parseInt(hslHueField.textValue),
            Std.parseFloat(hslSaturationField.textValue) * 0.01,
            Std.parseFloat(hslLightnessField.textValue) * 0.01
        );

    }
    */

    function createTextField(?applyValue:Void->Void, minValue:Int = 0, maxValue:Int = 100) {

        var fieldView = new TextFieldView(NUMERIC);
        fieldView.textAlign = CENTER;
        fieldView.inputStyle = OVERLAY;
        fieldView.textValue = '0';
        fieldView.viewWidth = FIELD_ROW_WIDTH;

        fieldView.setTextValue = function(field, textValue) {
            if (applyValue != null) {
                app.oncePostFlushImmediate(applyValue);
            }
            return SanitizeTextField.setTextValueToInt(field, textValue, minValue, maxValue);
        };
        fieldView.setEmptyValue = function(field) {
            var value:Int = 0;
            if (value < minValue) {
                value = minValue;
            }
            if (value > maxValue) {
                value = maxValue;
            }
            fieldView.textValue = '' + value;
            if (applyValue != null) {
                applyValue();
            }
        };

        return fieldView;

    }

    function updateStyle() {

        var theme = context.theme;

        borderColor = theme.overlayBorderColor;
        borderAlpha = theme.overlayBorderAlpha;

        color = theme.overlayBackgroundColor;
        alpha = theme.overlayBackgroundAlpha;

        rgbLabel.textColor = theme.lightTextColor;
        rgbLabel.font = theme.mediumFont;

        hslLabel.textColor = theme.lightTextColor;
        hslLabel.font = theme.mediumFont;

    }

    function saveColor() {

        context.user.addPaletteColor(colorValue);

    }

    function switchColorMode() {

        this.hsluv = !this.hsluv;
        setColorFromRGB(colorValue.red, colorValue.green, colorValue.blue);

    }

    function updateColorPreviews() {

        var paletteColors = this.paletteColors;
        var draggingColorPreview = this.draggingColorPreview;
        var draggingColorDropIndex = this.draggingColorDropIndex;

        unobserve();

        var didChange = false;

        while (paletteColorPreviews.length > paletteColors.length) {
            var toRemove = paletteColorPreviews.pop();
            toRemove.destroy();
            didChange = true;
        }

        while (paletteColorPreviews.length < paletteColors.length) {
            var toAdd = createColorPreview();
            add(toAdd);
            paletteColorPreviews.push(toAdd);
            didChange = true;
        }

        var paletteColorDragIndex = -1;
        if (draggingColorPreview != null) {
            paletteColorDragIndex = paletteColorPreviews.indexOf(draggingColorPreview);
        }

        if (paletteColors.length > 0) {

            var w = getColorPickerWidth();
            var availableWidth = w - PADDING * 2;

            var x = -(PALETTE_COLOR_SIZE + PALETTE_COLOR_GAP);
            var y = PADDING + GRADIENT_SIZE;

            for (i in 0...paletteColors.length) {
                x += PALETTE_COLOR_SIZE + PALETTE_COLOR_GAP;
                if (x + PALETTE_COLOR_SIZE > availableWidth) {
                    x = 0;
                    y += PALETTE_COLOR_SIZE + PALETTE_COLOR_GAP;
                }

                var n = i;

                if (draggingColorDropIndex != -1) {
                    if (i >= paletteColorDragIndex && i <= draggingColorDropIndex) {
                        n++;
                    }
                    else if (i <= paletteColorDragIndex && i > draggingColorDropIndex) {
                        n--;
                    }
                }

                var colorPreview = paletteColorPreviews[n];
                if (colorPreview != null) {
                    colorPreview.colorValue = paletteColors[n];
                    var transitionDuration = 0.0;
                    if (draggingColorPreview != null && draggingColorPreview != colorPreview && colorPreview.offsetY == y) {
                        transitionDuration = 0.1;
                    }
                    colorPreview.transition(transitionDuration, colorPreview -> {
                        colorPreview.offset(x, y);
                    });
                }
            }

            this.paletteHeight = y + PALETTE_COLOR_SIZE - GRADIENT_SIZE - PADDING;
        }
        else {
            this.paletteHeight = 0;
        }

        if (didChange) {
            invalidatePaletteColorPreviews();
        }

        reobserve();

    }

    function updateFromColorDrop() {

        var draggingColorDropIndex = this.draggingColorDropIndex;
        if (draggingColorDropIndex != -1)
            lastDraggingColorDropIndex = draggingColorDropIndex;

        var draggingColorPreview = this.draggingColorPreview;
        if (draggingColorPreview != null)
            lastDraggingColorPreview = draggingColorPreview;

    }

    function createColorPreview():ColorPickerPaletteColorView {

        var colorPreview = new ColorPickerPaletteColorView();

        colorPreview.onClick(this, handlePaletteColorClick);
        colorPreview.onDrop(this, handlePaletteColorDrop);
        colorPreview.onLongPress(this, handlePaletteColorLongPress);

        return colorPreview;

    }

    function handlePaletteColorClick(colorPreview:ColorPickerPaletteColorView) {

        var colorValue = colorPreview.colorValue;

        setColorFromRGB(
            colorValue.red,
            colorValue.green,
            colorValue.blue
        );

    }

    function handlePaletteColorDrop(colorPreview:ColorPickerPaletteColorView) {

        var lastDraggingColorDragIndex = paletteColorPreviews.indexOf(draggingColorPreview);

        context.user.movePaletteColor(lastDraggingColorDragIndex, lastDraggingColorDropIndex);

    }

    function handlePaletteColorLongPress(colorPreview:ColorPickerPaletteColorView, info:TouchInfo) {

        var index = paletteColorPreviews.indexOf(colorPreview);

        if (index != -1)
            context.user.removePaletteColor(index);

    }

/// Related field view

    public function relatedFieldView():FieldView {

        return colorFieldView;

    }

}
