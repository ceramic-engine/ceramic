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

using ceramic.Extensions;

/**
 * A gradient color selector for HSB (Hue, Saturation, Brightness) color space.
 * 
 * This view displays a 2D gradient where:
 * - X-axis represents saturation (0-100%)
 * - Y-axis represents brightness (100-0%, inverted)
 * - The gradient is tinted with the current hue
 * 
 * The view features:
 * - Interactive pointer for selecting saturation and brightness
 * - Two gradient layers: tint (hue-based) and black overlay
 * - Smooth pointer color transitions (white on dark areas, black on light)
 * - Pixel-perfect rendering with nearest neighbor filtering
 * 
 * This component is typically used within ColorPickerView as part of the
 * HSB color selection interface.
 * 
 * @see ColorPickerView
 * @see ColorPickerHSBSpectrumView
 */
class ColorPickerHSBGradientView extends View {

    /**
     * Event emitted when the color is updated via pointer interaction.
     */
    @event function updateColorFromPointer();

    /**
     * Shared point instance for coordinate calculations.
     */
    static var _point = new Point();

    /**
     * Shared array for HSL color space calculations.
     */
    static var _tuple:Array<Float> = [0, 0, 0];

    /**
     * The current color value represented by the gradient.
     * Setting this updates the gradient tint and pointer position.
     */
    public var colorValue(default, set):Color = Color.WHITE;
    function set_colorValue(colorValue:Color):Color {
        if (this.colorValue == colorValue) return colorValue;
        this.colorValue = colorValue;
        updateTintColor();
        updatePointerFromColor();
        return colorValue;
    }

    /**
     * Internal flag indicating if the spectrum is being moved.
     * Used to coordinate animations with ColorPickerView.
     */
    @:allow(elements.ColorPickerView)
    var movingSpectrum:Bool = false;

    var blackGradient:Mesh;

    var tintGradient:Mesh;

    var colorPointer:Border;

    var targetPointerColor:Color = Color.NONE;

    var pointerColorTween:Tween = null;

    var movingPointer:Bool = false;

    var savedPointerX:Float = 0;

    var savedPointerY:Float = 0;

    var filter:Filter;

    /**
     * The current hue value (0-360 degrees) used to tint the gradient.
     */
    public var hue(default, null):Float = 0;

    /**
     * Creates a new HSB gradient view.
     * 
     * Initializes:
     * - Two gradient meshes (tint and black overlay)
     * - Interactive color pointer
     * - Nearest neighbor filtering for crisp rendering
     * - Pointer event handlers
     */
    public function new() {

        super();

        filter = new Filter();
        filter.textureFilter = NEAREST;
        add(filter);

        transparent = true;

        tintGradient = new Mesh();
        tintGradient.colorMapping = VERTICES;
        tintGradient.depth = 1;
        filter.content.add(tintGradient);

        blackGradient = new Mesh();
        blackGradient.colorMapping = VERTICES;
        blackGradient.depth = 2;
        filter.content.add(blackGradient);

        colorPointer = new Border();
        colorPointer.anchor(0.5, 0.5);
        colorPointer.size(10, 10);
        colorPointer.depth = 3;
        colorPointer.borderPosition = INSIDE;
        colorPointer.borderSize = 1;
        colorPointer.roundTranslation = 1;
        filter.content.add(colorPointer);

        blackGradient.vertices = [
            0, 0,
            1, 0,
            1, 1,
            0, 1
        ];

        blackGradient.indices = [
            0, 1, 2,
            0, 2, 3
        ];

        blackGradient.colors[0] = new AlphaColor(Color.WHITE, 0);
        blackGradient.colors[1] = new AlphaColor(Color.WHITE, 0);
        blackGradient.colors[2] = new AlphaColor(Color.BLACK);
        blackGradient.colors[3] = new AlphaColor(Color.BLACK);

        tintGradient.vertices = blackGradient.vertices;
        tintGradient.indices = blackGradient.indices;

        tintGradient.colors[0] = new AlphaColor(Color.WHITE);

        var tintColor = Color.fromHSL(colorValue.hue, 1, 0.5);
        tintGradient.colors[1] = new AlphaColor(tintColor);
        tintGradient.colors[2] = new AlphaColor(tintColor);

        tintGradient.colors[3] = new AlphaColor(Color.WHITE);

        updatePointerFromColor();

        filter.content.onPointerDown(this, handlePointerDown);
        filter.content.onPointerUp(this, handlePointerUp);

    }

    /**
     * Updates the gradient tint based on the current or provided hue.
     * The tint color is applied to the right side of the gradient.
     * 
     * @param hue Optional new hue value (0-360). If not provided, uses current hue.
     */
    public function updateTintColor(?hue:Float) {

        if (hue != null) {
            this.hue = hue;
        }

        var tintColor = Color.fromHSL(this.hue, 1, 0.5);
        tintGradient.colors[1] = new AlphaColor(tintColor);
        tintGradient.colors[2] = new AlphaColor(tintColor);

    }

    /**
     * Saves the current pointer position for later restoration.
     * Used when temporarily moving the pointer during spectrum changes.
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
     * Calculates the brightness value (0-1) from the pointer's Y position.
     * Brightness is inverted (top = 100%, bottom = 0%).
     * 
     * @return The brightness value clamped between 0 and 1
     */
    public function getBrightnessFromPointer():Float {

        var brightness = 1 - (colorPointer.y / height);
        if (brightness < 0)
            brightness = 0;
        if (brightness > 1)
            brightness = 1;

        return brightness;

    }

    /**
     * Calculates the saturation value (0-1) from the pointer's X position.
     * Saturation increases from left (0%) to right (100%).
     * 
     * @return The saturation value clamped between 0 and 1
     */
    public function getSaturationFromPointer():Float {

        var saturation = colorPointer.x / width;
        if (saturation < 0)
            saturation = 0;
        if (saturation > 1)
            saturation = 1;

        return saturation;

    }

    /**
     * Updates the pointer position and color based on the current color value.
     * Also handles smooth color transitions when the pointer moves between
     * light and dark areas of the gradient.
     */
    function updatePointerFromColor() {

        var brightness = colorValue.brightness;
        var saturation = colorValue.saturation;

        colorPointer.pos(
            width * saturation,
            height * (1.0 - brightness)
        );

        var newPointerColor = Color.WHITE;
        colorValue.getHSLuv(_tuple);
        if (_tuple[2] > 0.5) {
            newPointerColor = Color.BLACK;
        }

        if (movingPointer || movingSpectrum) {
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

        blackGradient.scale(width, height);
        tintGradient.scale(width, height);

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

    /**
     * Updates the color based on touch/pointer position.
     * Calculates saturation and brightness from the pointer coordinates
     * and emits an update event.
     * 
     * @param info Touch information containing pointer coordinates
     */
    function updateColorFromTouchInfo(info:TouchInfo) {

        screenToVisual(info.x, info.y, _point);

        var brightness = 1 - (_point.y / height);
        if (brightness < 0)
            brightness = 0;
        if (brightness > 1)
            brightness = 1;

        var saturation = _point.x / width;
        if (saturation < 0)
            saturation = 0;
        if (saturation > 1)
            saturation = 1;

        this.colorValue = Color.fromHSB(
            hue, saturation, brightness
        );

        updatePointerFromColor();

        emitUpdateColorFromPointer();

        colorPointer.pos(
            Math.max(0, Math.min(width, _point.x)),
            Math.max(0, Math.min(height, _point.y))
        );

    }

}
