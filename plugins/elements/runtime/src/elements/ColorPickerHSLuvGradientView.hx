package elements;

import ceramic.AlphaColor;
import ceramic.Border;
import ceramic.Color;
import ceramic.Filter;
import ceramic.Mesh;
import ceramic.Point;
import ceramic.Shortcuts.*;
import ceramic.TouchInfo;
import ceramic.Tween;
import ceramic.View;
import tracker.Observable;

using ceramic.Extensions;

class ColorPickerHSLuvGradientView extends View {

    @event function updateColorFromPointer();

    static var PRECISION_X:Int = 32;

    static var PRECISION_Y:Int = 8;

    static var _point = new Point();

    static var _tuple:Array<Float> = [0, 0, 0];

    public var colorValue(default, set):Color = Color.WHITE;
    function set_colorValue(colorValue:Color):Color {
        if (this.colorValue == colorValue) return colorValue;
        this.colorValue = colorValue;
        updateGradientColors();
        updatePointerFromColor();
        return colorValue;
    }

    @:allow(elements.ColorPickerView)
    var movingSpectrum:Bool = false;

    var gradient:Mesh;

    var colorPointer:Border;

    var targetPointerColor:Color = Color.NONE;

    var pointerColorTween:Tween = null;

    var movingPointer:Bool = false;

    var savedPointerX:Float = 0;

    var savedPointerY:Float = 0;

    var filter:Filter;

    public var lightness(default, null):Float = 0.5;

    public function new() {

        super();

        filter = new Filter();
        add(filter);

        transparent = true;

        colorPointer = new Border();
        colorPointer.anchor(0.5, 0.5);
        colorPointer.size(10, 10);
        colorPointer.depth = 3;
        colorPointer.borderPosition = INSIDE;
        colorPointer.borderSize = 1;
        filter.content.add(colorPointer);

        gradient = new Mesh();
        gradient.colorMapping = VERTICES;
        gradient.depth = 1;
        filter.content.add(gradient);

        var vertices = gradient.vertices;
        var indices = gradient.indices;

        for (c in 0...PRECISION_X) {

            vertices.push(c);
            vertices.push(0);
            vertices.push(c + 1);
            vertices.push(0);

            for (r in 0...PRECISION_Y) {

                vertices.push(c);
                vertices.push(r + 1);
                vertices.push(c + 1);
                vertices.push(r + 1);

                var i = r * 2 + c * (PRECISION_Y * 2 + 2);

                indices.push(i);
                indices.push(i + 1);
                indices.push(i + 2);

                indices.push(i + 1);
                indices.push(i + 2);
                indices.push(i + 3);

            }
        }

        updateGradientColors();
        updatePointerFromColor();

        onPointerDown(this, handlePointerDown);
        onPointerUp(this, handlePointerUp);

    }

    public function updateGradientColors(?lightness:Float) {

        if (lightness != null) {
            this.lightness = lightness;
        }

        var colors = gradient.colors;

        var ci = 0;

        for (c in 0...PRECISION_X) {

            colors[ci] = colorWithHueAndSaturation(
                c * 360 / PRECISION_X,
                1
            );
            ci++;
            colors[ci] = colorWithHueAndSaturation(
                (c + 1) * 360 / PRECISION_X,
                1
            );
            ci++;

            for (r in 0...PRECISION_Y) {

                colors[ci] = colorWithHueAndSaturation(
                    c * 360 / PRECISION_X,
                    1.0 - (r + 1) * 1.0 / PRECISION_Y
                );
                ci++;
                colors[ci] = colorWithHueAndSaturation(
                    (c + 1) * 360 / PRECISION_X,
                    1.0 - (r + 1) * 1.0 / PRECISION_Y
                );
                ci++;
            }
        }

    }

    public function savePointerPosition() {

        savedPointerX = colorPointer.x;
        savedPointerY = colorPointer.y;

    }

    public function restorePointerPosition() {

        colorPointer.x = savedPointerX;
        colorPointer.y = savedPointerY;

    }

    public function getSaturationFromPointer():Float {

        var saturation = 1 - (colorPointer.y / height);
        if (saturation < 0)
            saturation = 0;
        if (saturation > 1)
            saturation = 1;

        return saturation;

    }

    public function getHueFromPointer():Float {

        var hue = colorPointer.x / width;
        if (hue < 0)
            hue = 0;
        if (hue > 1)
            hue = 1;
        hue *= 360;

        return hue;

    }

    function colorWithHueAndSaturation(hue:Float, saturation:Float):AlphaColor {

        return new AlphaColor(Color.fromHSLuv(hue, saturation, lightness));

    }

    function updatePointerFromColor() {

        colorValue.getHSLuv(_tuple);

        var hue = _tuple[0] / 360;
        var saturation = _tuple[1];

        colorPointer.pos(
            width * hue,
            height * (1.0 - saturation)
        );

        var newPointerColor = Color.WHITE;
        if (lightness > 0.5) {
            newPointerColor = Color.BLACK;
        }
        targetPointerColor = newPointerColor;

        if (movingSpectrum) {
            if (targetPointerColor != newPointerColor) {
                targetPointerColor = newPointerColor;
                if (pointerColorTween != null) {
                    pointerColorTween.destroy();
                    pointerColorTween = null;
                }
                var startColor = colorPointer.borderColor;
                pointerColorTween = tween(0.4, 0, 1, (v, t) -> {
                    colorPointer.borderColor = Color.interpolate(startColor, targetPointerColor, v);
                });
            }
        }
        else {
            targetPointerColor = newPointerColor;
            colorPointer.borderColor = targetPointerColor;
        }

    }

    override function layout() {

        filter.size(width, height);

        gradient.scale(
            width / PRECISION_X,
            height / PRECISION_Y
        );

        updatePointerFromColor();

    }

/// Pointer events

    function handlePointerDown(info:TouchInfo) {

        screen.onPointerMove(this, handlePointerMove);

        updateColorFromTouchInfo(info);

        movingPointer = true;

    }

    function handlePointerMove(info:TouchInfo) {

        updateColorFromTouchInfo(info);

    }

    function handlePointerUp(info:TouchInfo) {

        screen.offPointerMove(handlePointerMove);

        updateColorFromTouchInfo(info);

        movingPointer = false;

    }

    function updateColorFromTouchInfo(info:TouchInfo) {

        screenToVisual(info.x, info.y, _point);

        var saturation = 1 - (_point.y / height);
        if (saturation < 0)
            saturation = 0;
        if (saturation > 1)
            saturation = 1;

        var hue = _point.x / width;
        if (hue < 0)
            hue = 0;
        if (hue > 1)
            hue = 1;
        hue *= 360;

        this.colorValue = Color.fromHSLuv(
            hue, saturation, lightness
        );

        colorPointer.pos(
            Math.max(0, Math.min(width, _point.x)),
            Math.max(0, Math.min(height, _point.y))
        );

        emitUpdateColorFromPointer();

    }

}
