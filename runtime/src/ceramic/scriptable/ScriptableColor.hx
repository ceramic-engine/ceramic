package ceramic.scriptable;

/**
 * Class representing a color, based on Int. Provides a variety of methods for creating and converting colors.
 *
 * Colors can be written as Ints. This means you can pass a hex value such as
 * 0x123456 to a function expecting a Color, and it will automatically become a Color "object".
 * Similarly, Colors may be treated as Ints.
 *
 * Note that when using properties of a Color other than RGB, the values are ultimately stored as
 * RGB values, so repeatedly manipulating HSB/HSL/CMYK values may result in a gradual loss of precision.
 */
class ScriptableColor {
    
    public static final NONE:Color =        -1;

    public static final WHITE:Color =       0xFFFFFF;
    public static final GRAY:Color =        0x808080;
    public static final BLACK:Color =       0x000000;

    public static final GREEN:Color =       0x008000;
    public static final LIME:Color =        0x00FF00;
    public static final YELLOW:Color =      0xFFFF00;
    public static final ORANGE:Color =      0xFFA500;
    public static final RED:Color =         0xFF0000;
    public static final PURPLE:Color =      0x800080;
    public static final BLUE:Color =        0x0000FF;
    public static final BROWN:Color =       0x8B4513;
    public static final PINK:Color =        0xFFC0CB;
    public static final MAGENTA:Color =     0xFF00FF;
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

    public static function red(color:Color):Int
    {
        return color.red;
    }

    public static function green(color:Color):Int
    {
        return color.green;
    }

    public static function blue(color:Color):Int
    {
        return color.blue;
    }

    public static function redFloat(color:Color):Float
    {
        return color.redFloat;
    }

    public static function greenFloat(color:Color):Float
    {
        return color.greenFloat;
    }

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