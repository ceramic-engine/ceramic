package ceramic.scriptable;

/**
 * Scriptable wrapper for Color to expose RGB color functionality to scripts.
 *
 * This class provides comprehensive color manipulation features for scripts.
 * In scripts, this type is exposed as `Color` (without the Scriptable prefix)
 * and provides the same functionality as ceramic.Color.
 *
 * Colors are represented as integers in RGB format (0xRRGGBB). You can use
 * hex values directly or create colors using various color space methods.
 *
 * ## Usage in Scripts
 *
 * ```haxe
 * // Use predefined colors
 * var red = Color.RED;
 * var blue = Color.BLUE;
 *
 * // Create from hex value
 * var purple = 0x9400D3;
 *
 * // Create from RGB values
 * var orange = Color.fromRGB(255, 165, 0);
 *
 * // Create from HSB (hue, saturation, brightness)
 * var cyan = Color.fromHSB(180, 1.0, 1.0);
 *
 * // Interpolate between colors
 * var blend = Color.interpolate(red, blue, 0.5);
 *
 * // Modify colors
 * var darkRed = Color.getDarkened(red, 0.3);
 * var lightBlue = Color.getLightened(blue, 0.3);
 * ```
 *
 * ## Color Spaces
 *
 * - **RGB**: Red, Green, Blue (0-255 per channel)
 * - **HSB/HSV**: Hue (0-360°), Saturation (0-1), Brightness/Value (0-1)
 * - **HSL**: Hue (0-360°), Saturation (0-1), Lightness (0-1)
 * - **CMYK**: Cyan, Magenta, Yellow, Key/Black (0-1 per channel)
 * - **HSLuv**: Perceptually uniform color space (if enabled)
 *
 * Note that colors are stored internally as RGB, so repeated conversions
 * between color spaces may result in precision loss.
 *
 * @see ceramic.Color The actual implementation
 * @see ceramic.scriptable.ScriptableAlphaColor For colors with alpha channel
 */
class ScriptableColor {

    /** Special value representing no color or transparent/invalid color */
    public static final NONE:Color =        -1;

    /** Pure white color (RGB: 255, 255, 255) */
    public static final WHITE:Color =       0xFFFFFF;
    /** Medium gray color (RGB: 128, 128, 128) */
    public static final GRAY:Color =        0x808080;
    /** Pure black color (RGB: 0, 0, 0) */
    public static final BLACK:Color =       0x000000;

    /** Standard green color (RGB: 0, 128, 0) */
    public static final GREEN:Color =       0x008000;
    /** Bright lime green color (RGB: 0, 255, 0) */
    public static final LIME:Color =        0x00FF00;
    /** Pure yellow color (RGB: 255, 255, 0) */
    public static final YELLOW:Color =      0xFFFF00;
    /** Orange color (RGB: 255, 165, 0) */
    public static final ORANGE:Color =      0xFFA500;
    /** Pure red color (RGB: 255, 0, 0) */
    public static final RED:Color =         0xFF0000;
    /** Standard purple color (RGB: 128, 0, 128) */
    public static final PURPLE:Color =      0x800080;
    /** Pure blue color (RGB: 0, 0, 255) */
    public static final BLUE:Color =        0x0000FF;
    /** Brown color (RGB: 139, 69, 19) */
    public static final BROWN:Color =       0x8B4513;
    /** Pink color (RGB: 255, 192, 203) */
    public static final PINK:Color =        0xFFC0CB;
    /** Magenta color (RGB: 255, 0, 255) */
    public static final MAGENTA:Color =     0xFF00FF;
    /** Cyan color (RGB: 0, 255, 255) */
    public static final CYAN:Color =        0x00FFFF;

    /**
     * Generate a random color (away from white or black)
     * @return The color as a Color
     */
    public static function random(minSatutation:Float = 0.5, minBrightness:Float = 0.5):Color
    {
        return Color.random(minSatutation, minBrightness);
    }

    /**
     * Create a color from the least significant four bytes of an Int
     *
     * @param    value And Int with bytes in the format 0xRRGGBB
     * @return    The color as a Color
     */
    public static function fromInt(value:Int):Color
    {
        return Color.fromInt(value);
    }

    /**
     * Generate a color from integer RGB values (0 to 255)
     *
     * @param red    The red value of the color from 0 to 255
     * @param green    The green value of the color from 0 to 255
     * @param blue    The green value of the color from 0 to 255
     * @return The color as a Color
     */
    public static function fromRGB(red:Int, green:Int, blue:Int):Color
    {
        return Color.fromRGB(red, green, blue);
    }

    /**
     * Generate a color from float RGB values (0 to 1)
     *
     * @param red    The red value of the color from 0 to 1
     * @param green    The green value of the color from 0 to 1
     * @param blue    The green value of the color from 0 to 1
     * @return The color as a Color
     */
    public static function fromRGBFloat(red:Float, green:Float, blue:Float):Color
    {
        return Color.fromRGBFloat(red, green, blue);
    }

    /**
     * Generate a color from CMYK values (0 to 1)
     *
     * @param cyan        The cyan value of the color from 0 to 1
     * @param magenta    The magenta value of the color from 0 to 1
     * @param yellow    The yellow value of the color from 0 to 1
     * @param black        The black value of the color from 0 to 1
     * @return The color as a Color
     */
    public static function fromCMYK(cyan:Float, magenta:Float, yellow:Float, black:Float):Color
    {
        return Color.fromCMYK(cyan, magenta, yellow, black);
    }

    /**
     * Generate a color from HSB (aka HSV) components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    brightness    (aka value) A number between 0 and 1, indicating how bright the color should be.  0 is black, 1 is full bright.
     * @return    The color as a Color
     */
    public static function fromHSB(hue:Float, saturation:Float, brightness:Float):Color
    {
        return Color.fromHSB(hue, saturation, brightness);
    }

    /**
     * Generate a color from HSL components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    The color as a Color
     */
    public static function fromHSL(hue:Float, saturation:Float, lightness:Float):Color
    {
        return Color.fromHSL(hue, saturation, lightness);
    }

    /**
     * Parses a `String` and returns a `Color` or `null` if the `String` couldn't be parsed.
     *
     * Examples (input -> output in hex):
     *
     * - `0x00FF00`    -> `0x00FF00`
     * - `#0000FF`     -> `0x0000FF`
     * - `GRAY`        -> `0x808080`
     * - `blue`        -> `0x0000FF`
     *
     * @param    str     The string to be parsed
     * @return    A `Color` or `null` if the `String` couldn't be parsed
     */
    public static function fromString(str:String):Null<Color>
    {
        return Color.fromString(str);
    }

    /**
     * Get HSB color wheel values in an array which will be 360 elements in size
     *
     * @return    HSB color wheel as Array of Colors
     */
    public static function getHSBColorWheel():Array<Color>
    {
        return Color.getHSBColorWheel();
    }

    /**
     * Get an interpolated color based on two different colors.
     *
     * @param     color1 The first color
     * @param     color2 The second color
     * @param     factor value from 0 to 1 representing how much to shift color1 toward color2
     * @return    The interpolated color
     */
    public static inline function interpolate(color1:Color, color2:Color, factor:Float = 0.5):Color
    {
        return Color.interpolate(color1, color2, factor);
    }

    /**
     * Create a gradient from one color to another
     *
     * @param color1 The color to shift from
     * @param color2 The color to shift to
     * @param steps How many colors the gradient should have
     * @param ease An optional easing function, such as those provided in FlxEase
     * @return An array of colors of length steps, shifting from color1 to color2
     */
    public static function gradient(color1:Color, color2:Color, steps:Int, ?ease:Float->Float):Array<Color>
    {
        return Color.gradient(color1, color2, steps, ease);
    }

    /**
     * Multiply the RGB channels of two Colors
     */
    public static function multiply(lhs:Color, rhs:Color):Color
    {
        return Color.multiply(lhs, rhs);
    }

    /**
     * Add the RGB channels of two Colors
     */
    public static function add(lhs:Color, rhs:Color):Color
    {
        return Color.add(lhs, rhs);
    }

    /**
     * Subtract the RGB channels of one Color from another
     */
    public static function subtract(lhs:Color, rhs:Color):Color
    {
        return Color.subtract(lhs, rhs);
    }

    /**
     * Return a String representation of the color in the format
     *
     * @param prefix Whether to include "0x" prefix at start of string
     * @return    A string of length 10 in the format 0xAARRGGBB
     */
    public static function toHexString(color:Color, prefix:Bool = true):String
    {
        return color.toHexString(prefix);
    }

    /**
     * Return a String representation of the color in the format #RRGGBB
     *
     * @return    A string of length 7 in the format #RRGGBB
     */
    public static function toWebString(color:Color):String
    {
        return color.toWebString();
    }

    /**
     * Get a string of color information about this color
     *
     * @return A string containing information about this color
     */
    public static function getColorInfo(color:Color):String
    {
        return color.getColorInfo();
    }

    /**
     * Get a darkened version of this color
     *
     * @param    factor value from 0 to 1 of how much to progress toward black.
     * @return     A darkened version of this color
     */
    public static function getDarkened(color:Color, factor:Float = 0.2):Color
    {
        return color.getDarkened(factor);
    }

    /**
     * Get a lightened version of this color
     *
     * @param    factor value from 0 to 1 of how much to progress toward white.
     * @return     A lightened version of this color
     */
    public static function getLightened(color:Color, factor:Float = 0.2):Color
    {
        return color.getLightened(factor);
    }

    /**
     * Get the inversion of this color
     *
     * @return The inversion of this color
     */
    public static function getInverted(color:Color):Color
    {
        return color.getInverted();
    }

    /**
     * Get the hue of the color in degrees (from 0 to 359)
     */
    public static function hue(color:Color):Float
    {
        return color.hue;
    }

    /**
     * Get the saturation of the color (from 0 to 1)
     */
    public static function saturation(color:Color):Float
    {
        return color.saturation;
    }

    /**
     * Get the brightness (aka value) of the color (from 0 to 1)
     */
    public static function brightness(color:Color):Float
    {
        return color.brightness;
    }

    /**
     * Get the lightness of the color (from 0 to 1)
     */
    public static function lightness(color:Color):Float
    {
        return color.lightness;
    }

    /**
     * Get the red channel value of the color as an integer (0-255)
     *
     * @param color The color to extract the red channel from
     * @return The red channel value as an integer from 0 to 255
     */
    public static function red(color:Color):Int
    {
        return color.red;
    }

    /**
     * Get the green channel value of the color as an integer (0-255)
     *
     * @param color The color to extract the green channel from
     * @return The green channel value as an integer from 0 to 255
     */
    public static function green(color:Color):Int
    {
        return color.green;
    }

    /**
     * Get the blue channel value of the color as an integer (0-255)
     *
     * @param color The color to extract the blue channel from
     * @return The blue channel value as an integer from 0 to 255
     */
    public static function blue(color:Color):Int
    {
        return color.blue;
    }

    /**
     * Get the red channel value of the color as a float (0.0-1.0)
     *
     * @param color The color to extract the red channel from
     * @return The red channel value as a float from 0.0 to 1.0
     */
    public static function redFloat(color:Color):Float
    {
        return color.redFloat;
    }

    /**
     * Get the green channel value of the color as a float (0.0-1.0)
     *
     * @param color The color to extract the green channel from
     * @return The green channel value as a float from 0.0 to 1.0
     */
    public static function greenFloat(color:Color):Float
    {
        return color.greenFloat;
    }

    /**
     * Get the blue channel value of the color as a float (0.0-1.0)
     *
     * @param color The color to extract the blue channel from
     * @return The blue channel value as a float from 0.0 to 1.0
     */
    public static function blueFloat(color:Color):Float
    {
        return color.blueFloat;
    }

#if hsluv
    /**
     * Generate a color from HSLuv components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    The color as a Color
     */
    public static function fromHSLuv(hue:Float, saturation:Float, lightness:Float):Color
    {
        return Color.fromHSLuv(hue, saturation, lightness);
    }

    /**
     * Get HSLuv components from the color instance.
     *
     * @param result A pre-allocated array to store the result into.
     * @return    The HSLuv components as a float array
     */
    public static function getHSLuv(color:Color, ?result:Array<Float>):Array<Float>
    {
        return color.getHSLuv(result);
    }
#end

}