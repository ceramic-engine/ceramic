package elements;

import ceramic.AlphaColor;
import ceramic.Border;
import ceramic.Color;
import ceramic.Mesh;
import ceramic.Point;
import ceramic.Shortcuts.*;
import ceramic.TouchInfo;
import ceramic.View;
import tracker.Observable;

using ceramic.Extensions;

class ColorPickerHSBSpectrumView extends View implements Observable {

    @event function updateHueFromPointer();

    static var _point = new Point();

    static var PRECISION:Int = 16;

    @observe public var movingPointer(default, null):Bool = false;

    var spectrum:Mesh;

    var huePointer:Border;

    public var hue(default, set):Float = 0;
    function set_hue(hue:Float):Float {
        if (this.hue == hue) return hue;
        this.hue = hue;
        updatePointerFromHue();
        return hue;
    }

    public function new() {

        super();

        transparent = true;

        huePointer = new Border();
        huePointer.depth = 2;
        huePointer.borderTopSize = 1;
        huePointer.borderBottomSize = 1;
        huePointer.borderTopColor = Color.WHITE;
        huePointer.borderBottomColor = Color.BLACK;
        huePointer.borderPosition = OUTSIDE;
        huePointer.anchor(0.5, 0.5);
        add(huePointer);

        initSpectrum();

        onPointerDown(this, handlePointerDown);
        onPointerUp(this, handlePointerUp);

    }

    function initSpectrum() {

        spectrum = new Mesh();
        spectrum.colorMapping = VERTICES;
        spectrum.depth = 1;
        add(spectrum);

        spectrum.vertices = [
            0, 0,
            1, 0
        ];

        var vertices = spectrum.vertices;
        var indices = spectrum.indices;
        var colors = spectrum.colors;

        var color = colorWithHue(0);
        colors.push(color);
        colors.push(color);

        for (i in 0...PRECISION) {

            vertices.push(0);
            vertices.push(i + 1);
            vertices.push(1);
            vertices.push(i + 1);

            var color = colorWithHue(360 - (i + 1) * 360 / PRECISION);
            colors.push(color);
            colors.push(color);

            indices.push(i * 2);
            indices.push(i * 2 + 1);
            indices.push(i * 2 + 2);

            indices.push(i * 2 + 1);
            indices.push(i * 2 + 2);
            indices.push(i * 2 + 3);

        }

    }

    function updatePointerFromHue() {

        huePointer.pos(
            width * 0.5,
            height * (1.0 - (hue / 360))
        );

    }

    override function layout() {

        spectrum.scale(
            width,
            height / PRECISION
        );

        huePointer.size(width, 0);

        updatePointerFromHue();

    }

    function colorWithHue(hue:Float):AlphaColor {

        return new AlphaColor(Color.fromHSB(hue, 1, 1));

    }

/// Pointer events

    function handlePointerDown(info:TouchInfo) {

        screen.onPointerMove(this, handlePointerMove);

        updateHueFromTouchInfo(info);

    }

    function handlePointerMove(info:TouchInfo) {

        movingPointer = true;

        updateHueFromTouchInfo(info);

    }

    function handlePointerUp(info:TouchInfo) {

        screen.offPointerMove(handlePointerMove);

        movingPointer = false;

        updateHueFromTouchInfo(info);

    }

    function updateHueFromTouchInfo(info:TouchInfo) {

        screenToVisual(info.x, info.y, _point);

        hue = Math.round((1.0 - Math.max(0, Math.min(_point.y / height, 1.0))) * 360);

        updatePointerFromHue();

        emitUpdateHueFromPointer();

    }

}
