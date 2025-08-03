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

/**
 * A color picker gradient view using the HSLuv color space for perceptually uniform color selection.
 * HSLuv is a human-friendly alternative to HSL that maintains perceptual uniformity across hue
 * and saturation changes, making color selection more intuitive.
 * 
 * The gradient displays:
 * - Hue along the horizontal axis (0-360 degrees)
 * - Saturation along the vertical axis (100% at top, 0% at bottom)
 * - Lightness controlled externally and applied uniformly
 * 
 * Users can select colors by clicking/dragging on the gradient, with a visual pointer
 * indicating the current selection. The pointer automatically adjusts its color for
 * visibility based on the lightness value.
 * 
 * @event updateColorFromPointer Emitted when the color is updated via pointer interaction
 */
class ColorPickerHSLuvGradientView extends View {

    @event function updateColorFromPointer();

    /** Number of horizontal segments in the gradient mesh for hue precision */
    static var PRECISION_X:Int = 32;

    /** Number of vertical segments in the gradient mesh for saturation precision */
    static var PRECISION_Y:Int = 8;

    /** Reusable point for coordinate conversions */
    static var _point = new Point();

    /** Reusable array for HSLuv color conversions */
    static var _tuple:Array<Float> = [0, 0, 0];

    /**
     * The currently selected color value.
     * Setting this updates the gradient and pointer position.
     */
    public var colorValue(default, set):Color = Color.WHITE;
    function set_colorValue(colorValue:Color):Color {
        if (this.colorValue == colorValue) return colorValue;
        this.colorValue = colorValue;
        updateGradientColors();
        updatePointerFromColor();
        return colorValue;
    }

    /** Internal flag indicating the spectrum (lightness) is being adjusted */
    @:allow(elements.ColorPickerView)
    var movingSpectrum:Bool = false;

    /** The mesh that renders the HSLuv gradient */
    var gradient:Mesh;

    /** Visual pointer indicating the current color selection */
    var colorPointer:Border;

    /** Target color for pointer border animation */
    var targetPointerColor:Color = Color.NONE;

    /** Active tween for animating pointer color changes */
    var pointerColorTween:Tween = null;

    /** Flag indicating the pointer is being dragged */
    var movingPointer:Bool = false;

    /** Saved X position of the pointer for restoration */
    var savedPointerX:Float = 0;

    /** Saved Y position of the pointer for restoration */
    var savedPointerY:Float = 0;

    /** Filter container for the gradient content */
    var filter:Filter;

    /**
     * The lightness value (0-1) applied uniformly across the gradient.
     * This is typically controlled by an external spectrum/slider.
     */
    public var lightness(default, null):Float = 0.5;

    /**
     * Creates a new HSLuv gradient color picker view.
     * Initializes the gradient mesh and selection pointer.
     */
    public function new() {

        super();

        filter = new Filter();
        filter.textureFilter = NEAREST;
        add(filter);

        transparent = true;

        colorPointer = new Border();
        colorPointer.anchor(0.5, 0.5);
        colorPointer.size(10, 10);
        colorPointer.depth = 3;
        colorPointer.borderPosition = INSIDE;
        colorPointer.borderSize = 1;
        colorPointer.roundTranslation = 1;
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

        filter.content.onPointerDown(this, handlePointerDown);
        filter.content.onPointerUp(this, handlePointerUp);

    }

    /**
     * Updates the gradient mesh colors based on the current lightness value.
     * Regenerates all vertex colors to reflect the HSLuv color space.
     * @param lightness Optional new lightness value (0-1)
     */
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

    /**
     * Saves the current pointer position for later restoration.
     * Useful when temporarily moving the pointer during spectrum adjustments.
     */
    public function savePointerPosition() {

        savedPointerX = colorPointer.x;
        savedPointerY = colorPointer.y;

    }

    /**
     * Restores the pointer to its previously saved position.
     */
    public function restorePointerPosition() {

        colorPointer.x = savedPointerX;
        colorPointer.y = savedPointerY;

    }

    /**
     * Calculates the saturation value based on the pointer's vertical position.
     * @return Saturation value (0-1), where 1 is at the top
     */
    public function getSaturationFromPointer():Float {

        var saturation = 1 - (colorPointer.y / height);
        if (saturation < 0)
            saturation = 0;
        if (saturation > 1)
            saturation = 1;

        return saturation;

    }

    /**
     * Calculates the hue value based on the pointer's horizontal position.
     * @return Hue value in degrees (0-360)
     */
    public function getHueFromPointer():Float {

        var hue = colorPointer.x / width;
        if (hue < 0)
            hue = 0;
        if (hue > 1)
            hue = 1;
        hue *= 360;

        return hue;

    }

    /**
     * Creates a color with the specified hue and saturation using the current lightness.
     * @param hue Hue value in degrees (0-360)
     * @param saturation Saturation value (0-1)
     * @return The resulting color with full opacity
     */
    function colorWithHueAndSaturation(hue:Float, saturation:Float):AlphaColor {

        return new AlphaColor(Color.fromHSLuv(hue, saturation, lightness));

    }

    /**
     * Updates the pointer position based on the current color value.
     * Also adjusts the pointer border color for visibility.
     */
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

    /**
     * Handles layout updates when the view is resized.
     * Scales the gradient mesh and updates pointer position accordingly.
     */
    override function layout() {

        filter.size(width, height);

        gradient.scale(
            width / PRECISION_X,
            height / PRECISION_Y
        );

        updatePointerFromColor();

    }

/// Pointer events

    /**
     * Handles pointer down events to begin color selection.
     * @param info Touch/mouse information
     */
    function handlePointerDown(info:TouchInfo) {

        screen.onPointerMove(this, handlePointerMove);

        updateColorFromTouchInfo(info);

        movingPointer = true;

    }

    /**
     * Handles pointer move events during color selection.
     * @param info Touch/mouse information
     */
    function handlePointerMove(info:TouchInfo) {

        updateColorFromTouchInfo(info);

    }

    /**
     * Handles pointer up events to end color selection.
     * @param info Touch/mouse information
     */
    function handlePointerUp(info:TouchInfo) {

        screen.offPointerMove(handlePointerMove);

        updateColorFromTouchInfo(info);

        movingPointer = false;

    }

    /**
     * Updates the selected color based on touch/mouse position.
     * Converts screen coordinates to hue/saturation values and updates the color.
     * @param info Touch/mouse information containing screen coordinates
     */
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
