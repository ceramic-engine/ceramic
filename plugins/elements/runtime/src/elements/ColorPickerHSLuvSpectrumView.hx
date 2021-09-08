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

class ColorPickerHSLuvSpectrumView extends View implements Observable {

    @event function updateHueFromPointer();

    static var _point = new Point();

    static var PRECISION:Int = 16;

    @observe public var movingPointer(default, null):Bool = false;

    var spectrum:Mesh;

    var lightnessPointer:Border;

    public var lightness(default, set):Float = 0.5;
    function set_lightness(lightness:Float):Float {
        if (this.lightness == lightness) return lightness;
        this.lightness = lightness;
        updatePointerFromLightness();
        return lightness;
    }

    public var hue(default, set):Float = 0;
    function set_hue(hue:Float):Float {
        if (this.hue == hue) return hue;
        this.hue = hue;
        spectrumColorsDirty = true;
        return hue;
    }

    public var saturation(default, set):Float = 1;
    function set_saturation(saturation:Float):Float {
        if (this.saturation == saturation) return saturation;
        this.saturation = saturation;
        spectrumColorsDirty = true;
        return saturation;
    }

    var spectrumColorsDirty(default, set):Bool = false;
    function set_spectrumColorsDirty(spectrumColorsDirty:Bool):Bool {
        if (spectrumColorsDirty) {
            if (!this.spectrumColorsDirty) {
                this.spectrumColorsDirty = true;
                app.onceImmediate(updateSpectrumColors);
            }
        }
        else {
            this.spectrumColorsDirty = false;
        }
        return spectrumColorsDirty;
    }

    public function new() {

        super();

        transparent = true;

        lightnessPointer = new Border();
        lightnessPointer.depth = 2;
        lightnessPointer.borderTopSize = 1;
        lightnessPointer.borderBottomSize = 1;
        lightnessPointer.borderTopColor = Color.WHITE;
        lightnessPointer.borderBottomColor = Color.BLACK;
        lightnessPointer.borderPosition = OUTSIDE;
        lightnessPointer.anchor(0.5, 0.5);
        add(lightnessPointer);

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

        for (i in 0...PRECISION) {

            vertices.push(0);
            vertices.push(i + 1);
            vertices.push(1);
            vertices.push(i + 1);

            indices.push(i * 2);
            indices.push(i * 2 + 1);
            indices.push(i * 2 + 2);

            indices.push(i * 2 + 1);
            indices.push(i * 2 + 2);
            indices.push(i * 2 + 3);

        }

        updateSpectrumColors();

    }

    function updateSpectrumColors() {

        spectrumColorsDirty = false;

        var colors = spectrum.colors;

        var color = colorWithLightness(1);
        var ci = 0;
        colors[ci] = color;
        ci++;
        colors[ci] = color;
        ci++;

        for (i in 0...PRECISION) {

            var color = colorWithLightness(1.0 - (i + 1) * 1.0 / PRECISION);
            colors[ci] = color;
            ci++;
            colors[ci] = color;
            ci++;
        }

    }

    function updatePointerFromLightness() {

        lightnessPointer.pos(
            width * 0.5,
            height * (1.0 - lightness)
        );

    }

    override function layout() {

        spectrum.scale(
            width,
            height / PRECISION
        );

        lightnessPointer.size(width, 0);

        updatePointerFromLightness();

    }

    function colorWithLightness(lightness:Float):AlphaColor {

        //return new AlphaColor(Color.fromHSL(0, 0, lightness));
        return new AlphaColor(Color.fromHSLuv(hue, saturation, lightness));

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

        lightness = 1.0 - Math.max(0, Math.min(_point.y / height, 1));

        updatePointerFromLightness();

        emitUpdateHueFromPointer();

    }

}
