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

/**
 * A vertical spectrum view for HSLuv color selection showing lightness values.
 * This component displays a gradient from light to dark (top to bottom) for a
 * specific hue and saturation combination in the HSLuv color space.
 * 
 * The spectrum provides:
 * - Vertical gradient showing lightness from 100% (top) to 0% (bottom)
 * - Interactive pointer for selecting lightness values
 * - Visual feedback with contrasting border colors for visibility
 * 
 * Used in conjunction with ColorPickerHSLuvGradientView to provide complete
 * HSLuv color selection capabilities.
 * 
 * @event updateHueFromPointer Emitted when lightness is updated via pointer interaction
 */
class ColorPickerHSLuvSpectrumView extends View implements Observable {

    @event function updateHueFromPointer();

    /** Reusable point for coordinate conversions */
    static var _point = new Point();

    /** Number of gradient segments for smooth lightness transitions */
    static var PRECISION:Int = 16;

    /** Observable flag indicating the pointer is being dragged */
    @observe public var movingPointer(default, null):Bool = false;

    /** The mesh that renders the lightness gradient */
    var spectrum:Mesh;

    /** Visual pointer indicating the current lightness selection */
    var lightnessPointer:Border;

    /**
     * The current lightness value (0-1).
     * Updates the pointer position when changed.
     */
    public var lightness(default, set):Float = 0.5;
    function set_lightness(lightness:Float):Float {
        if (this.lightness == lightness) return lightness;
        this.lightness = lightness;
        updatePointerFromLightness();
        return lightness;
    }

    /**
     * The hue value in degrees (0-360) used for the spectrum.
     * Changing this regenerates the gradient colors.
     */
    public var hue(default, set):Float = 0;
    function set_hue(hue:Float):Float {
        if (this.hue == hue) return hue;
        this.hue = hue;
        spectrumColorsDirty = true;
        return hue;
    }

    /**
     * The saturation value (0-1) used for the spectrum.
     * Changing this regenerates the gradient colors.
     */
    public var saturation(default, set):Float = 1;
    function set_saturation(saturation:Float):Float {
        if (this.saturation == saturation) return saturation;
        this.saturation = saturation;
        spectrumColorsDirty = true;
        return saturation;
    }

    /** Flag to defer spectrum color updates until next frame */
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

    /**
     * Creates a new HSLuv spectrum view for lightness selection.
     * Initializes the gradient mesh and horizontal pointer.
     */
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

    /**
     * Initializes the spectrum mesh with vertices and indices.
     * Creates a vertical gradient with the specified precision.
     */
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

    /**
     * Updates the spectrum mesh colors based on current hue and saturation.
     * Creates a smooth gradient from light to dark in HSLuv space.
     */
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

    /**
     * Updates the pointer position based on the current lightness value.
     * Positions the pointer vertically with light at top, dark at bottom.
     */
    function updatePointerFromLightness() {

        lightnessPointer.pos(
            width * 0.5,
            height * (1.0 - lightness)
        );

    }

    /**
     * Handles layout updates when the view is resized.
     * Scales the spectrum mesh and adjusts pointer dimensions.
     */
    override function layout() {

        spectrum.scale(
            width,
            height / PRECISION
        );

        lightnessPointer.size(width, 0);

        updatePointerFromLightness();

    }

    /**
     * Creates a color with the specified lightness using current hue and saturation.
     * @param lightness The lightness value (0-1)
     * @return The resulting color in HSLuv space with full opacity
     */
    function colorWithLightness(lightness:Float):AlphaColor {

        //return new AlphaColor(Color.fromHSL(0, 0, lightness));
        return new AlphaColor(Color.fromHSLuv(hue, saturation, lightness));

    }

/// Pointer events

    /**
     * Handles pointer down events to begin lightness selection.
     * @param info Touch/mouse information
     */
    function handlePointerDown(info:TouchInfo) {

        screen.onPointerMove(this, handlePointerMove);

        updateHueFromTouchInfo(info);

    }

    /**
     * Handles pointer move events during lightness selection.
     * Sets the moving flag and updates the lightness value.
     * @param info Touch/mouse information
     */
    function handlePointerMove(info:TouchInfo) {

        movingPointer = true;

        updateHueFromTouchInfo(info);

    }

    /**
     * Handles pointer up events to end lightness selection.
     * Clears the moving flag and finalizes the selection.
     * @param info Touch/mouse information
     */
    function handlePointerUp(info:TouchInfo) {

        screen.offPointerMove(handlePointerMove);

        movingPointer = false;

        updateHueFromTouchInfo(info);

    }

    /**
     * Updates the lightness value based on touch/mouse position.
     * Converts vertical position to lightness (top=1, bottom=0).
     * @param info Touch/mouse information containing screen coordinates
     */
    function updateHueFromTouchInfo(info:TouchInfo) {

        screenToVisual(info.x, info.y, _point);

        lightness = 1.0 - Math.max(0, Math.min(_point.y / height, 1));

        updatePointerFromLightness();

        emitUpdateHueFromPointer();

    }

}
