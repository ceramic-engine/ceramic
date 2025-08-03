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
 * A vertical hue spectrum selector for HSB color space.
 * 
 * This view displays a vertical gradient showing the full color spectrum
 * from 0° to 360° (red to red through the rainbow). Users can select
 * a hue by clicking or dragging along the spectrum.
 * 
 * Features:
 * - Smooth gradient mesh with configurable precision
 * - Interactive pointer with black/white borders for visibility
 * - Vertical layout (top = 360°/0° red, bottom = 0°/360° red)
 * - Observable pointer movement state
 * 
 * The spectrum is rendered as a mesh with multiple colored segments
 * for smooth color transitions. The precision can be adjusted via
 * the PRECISION constant.
 * 
 * @see ColorPickerView
 * @see ColorPickerHSBGradientView
 */
class ColorPickerHSBSpectrumView extends View implements Observable {

    /**
     * Event emitted when the hue is updated via pointer interaction.
     */
    @event function updateHueFromPointer();

    /**
     * Shared point instance for coordinate calculations.
     */
    static var _point = new Point();

    /**
     * Number of color segments in the spectrum gradient.
     * Higher values create smoother gradients.
     */
    static var PRECISION:Int = 16;

    /**
     * Whether the pointer is currently being moved.
     * Observable property for coordinating with other components.
     */
    @observe public var movingPointer(default, null):Bool = false;

    /**
     * The mesh displaying the color spectrum gradient.
     */
    var spectrum:Mesh;

    /**
     * The horizontal line pointer indicating the selected hue.
     */
    var huePointer:Border;

    /**
     * The current hue value (0-360 degrees).
     * Setting this updates the pointer position.
     */
    public var hue(default, set):Float = 0;
    function set_hue(hue:Float):Float {
        if (this.hue == hue) return hue;
        this.hue = hue;
        updatePointerFromHue();
        return hue;
    }

    /**
     * Creates a new HSB spectrum view.
     * 
     * Initializes:
     * - Gradient mesh with color spectrum
     * - Horizontal pointer with contrasting borders
     * - Pointer event handlers
     */
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

    /**
     * Initializes the spectrum gradient mesh.
     * Creates a vertical gradient with segments for each hue value,
     * distributed according to the PRECISION constant.
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

    /**
     * Updates the pointer position based on the current hue value.
     * The pointer moves vertically with 0° at the bottom and 360° at the top.
     */
    function updatePointerFromHue() {

        huePointer.pos(
            width * 0.5,
            height * (1.0 - (hue / 360))
        );

    }

    /**
     * Lays out the spectrum and pointer to fit the view dimensions.
     */
    override function layout() {

        spectrum.scale(
            width,
            height / PRECISION
        );

        huePointer.size(width, 0);

        updatePointerFromHue();

    }

    /**
     * Creates a color with maximum saturation and brightness for the given hue.
     * 
     * @param hue The hue value in degrees (0-360)
     * @return An AlphaColor with the specified hue at full saturation/brightness
     */
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

    /**
     * Updates the hue based on touch/pointer position.
     * Calculates the hue from the Y coordinate (inverted so top = 360°).
     * 
     * @param info Touch information containing pointer coordinates
     */
    function updateHueFromTouchInfo(info:TouchInfo) {

        screenToVisual(info.x, info.y, _point);

        hue = Math.round((1.0 - Math.max(0, Math.min(_point.y / height, 1.0))) * 360);

        updatePointerFromHue();

        emitUpdateHueFromPointer();

    }

}
