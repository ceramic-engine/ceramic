package ceramic;

using StringTools;

/**
 * Color with alpha channel stored as a 32-bit integer.
 * 
 * AlphaColor represents a color with transparency in ARGB format (0xAARRGGBB).
 * It extends the functionality of Color by adding an alpha channel for opacity.
 * 
 * Key features:
 * - Full RGBA color support with alpha transparency
 * - Compatible with Color class (can convert to/from)
 * - Same color manipulation features as Color
 * - Predefined constants for common colors with full opacity
 * - String parsing and formatting
 * - HSB/HSL/CMYK color space conversions
 * 
 * The alpha channel controls transparency:
 * - 0x00 (0) = Fully transparent
 * - 0xFF (255) = Fully opaque
 * - Values in between create partial transparency
 * 
 * @example
 * ```haxe
 * // Create colors with alpha
 * var semiRed = AlphaColor.fromRGBA(255, 0, 0, 128); // 50% transparent red
 * var transparent = AlphaColor.TRANSPARENT;
 * var opaque = AlphaColor.WHITE;
 * 
 * // Convert between Color and AlphaColor
 * var color = Color.BLUE;
 * var alphaColor = color.toAlphaColor(); // Full opacity
 * var backToColor:Color = alphaColor; // Auto-conversion
 * 
 * // Manipulate alpha
 * var faded = alphaColor;
 * faded.alpha = 128; // 50% opacity
 * faded.alphaFloat = 0.25; // 25% opacity
 * 
 * // Parse from string
 * var parsed = AlphaColor.fromString("#80FF0000"); // Semi-transparent red
 * ```
 * 
 * @see Color
 */
#if (cpp && windows)
@:headerCode('
// Needed otherwise windows build fails :(
// But why?
#undef TRANSPARENT
')
#end
abstract AlphaColor(Int) from Int from UInt to Int to UInt {

    /**
     * Special value representing no color.
     * Same as Color.NONE but as AlphaColor type.
     */
    public static inline var NONE:AlphaColor =        -1;

    /**
     * Fully transparent (invisible) color.
     * Alpha = 0, RGB values don't matter visually.
     */
    public static inline var TRANSPARENT:AlphaColor = 0x00000000;

    /** Pure white color with full opacity (0xFFFFFFFF) */
    public static inline var WHITE:AlphaColor =       0xFFFFFFFF;
    /** Medium gray color with full opacity (0xFF808080) */
    public static inline var GRAY:AlphaColor =        0xFF808080;
    /** Pure black color with full opacity (0xFF000000) */
    public static inline var BLACK:AlphaColor =       0xFF000000;

    /** Dark green color with full opacity (0xFF008000) */
    public static inline var GREEN:AlphaColor =       0xFF008000;
    /** Bright lime green color with full opacity (0xFF00FF00) */
    public static inline var LIME:AlphaColor =        0xFF00FF00;
    /** Bright yellow color with full opacity (0xFFFFFF00) */
    public static inline var YELLOW:AlphaColor =      0xFFFFFF00;
    /** Orange color with full opacity (0xFFFFA500) */
    public static inline var ORANGE:AlphaColor =      0xFFFFA500;
    /** Pure red color with full opacity (0xFFFF0000) */
    public static inline var RED:AlphaColor =         0xFFFF0000;
    /** Purple color with full opacity (0xFF800080) */
    public static inline var PURPLE:AlphaColor =      0xFF800080;
    /** Pure blue color with full opacity (0xFF0000FF) */
    public static inline var BLUE:AlphaColor =        0xFF0000FF;
    /** Brown color with full opacity (0xFF8B4513) */
    public static inline var BROWN:AlphaColor =       0xFF8B4513;
    /** Pink color with full opacity (0xFFFFC0CB) */
    public static inline var PINK:AlphaColor =        0xFFFFC0CB;
    /** Magenta color with full opacity (0xFFFF00FF) */
    public static inline var MAGENTA:AlphaColor =     0xFFFF00FF;
    /** Cyan color with full opacity (0xFF00FFFF) */
    public static inline var CYAN:AlphaColor =        0xFF00FFFF;

    /** Cornflower blue color with full opacity (0xFF6495ED) */
    public static inline var CORNFLOWERBLUE:AlphaColor =  0xFF6495ED;
    /** Medium violet red color with full opacity (0xFFC71585) */
    public static inline var MEDIUMVIOLETRED:AlphaColor = 0xFFC71585;
    /** Deep pink color with full opacity (0xFFFF1493) */
    public static inline var DEEPPINK:AlphaColor =        0xFFFF1493;
    /** Pale violet red color with full opacity (0xFFDB7093) */
    public static inline var PALEVIOLETRED:AlphaColor =   0xFFDB7093;
    /** Hot pink color with full opacity (0xFFFF69B4) */
    public static inline var HOTPINK:AlphaColor =         0xFFFF69B4;
    /** Light pink color with full opacity (0xFFFFB6C1) */
    public static inline var LIGHTPINK:AlphaColor =       0xFFFFB6C1;
    /** Dark red color with full opacity (0xFF8B0000) */
    public static inline var DARKRED:AlphaColor =         0xFF8B0000;
    /** Firebrick red color with full opacity (0xFFB22222) */
    public static inline var FIREBRICK:AlphaColor =       0xFFB22222;
    /** Crimson color with full opacity (0xFFDC143C) */
    public static inline var CRIMSON:AlphaColor =         0xFFDC143C;
    /** Indian red color with full opacity (0xFFCD5C5C) */
    public static inline var INDIANRED:AlphaColor =       0xFFCD5C5C;
    /** Light coral color with full opacity (0xFFF08080) */
    public static inline var LIGHTCORAL:AlphaColor =      0xFFF08080;
    /** Salmon color with full opacity (0xFFFA8072) */
    public static inline var SALMON:AlphaColor =          0xFFFA8072;
    /** Dark salmon color with full opacity (0xFFE9967A) */
    public static inline var DARKSALMON:AlphaColor =      0xFFE9967A;
    /** Light salmon color with full opacity (0xFFFFA07A) */
    public static inline var LIGHTSALMON:AlphaColor =     0xFFFFA07A;
    /** Orange red color with full opacity (0xFFFF4500) */
    public static inline var ORANGERED:AlphaColor =       0xFFFF4500;
    /** Tomato color with full opacity (0xFFFF6347) */
    public static inline var TOMATO:AlphaColor =          0xFFFF6347;
    /** Dark orange color with full opacity (0xFFFF8C00) */
    public static inline var DARKORANGE:AlphaColor =      0xFFFF8C00;
    /** Coral color with full opacity (0xFFFF7F50) */
    public static inline var CORAL:AlphaColor =           0xFFFF7F50;
    /** Dark khaki color with full opacity (0xFFBDB76B) */
    public static inline var DARKKHAKI:AlphaColor =       0xFFBDB76B;
    /** Gold color with full opacity (0xFFFFD700) */
    public static inline var GOLD:AlphaColor =            0xFFFFD700;
    /** Khaki color with full opacity (0xFFF0E68C) */
    public static inline var KHAKI:AlphaColor =           0xFFF0E68C;
    /** Peach puff color with full opacity (0xFFFFDAB9) */
    public static inline var PEACHPUFF:AlphaColor =       0xFFFFDAB9;
    /** Pale goldenrod color with full opacity (0xFFEEE8AA) */
    public static inline var PALEGOLDENROD:AlphaColor =   0xFFEEE8AA;
    /** Moccasin color with full opacity (0xFFFFE4B5) */
    public static inline var MOCCASIN:AlphaColor =        0xFFFFE4B5;
    /** Papaya whip color with full opacity (0xFFFFEFD5) */
    public static inline var PAPAYAWHIP:AlphaColor =      0xFFFFEFD5;
    /** Lemon chiffon color with full opacity (0xFFFFFACD) */
    public static inline var LEMONCHIFFON:AlphaColor =    0xFFFFFACD;
    /** Light yellow color with full opacity (0xFFFFFFE0) */
    public static inline var LIGHTYELLOW:AlphaColor =     0xFFFFFFE0;
    /** Sienna color with full opacity (0xFFA0522D) */
    public static inline var SIENNA:AlphaColor =          0xFFA0522D;
    /** Chocolate color with full opacity (0xFFD2691E) */
    public static inline var CHOCOLATE:AlphaColor =       0xFFD2691E;
    /** Peru color with full opacity (0xFFCD853F) */
    public static inline var PERU:AlphaColor =            0xFFCD853F;
    /** Tan color with full opacity (0xFFD2B48C) */
    public static inline var TAN:AlphaColor =             0xFFD2B48C;
    /** Dark olive green color with full opacity (0xFF556B2F) */
    public static inline var DARKOLIVEGREEN:AlphaColor =  0xFF556B2F;
    /** Olive color with full opacity (0xFF808000) */
    public static inline var OLIVE:AlphaColor =           0xFF808000;
    /** Teal color with full opacity (0xFF008080) */
    public static inline var TEAL:AlphaColor =            0xFF008080;
    /** Turquoise color with full opacity (0xFF40E0D0) */
    public static inline var TURQUOISE:AlphaColor =       0xFF40E0D0;
    /** Navy blue color with full opacity (0xFF000080) */
    public static inline var NAVY:AlphaColor =            0xFF000080;
    /** Indigo color with full opacity (0xFF4B0082) */
    public static inline var INDIGO:AlphaColor =          0xFF4B0082;
    /** Orchid color with full opacity (0xFFDA70D6) */
    public static inline var ORCHID:AlphaColor =          0xFFDA70D6;
    /** Lavender color with full opacity (0xFFE6E6FA) */
    public static inline var LAVENDER:AlphaColor =        0xFFE6E6FA;
    /** Azure color with full opacity (0xFFF0FFFF) */
    public static inline var AZURE:AlphaColor =           0xFFF0FFFF;
    /** Ivory color with full opacity (0xFFFFFFF0) */
    public static inline var IVORY:AlphaColor =           0xFFFFFFF0;
    /** Dim grey color with full opacity (0xFF696969) */
    public static inline var DIMGREY:AlphaColor =         0xFF696969;
    /** Slate grey color with full opacity (0xFF708090) */
    public static inline var SLATEGREY:AlphaColor =       0xFF708090;
    /** Snow color with full opacity (0xFFFFFAFA) */
    public static inline var SNOW:AlphaColor =            0xFFFFFAFA;

    /**
     * Red color component as `Int` between `0` and `255`.
     * Modifying this value updates the color immediately.
     */
    public var red(get, set):Int;
    /**
     * Green color component as `Int` between `0` and `255`.
     * Modifying this value updates the color immediately.
     */
    public var green(get, set):Int;
    /**
     * Blue color component as `Int` between `0` and `255`.
     * Modifying this value updates the color immediately.
     */
    public var blue(get, set):Int;
    /**
     * Alpha component as `Int` between `0` and `255`.
     * Controls transparency: 0 = fully transparent, 255 = fully opaque.
     * Modifying this value updates the color immediately.
     */
    public var alpha(get, set):Int;

    /**
     * Red color component as `Float` between `0.0` and `1.0`.
     * Modifying this value updates the color immediately.
     * Useful for smooth gradients and precise color calculations.
     */
    public var redFloat(get, set):Float;
    /**
     * Green color component as `Float` between `0.0` and `1.0`.
     * Modifying this value updates the color immediately.
     * Useful for smooth gradients and precise color calculations.
     */
    public var greenFloat(get, set):Float;
    /**
     * Blue color component as `Float` between `0.0` and `1.0`.
     * Modifying this value updates the color immediately.
     * Useful for smooth gradients and precise color calculations.
     */
    public var blueFloat(get, set):Float;
    /**
     * Alpha component as `Float` between `0.0` and `1.0`.
     * Controls transparency: 0.0 = fully transparent, 1.0 = fully opaque.
     * Modifying this value updates the color immediately.
     */
    public var alphaFloat(get, set):Float;

    /**
     * Cyan component in CMYK color space (0.0 to 1.0).
     * CMYK is commonly used for print design.
     * Setting this value recalculates RGB components automatically.
     */
    public var cyan(get, set):Float;
    /**
     * Magenta component in CMYK color space (0.0 to 1.0).
     * CMYK is commonly used for print design.
     * Setting this value recalculates RGB components automatically.
     */
    public var magenta(get, set):Float;
    /**
     * Yellow component in CMYK color space (0.0 to 1.0).
     * CMYK is commonly used for print design.
     * Setting this value recalculates RGB components automatically.
     */
    public var yellow(get, set):Float;
    /**
     * Black/Key component in CMYK color space (0.0 to 1.0).
     * CMYK is commonly used for print design.
     * Setting this value recalculates RGB components automatically.
     */
    public var black(get, set):Float;

    /**
     * The hue of the color in degrees (from 0 to 359).
     * Represents position on the color wheel: 0/360 = red, 120 = green, 240 = blue.
     * Setting this value preserves saturation and brightness.
     */
    public var hue(get, set):Float;
    /**
     * The saturation of the color (from 0 to 1).
     * Controls color intensity: 0 = grayscale, 1 = fully saturated.
     * Part of the HSB/HSV color model.
     */
    public var saturation(get, set):Float;
    /**
     * The brightness (aka value) of the color (from 0 to 1).
     * Controls how light or dark the color is: 0 = black, 1 = full brightness.
     * Part of the HSB/HSV color model.
     */
    public var brightness(get, set):Float;
    /**
     * The lightness of the color (from 0 to 1).
     * Controls the lightness: 0 = black, 0.5 = pure color, 1 = white.
     * Part of the HSL color model (different from brightness).
     */
    public var lightness(get, set):Float;

    /**
     * RGB color component typed as `ceramic.Color`.
     * Gets or sets the RGB values without affecting the alpha channel.
     * Useful for applying a Color to an AlphaColor while preserving transparency.
     */
    public var color(get, set):Color;

    /**
     * RGB color component typed as `ceramic.Color` (alias of `color`).
     * Gets or sets the RGB values without affecting the alpha channel.
     * Useful for applying a Color to an AlphaColor while preserving transparency.
     */
    public var rgb(get, set):Color;

    /**
     * Implicit conversion to Color (strips alpha channel).
     * @return RGB color without alpha
     */
    @:to public inline function toColor():Color {
        return rgb;
    }

    /**
     * Generate a random color with full opacity (away from white or black).
     * 
     * Creates vibrant colors by ensuring minimum saturation and brightness.
     * The resulting color will have full opacity (alpha = 255).
     * 
     * @param minSatutation Minimum saturation (0-1), default 0.5
     * @param minBrightness Minimum brightness (0-1), default 0.5
     * @return A randomly generated opaque color
     */
    public static inline function random(minSatutation:Float = 0.5, minBrightness:Float = 0.5):AlphaColor
    {
        return Color.random(minSatutation, minBrightness).toAlphaColor();
    }

    /**
     * Create a color from the least significant four bytes of an Int
     *
     * @param    value And Int with bytes in the format 0xAARRGGBB
     * @return    The color as an AlphaColor
     */
    public static inline function fromInt(value:Int):AlphaColor
    {
        return value;
    }

    /**
     * Generate a color from integer RGB values (0 to 255)
     *
     * @param red    The red value of the color from 0 to 255
     * @param green    The green value of the color from 0 to 255
     * @param blue    The green value of the color from 0 to 255
     * @return The color as a AlphaColor
     */
    public static inline function fromRGB(red:Int, green:Int, blue:Int):AlphaColor
    {
        return Color.fromRGB(red, green, blue).toAlphaColor();
    }

    /**
     * Generate a color from float RGB values (0 to 1)
     *
     * @param red    The red value of the color from 0 to 1
     * @param green    The green value of the color from 0 to 1
     * @param blue    The green value of the color from 0 to 1
     * @return The color as a AlphaColor
     */
    public static inline function fromRGBFloat(red:Float, green:Float, blue:Float):AlphaColor
    {
        var color = new Color();
        return color.setRGBFloat(red, green, blue).toAlphaColor();
    }

    /**
     * Generate a color from integer RGBA values (0 to 255)
     *
     * @param red    The red value of the color from 0 to 255
     * @param green    The green value of the color from 0 to 255
     * @param blue    The green value of the color from 0 to 255
     * @param alpha    The alpha value of the color from 0 to 255
     * @return The color as a AlphaColor
     */
    public static inline function fromRGBA(red:Int, green:Int, blue:Int, alpha:Int):AlphaColor
    {
        return new AlphaColor(Color.fromRGB(red, green, blue), alpha);
    }

    /**
     * Generate a color from float RGBA values (0 to 1)
     *
     * @param red    The red value of the color from 0 to 1
     * @param green    The green value of the color from 0 to 1
     * @param blue    The green value of the color from 0 to 1
     * @param alpha    The green value of the color from 0 to 1
     * @return The color as a AlphaColor
     */
    public static inline function fromRGBAFloat(red:Float, green:Float, blue:Float, alpha:Float):AlphaColor
    {
        var color:AlphaColor = 0xFF000000;
        return color.setRGBAFloat(red, green, blue, alpha);
    }

    /**
     * Generate a color from CMYK values (0 to 1)
     *
     * @param cyan        The cyan value of the color from 0 to 1
     * @param magenta    The magenta value of the color from 0 to 1
     * @param yellow    The yellow value of the color from 0 to 1
     * @param black        The black value of the color from 0 to 1
     * @return The color as a AlphaColor
     */
    public static inline function fromCMYK(cyan:Float, magenta:Float, yellow:Float, black:Float):AlphaColor
    {
        var color:AlphaColor = 0xFF000000;
        return color.setCMYK(cyan, magenta, yellow, black);
    }

    /**
     * Generate a color from HSB (aka HSV) components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    brightness    (aka value) A number between 0 and 1, indicating how bright the color should be.  0 is black, 1 is full bright.
     * @return    The color as a AlphaColor
     */
    public static function fromHSB(hue:Float, saturation:Float, brightness:Float):AlphaColor
    {
        var color:AlphaColor = 0xFF000000;
        return color.setHSB(hue, saturation, brightness);
    }

    /**
     * Generate a color from HSL components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    The color as a AlphaColor
     */
    public static inline function fromHSL(hue:Float, saturation:Float, lightness:Float):AlphaColor
    {
        var color:AlphaColor = 0xFF000000;
        return color.setHSL(hue, saturation, lightness);
    }

    /**
     * Parses a `String` and returns a `Color` or `null` if the `String` couldn't be parsed.
     *
     * Examples (input -> output in hex):
     *
     * - `0xFF00FF00`    -> `0xFF00FF00`
     * - `#FF0000FF`     -> `0xFF0000FF`
     * - `GRAY`        -> `0xFF808080`
     * - `blue`        -> `0xFF0000FF`
     *
     * @param    str     The string to be parsed
     * @return    A `Color` or `null` if the `String` couldn't be parsed
     */
    public static function fromString(str:String):Null<AlphaColor>
    {
        var result:Null<AlphaColor> = null;
        str = StringTools.trim(str);

        if (str.startsWith('0x'))
        {
            result = new Color(Std.parseInt(str.substring(0, 8)));
        }
        else if (str.startsWith('#'))
        {
            if (str.length >= 9) {
                var hexColor:String = "0x" + str.substring(1, 9);
                result = Std.parseInt(hexColor);
            }
            else {
                var hexColor:String = "0x" + str.substring(1, 7);
                result = new Color(Std.parseInt(hexColor)).toAlphaColor();
            }
        }
        else
        {
            str = str.toUpperCase();
            var colorLookup = Color.colorLookup;
            for (key in colorLookup.keys())
            {
                if (key == str)
                {
                    result = new Color(colorLookup.get(key)).toAlphaColor();
                    break;
                }
            }
        }

        return result;
    }

    /**
     * Get HSB color wheel values in an array which will be 360 elements in size
     *
     * @return    HSB color wheel as Array of AlphaColors
     */
    public static function getHSBColorWheel():Array<AlphaColor>
    {
        return [for (c in 0...360) fromHSB(c, 1.0, 1.0)];
    }

    /**
     * Get an interpolated color based on two different colors.
     *
     * @param     color1 The first color
     * @param     color2 The second color
     * @param     factor value from 0 to 1 representing how much to shift color1 toward color2
     * @return    The interpolated color
     */
    public static inline function interpolate(color1:AlphaColor, color2:AlphaColor, factor:Float = 0.5):AlphaColor
    {
        var r:Int = Std.int((color2.red - color1.red) * factor + color1.red);
        var g:Int = Std.int((color2.green - color1.green) * factor + color1.green);
        var b:Int = Std.int((color2.blue - color1.blue) * factor + color1.blue);
        var a:Int = Std.int((color2.alpha - color1.alpha) * factor + color1.alpha);

        return fromRGBA(r, g, b, a);
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
    public static function gradient(color1:AlphaColor, color2:AlphaColor, steps:Int, ?ease:Float->Float):Array<AlphaColor>
    {
        var output = new Array<AlphaColor>();

        if (ease == null)
        {
            ease = function(t:Float):Float
            {
                return t;
            }
        }

        for (step in 0...steps)
        {
            output[step] = interpolate(color1, color2, ease(step / (steps - 1)));
        }

        return output;
    }

    /**
     * Multiply the RGB channels of two AlphaColors.
     * The result uses full opacity (alpha = 255).
     * Useful for color blending and filter effects.
     * 
     * @param lhs Left-hand side color
     * @param rhs Right-hand side color
     * @return The multiplied color with full opacity
     */
    @:op(A * B)
    public static inline function multiply(lhs:AlphaColor, rhs:AlphaColor):AlphaColor
    {
        return AlphaColor.fromRGBFloat(lhs.redFloat * rhs.redFloat, lhs.greenFloat * rhs.greenFloat, lhs.blueFloat * rhs.blueFloat);
    }

    /**
     * Add the RGB channels of two AlphaColors.
     * The result uses full opacity (alpha = 255).
     * Values are clamped to the 0-255 range.
     * 
     * @param lhs Left-hand side color
     * @param rhs Right-hand side color
     * @return The added color with full opacity
     */
    @:op(A + B)
    public static inline function add(lhs:AlphaColor, rhs:AlphaColor):AlphaColor
    {
        return AlphaColor.fromRGB(lhs.red + rhs.red, lhs.green + rhs.green, lhs.blue + rhs.blue);
    }

    /**
     * Subtract the RGB channels of one AlphaColor from another.
     * The result uses full opacity (alpha = 255).
     * Values are clamped to the 0-255 range.
     * 
     * @param lhs Left-hand side color (minuend)
     * @param rhs Right-hand side color (subtrahend)
     * @return The subtracted color with full opacity
     */
    @:op(A - B)
    public static inline function subtract(lhs:AlphaColor, rhs:AlphaColor):AlphaColor
    {
        return AlphaColor.fromRGB(lhs.red - rhs.red, lhs.green - rhs.green, lhs.blue - rhs.blue);
    }

    /**
     * Return a String representation of the color in the format
     *
     * @param prefix Whether to include "0x" prefix at start of string
     * @return    A string of length 10 in the format 0xAARRGGBB
     */
    public inline function toHexString(prefix:Bool = true):String
    {
        return (prefix ? "0x" : "") +
            StringTools.hex(alpha, 2) + StringTools.hex(red, 2) + StringTools.hex(green, 2) + StringTools.hex(blue, 2);
    }

    /**
     * Return a String representation of the color in the format #RRGGBB
     *
     * @return    A string of length 7 in the format #RRGGBB
     */
    public inline function toWebString():String
    {
        return "#" + rgb.toHexString(false);
    }

    /**
     * Get a string of color information about this color
     *
     * @return A string containing information about this color
     */
    public function getColorInfo():String
    {
        // Hex format
        var result:String = toHexString() + "\n";
        // ARGB format
        result += "alpha: " + alpha + "red: " + red + " green: " + green + " blue: " + blue + "\n";
        // HSB/HSL info
        result += "hue: " + roundDecimal(hue, 2) + " saturation: " + roundDecimal(saturation, 2) +
            " brightness: " + roundDecimal(brightness, 2) + " lightness: " + roundDecimal(lightness, 2);

        return result;
    }

    /**
     * Get a darkened version of this color
     *
     * @param    factor value from 0 to 1 of how much to progress toward black.
     * @return     A darkened version of this color
     */
    public function getDarkened(factor:Float = 0.2):AlphaColor
    {
        factor = bound(factor, 0, 1);
        var output:AlphaColor = this;
        output.lightness = output.lightness * (1 - factor);
        return output;
    }

    /**
     * Get a lightened version of this color
     *
     * @param    factor value from 0 to 1 of how much to progress toward white.
     * @return     A lightened version of this color
     */
    public inline function getLightened(factor:Float = 0.2):AlphaColor
    {
        factor = bound(factor, 0, 1);
        var output:AlphaColor = this;
        output.lightness = output.lightness + (1 - lightness) * factor;
        return output;
    }

    /**
     * Get the inversion of this color
     *
     * @return The inversion of this color
     */
    public inline function getInverted():Color
    {
		var oldAlpha = alpha;
		var output:AlphaColor = AlphaColor.WHITE - this;
		output.alpha = oldAlpha;
		return output;
    }

    /**
     * Set RGB values as integers (0 to 255)
     *
     * @param red    The red value of the color from 0 to 255
     * @param green    The green value of the color from 0 to 255
     * @param blue    The green value of the color from 0 to 255
     * @return This color
     */
    public inline function setRGB(red:Int, green:Int, blue:Int):AlphaColor
    {
        set_red(red);
        set_green(green);
        set_blue(blue);
        return this;
    }

    /**
     * Set RGB values as integers (0 to 255)
     *
     * @param red    The red value of the color from 0 to 255
     * @param green    The green value of the color from 0 to 255
     * @param blue    The green value of the color from 0 to 255
     * @param alpha    The alpha value of the color from 0 to 255
     * @return This color
     */
    public inline function setRGBA(red:Int, green:Int, blue:Int, alpha:Int):AlphaColor
    {
        set_red(red);
        set_green(green);
        set_blue(blue);
        set_alpha(alpha);
        return this;
    }

    /**
     * Set RGB values as floats (0 to 1)
     *
     * @param red    The red value of the color from 0 to 1
     * @param green    The green value of the color from 0 to 1
     * @param blue    The green value of the color from 0 to 1
     * @return This color
     */
    public inline function setRGBFloat(red:Float, green:Float, blue:Float):AlphaColor
    {
        redFloat = red;
        greenFloat = green;
        blueFloat = blue;
        return this;
    }

    /**
     * Set RGB values as floats (0 to 1)
     *
     * @param red    The red value of the color from 0 to 1
     * @param green    The green value of the color from 0 to 1
     * @param blue    The green value of the color from 0 to 1
     * @param alpha    The alpha value of the color from 0 to 1
     * @return This color
     */
    public inline function setRGBAFloat(red:Float, green:Float, blue:Float, alpha:Float):AlphaColor
    {
        redFloat = red;
        greenFloat = green;
        blueFloat = blue;
        alphaFloat = alpha;
        return this;
    }

    /**
     * Set CMYK values as floats (0 to 1)
     *
     * @param cyan        The cyan value of the color from 0 to 1
     * @param magenta    The magenta value of the color from 0 to 1
     * @param yellow    The yellow value of the color from 0 to 1
     * @param black        The black value of the color from 0 to 1
     * @return This color
     */
    public inline function setCMYK(cyan:Float, magenta:Float, yellow:Float, black:Float):AlphaColor
    {
        redFloat = (1 - cyan) * (1 - black);
        greenFloat = (1 - magenta) * (1 - black);
        blueFloat = (1 - yellow) * (1 - black);
        return this;
    }

    /**
     * Set HSB (aka HSV) components
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    brightness    (aka value) A number between 0 and 1, indicating how bright the color should be.  0 is black, 1 is full bright.
     * @return    This color
     */
    public inline function setHSB(hue:Float, saturation:Float, brightness:Float):AlphaColor
    {
        var chroma = brightness * saturation;
        var match = brightness - chroma;
        return setHSChromaMatch(hue, saturation, chroma, match);
    }

    /**
     * Set HSL components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    This color
     */
    public inline function setHSL(hue:Float, saturation:Float, lightness:Float):AlphaColor
    {
        var chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
        var match = lightness - chroma / 2;
        return setHSChromaMatch(hue, saturation, chroma, match);
    }

    /**
     * Private utility function to perform common operations between setHSB and setHSL.
     * Converts HSB/HSL values to RGB using the chroma and match values.
     * 
     * @param hue The hue angle in degrees
     * @param saturation The saturation value (not used directly in calculation)
     * @param chroma The chroma value (color intensity)
     * @param match The match value (baseline lightness)
     * @return This color after modification
     */
    private inline function setHSChromaMatch(hue:Float, saturation:Float, chroma:Float, match:Float):AlphaColor
    {
        hue %= 360;
        var hueD = hue / 60;
        var mid = chroma * (1 - Math.abs(hueD % 2 - 1)) + match;
        chroma += match;

        switch (Std.int(hueD))
        {
            case 0: setRGBFloat(chroma, mid, match);
            case 1: setRGBFloat(mid, chroma, match);
            case 2: setRGBFloat(match, chroma, mid);
            case 3: setRGBFloat(match, mid, chroma);
            case 4: setRGBFloat(mid, match, chroma);
            case 5: setRGBFloat(chroma, match, mid);
        }

        return this;
    }

    /**
     * Create a new `AlphaColor` (ARGB) object from a `ceramic.Color` object and the given `alpha`
     * @param color RGB color object (`ceramic.Color`)
     * @param alpha alpha component between `0` and `255`
     */
    public inline function new(color:Color, alpha:Int = 255) {
        var value:AlphaColor = Std.int(color) + 0xFF000000;
        value.alpha = alpha;
        this = value;
    }

    inline function get_color():Color {
        return Color.fromRGB(red, green, blue);
    }
    inline function set_color(color:Color):Color {
        red = color.red;
        green = color.green;
        blue = color.blue;
        return color;
    }

    inline function get_rgb():Color {
        return Color.fromRGB(red, green, blue);
    }
    inline function set_rgb(color:Color):Color {
        red = color.red;
        green = color.green;
        blue = color.blue;
        return color;
    }

    private inline function get_red():Int {
        return (this >> 16) & 0xff;
    }

    private inline function get_green():Int {
        return (this >> 8) & 0xff;
    }

    private inline function get_blue():Int {
        return this & 0xff;
    }

    private inline function get_alpha():Int {
        return (this >> 24) & 0xff;
    }

    private inline function get_redFloat():Float {
        return red / 255;
    }

    private inline function get_greenFloat():Float {
        return green / 255;
    }

    private inline function get_blueFloat():Float {
        return blue / 255;
    }

    private inline function get_alphaFloat():Float {
        return alpha / 255;
    }

    private inline function set_red(Value:Int):Int {
        this &= 0xff00ffff;
        this |= boundChannel(Value) << 16;
        return Value;
    }

    private inline function set_green(Value:Int):Int {
        this &= 0xffff00ff;
        this |= boundChannel(Value) << 8;
        return Value;
    }

    private inline function set_blue(Value:Int):Int {
        this &= 0xffffff00;
        this |= boundChannel(Value);
        return Value;
    }

    private inline function set_alpha(Value:Int):Int {
        this &= 0x00ffffff;
        this |= boundChannel(Value) << 24;
        return Value;
    }

    private inline function set_redFloat(Value:Float):Float {
        red = Math.round(Value * 255);
        return Value;
    }

    private inline function set_greenFloat(Value:Float):Float {
        green = Math.round(Value * 255);
        return Value;
    }

    private inline function set_blueFloat(Value:Float):Float {
        blue = Math.round(Value * 255);
        return Value;
    }

    private inline function set_alphaFloat(Value:Float):Float {
        alpha = Math.round(Value * 255);
        return Value;
    }

    private inline function get_cyan():Float
    {
        return (1 - redFloat - black) / brightness;
    }

    private inline function get_magenta():Float
    {
        return (1 - greenFloat - black) / brightness;
    }

    private inline function get_yellow():Float
    {
        return (1 - blueFloat - black) / brightness;
    }

    private inline function get_black():Float
    {
        return 1 - brightness;
    }

    private inline function set_cyan(value:Float):Float
    {
        setCMYK(value, magenta, yellow, black);
        return value;
    }

    private inline function set_magenta(value:Float):Float
    {
        setCMYK(cyan, value, yellow, black);
        return value;
    }

    private inline function set_yellow(value:Float):Float
    {
        setCMYK(cyan, magenta, value, black);
        return value;
    }

    private inline function set_black(value:Float):Float
    {
        setCMYK(cyan, magenta, yellow, value);
        return value;
    }

    private function get_hue():Float
    {
        var hueRad = Math.atan2(Math.sqrt(3) * (greenFloat - blueFloat), 2 * redFloat - greenFloat - blueFloat);
        var hue:Float = 0;
        if (hueRad != 0)
        {
            hue = 180 / Math.PI * Math.atan2(Math.sqrt(3) * (greenFloat - blueFloat), 2 * redFloat - greenFloat - blueFloat);
        }

        return hue < 0 ? hue + 360 : hue;
    }

    private inline function get_brightness():Float
    {
        return maxColor();
    }

    private inline function get_saturation():Float
    {
        return (maxColor() - minColor()) / brightness;
    }

    private inline function get_lightness():Float
    {
        return (maxColor() + minColor()) / 2;
    }

    private inline function set_hue(value:Float):Float
    {
        setHSB(value, saturation, brightness);
        return value;
    }

    private inline function set_saturation(value:Float):Float
    {
        setHSB(hue, value, brightness);
        return value;
    }

    private inline function set_brightness(value:Float):Float
    {
        setHSB(hue, saturation, value);
        return value;
    }

    private inline function set_lightness(value:Float):Float
    {
        setHSL(hue, saturation, value);
        return value;
    }

    private inline function maxColor():Float
    {
        return Math.max(redFloat, Math.max(greenFloat, blueFloat));
    }

    private inline function minColor():Float
    {
        return Math.min(redFloat, Math.min(greenFloat, blueFloat));
    }

    private inline function boundChannel(value:Int):Int
    {
        return value > 0xff ? 0xff : value < 0 ? 0 : value;
    }

/// Math

    private static function roundDecimal(value:Float, precision:Int):Float
    {
        var mult:Float = 1;
        for (i in 0...precision)
        {
            mult *= 10;
        }
        return Math.round(value * mult) / mult;
    }

    private static inline function bound(value:Float, ?min:Float, ?max:Float):Float
    {
        var lowerBound:Float = (min != null && value < min) ? min : value;
        return (max != null && lowerBound > max) ? max : lowerBound;
    }

/// To string

    /**
     * Get this RGBA color as `String`.
     * Format: `0xAARRGGBB`
     */
    inline public function toString() {

        return this == AlphaColor.NONE ? 'NONE' : toHexString();

    }

#if hsluv

/// HSLuv helpers

    static var _hsluvTuple:Array<Float> = [0, 0, 0];

    static var _hsluvResult:Array<Float> = [0, 0, 0];

    /**
     * The HSLuv hue of the color in degrees (from 0 to 359).
     * HSLuv is a perceptually uniform color space that provides more consistent lightness.
     * Setting this value preserves HSLuv saturation and lightness.
     * Only available when the `hsluv` library is included.
     */
    public var hueHSLuv(get, set):Float;
    /**
     * The HSLuv saturation of the color (from 0 to 1).
     * In HSLuv, saturation is perceptually uniform across different hues.
     * Setting this value preserves HSLuv hue and lightness.
     * Only available when the `hsluv` library is included.
     */
    public var saturationHSLuv(get, set):Float;
    /**
     * The HSLuv lightness of the color (from 0 to 1).
     * In HSLuv, lightness is perceptually uniform - 50% lightness appears equally bright across all hues.
     * Setting this value preserves HSLuv hue and saturation.
     * Only available when the `hsluv` library is included.
     */
    public var lightnessHSLuv(get, set):Float;

    private function get_hueHSLuv():Float
    {
        return _getOrCreateCachedHSLuvComponent(0);
    }

    inline private function set_hueHSLuv(hueHSLuv:Float):Float
    {
        setHSLuv(hueHSLuv, get_saturationHSLuv(), get_lightnessHSLuv());
        return hueHSLuv;
    }

    private function get_saturationHSLuv():Float
    {
        return _getOrCreateCachedHSLuvComponent(1);
    }

    inline private function set_saturationHSLuv(saturationHSLuv:Float):Float
    {
        setHSLuv(get_hueHSLuv(), saturationHSLuv, get_lightnessHSLuv());
        return saturationHSLuv;
    }

    private function get_lightnessHSLuv():Float
    {
        return _getOrCreateCachedHSLuvComponent(2);
    }

    inline private function set_lightnessHSLuv(lightnessHSLuv:Float):Float
    {
        setHSLuv(get_hueHSLuv(), get_saturationHSLuv(), lightnessHSLuv);
        return lightnessHSLuv;
    }

    private inline function _getOrCreateCachedHSLuvComponent(index:Int):Float
    {
        var key:Int = rgb;
        var entry:Int = @:privateAccess Color._hsluvCacheMap.get(key);
        if (entry == 0) {
            entry = Std.int(@:privateAccess Color._hsluvCacheValues.length / 3) + 1;
            @:privateAccess Color._hsluvCacheMap.set(key, entry);
            getHSLuv(_hsluvResult);
            @:privateAccess Color._hsluvCacheValues.push(_hsluvResult[0]);
            @:privateAccess Color._hsluvCacheValues.push(_hsluvResult[1]);
            @:privateAccess Color._hsluvCacheValues.push(_hsluvResult[2]);
        }
        return @:privateAccess Color._hsluvCacheValues[(entry-1)*3+index];
    }

    /**
     * Generate a color from HSLuv components.
     * HSLuv is a perceptually uniform color space that provides more consistent results than HSL.
     * Colors with the same lightness value appear equally bright regardless of hue.
     * Only available when the `hsluv` library is included.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    The color as a AlphaColor with full opacity
     */
    public static inline function fromHSLuv(hue:Float, saturation:Float, lightness:Float):AlphaColor
    {
        var color:AlphaColor = 0xFFFFFFFF;
        return color.setHSLuv(hue, saturation, lightness);
    }

    /**
     * Set HSLuv components.
     * Converts HSLuv values to RGB while maintaining the alpha channel.
     * For very low lightness values, falls back to regular HSL conversion.
     * Only available when the `hsluv` library is included.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    This color after modification
     */
    public inline function setHSLuv(hue:Float, saturation:Float, lightness:Float):AlphaColor
    {
        _hsluvTuple[0] = hue;
        _hsluvTuple[1] = saturation * 100;
        _hsluvTuple[2] = lightness * 100;
        if (lightness > 0.001) {
            hsluv.Hsluv.hsluvToRgb(_hsluvTuple, _hsluvResult);
            var v = _hsluvResult[0];
            if (v < 0)
                v = 0;
            set_redFloat(v);
            v = _hsluvResult[1];
            if (v < 0)
                v = 0;
            set_greenFloat(v);
            v = _hsluvResult[2];
            if (v < 0)
                v = 0;
            set_blueFloat(v);
        }
        else {
            setHSL(hue, saturation, lightness);
        }
        return this;
    }

    /**
     * Get HSLuv components from the color instance.
     * Extracts the hue, saturation and lightness values in HSLuv color space.
     * Only available when the `hsluv` library is included.
     *
     * @param result A pre-allocated array to store the result into. If null, a new array is created.
     * @return    The HSLuv components as a float array [hue (0-360), saturation (0-1), lightness (0-1)]
     */
    public inline function getHSLuv(?result:Array<Float>):Array<Float>
    {
        if (result == null) {
            result = [0, 0, 0];
        }
        _hsluvTuple[0] = redFloat;
        _hsluvTuple[1] = greenFloat;
        _hsluvTuple[2] = blueFloat;
        hsluv.Hsluv.rgbToHsluv(_hsluvTuple, result);
        result[1] *= 0.01;
        result[2] *= 0.01;
        return result;
    }

#end

}
