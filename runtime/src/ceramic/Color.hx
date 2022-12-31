package ceramic;

using StringTools;

// Substantial portion taken from: https://github.com/HaxeFlixel/flixel/blob/a59545015a65a42b8f24b08262ac80de020deb37/flixel/util/FlxColor.hx

/**
 * Class representing a color, based on Int. Provides a variety of methods for creating and converting colors.
 *
 * Colors can be written as Ints. This means you can pass a hex value such as
 * 0x123456 to a function expecting a Color, and it will automatically become a Color "object".
 * Similarly, Colors may be treated as Ints.
 *
 * Note that when using properties of a Color other than RGB, the values are ultimately stored as
 * RGB values, so repeatedly manipulating HSB/HSL/CMYK values may result in a gradual loss of precision.
 *
 * @author Joe Williamson (JoeCreates)
 * @author Edited by Jeremy Faivre for Ceramic engine (jeremyfa)
 */
abstract Color(Int) from Int from UInt to Int to UInt
{
    public static inline var NONE:Color =        -1;

    public static inline var WHITE:Color =       0xFFFFFF;
    public static inline var GRAY:Color =        0x808080;
    public static inline var BLACK:Color =       0x000000;

    public static inline var GREEN:Color =       0x008000;
    public static inline var LIME:Color =        0x00FF00;
    public static inline var YELLOW:Color =      0xFFFF00;
    public static inline var ORANGE:Color =      0xFFA500;
    public static inline var RED:Color =         0xFF0000;
    public static inline var PURPLE:Color =      0x800080;
    public static inline var BLUE:Color =        0x0000FF;
    public static inline var BROWN:Color =       0x8B4513;
    public static inline var PINK:Color =        0xFFC0CB;
    public static inline var MAGENTA:Color =     0xFF00FF;
    public static inline var CYAN:Color =        0x00FFFF;

    public static inline var CORNFLOWERBLUE:Color =  0x6495ED;
    public static inline var MEDIUMVIOLETRED:Color = 0xC71585;
    public static inline var DEEPPINK:Color =        0xFF1493;
    public static inline var PALEVIOLETRED:Color =   0xDB7093;
    public static inline var HOTPINK:Color =         0xFF69B4;
    public static inline var LIGHTPINK:Color =       0xFFB6C1;
    public static inline var DARKRED:Color =         0x8B0000;
    public static inline var FIREBRICK:Color =       0xB22222;
    public static inline var CRIMSON:Color =         0xDC143C;
    public static inline var INDIANRED:Color =       0xCD5C5C;
    public static inline var LIGHTCORAL:Color =      0xF08080;
    public static inline var SALMON:Color =          0xFA8072;
    public static inline var DARKSALMON:Color =      0xE9967A;
    public static inline var LIGHTSALMON:Color =     0xFFA07A;
    public static inline var ORANGERED:Color =       0xFF4500;
    public static inline var TOMATO:Color =          0xFF6347;
    public static inline var DARKORANGE:Color =      0xFF8C00;
    public static inline var CORAL:Color =           0xFF7F50;
    public static inline var DARKKHAKI:Color =       0xBDB76B;
    public static inline var GOLD:Color =            0xFFD700;
    public static inline var KHAKI:Color =           0xF0E68C;
    public static inline var PEACHPUFF:Color =       0xFFDAB9;
    public static inline var PALEGOLDENROD:Color =   0xEEE8AA;
    public static inline var MOCCASIN:Color =        0xFFE4B5;
    public static inline var PAPAYAWHIP:Color =      0xFFEFD5;
    public static inline var LEMONCHIFFON:Color =    0xFFFACD;
    public static inline var LIGHTYELLOW:Color =     0xFFFFE0;
    public static inline var SIENNA:Color =          0xA0522D;
    public static inline var CHOCOLATE:Color =       0xD2691E;
    public static inline var PERU:Color =            0xCD853F;
    public static inline var TAN:Color =             0xD2B48C;
    public static inline var DARKOLIVEGREEN:Color =  0x556B2F;
    public static inline var OLIVE:Color =           0x808000;
    public static inline var TEAL:Color =            0x008080;
    public static inline var TURQUOISE:Color =       0x40E0D0;
    public static inline var NAVY:Color =            0x000080;
    public static inline var INDIGO:Color =          0x4B0082;
    public static inline var ORCHID:Color =          0xDA70D6;
    public static inline var LAVENDER:Color =        0xE6E6FA;
    public static inline var AZURE:Color =           0xF0FFFF;
    public static inline var IVORY:Color =           0xFFFFF0;
    public static inline var DIMGREY:Color =         0x696969;
    public static inline var SLATEGREY:Color =       0x708090;
    public static inline var SNOW:Color =            0xFFFAFA;

    public static var colorLookup(default, null):Map<String, Int> = [
        "NONE" =>       -1,

        "WHITE" =>      0xFFFFFF,
        "GRAY" =>       0x808080,
        "BLACK" =>      0x000000,

        "GREEN" =>      0x008000,
        "LIME" =>       0x00FF00,
        "YELLOW" =>     0xFFFF00,
        "ORANGE" =>     0xFFA500,
        "RED" =>        0xFF0000,
        "PURPLE" =>     0x800080,
        "BLUE" =>       0x0000FF,
        "BROWN" =>      0x8B4513,
        "PINK" =>       0xFFC0CB,
        "MAGENTA" =>    0xFF00FF,
        "CYAN" =>       0x00FFFF,

        "CORNFLOWERBLUE" => 0x6495ED,
        "MEDIUMVIOLETRED" =>0xC71585,
        "DEEPPINK" =>       0xFF1493,
        "PALEVIOLETRED" =>  0xDB7093,
        "HOTPINK" =>        0xFF69B4,
        "LIGHTPINK" =>      0xFFB6C1,
        "DARKRED" =>        0x8B0000,
        "FIREBRICK" =>      0xB22222,
        "CRIMSON" =>        0xDC143C,
        "INDIANRED" =>      0xCD5C5C,
        "LIGHTCORAL" =>     0xF08080,
        "SALMON" =>         0xFA8072,
        "DARKSALMON" =>     0xE9967A,
        "LIGHTSALMON" =>    0xFFA07A,
        "ORANGERED" =>      0xFF4500,
        "TOMATO" =>         0xFF6347,
        "DARKORANGE" =>     0xFF8C00,
        "CORAL" =>          0xFF7F50,
        "DARKKHAKI" =>      0xBDB76B,
        "GOLD" =>           0xFFD700,
        "KHAKI" =>          0xF0E68C,
        "PEACHPUFF" =>      0xFFDAB9,
        "PALEGOLDENROD" =>  0xEEE8AA,
        "MOCCASIN" =>       0xFFE4B5,
        "PAPAYAWHIP" =>     0xFFEFD5,
        "LEMONCHIFFON" =>   0xFFFACD,
        "LIGHTYELLOW" =>    0xFFFFE0,
        "SIENNA" =>         0xA0522D,
        "CHOCOLATE" =>      0xD2691E,
        "PERU" =>           0xCD853F,
        "TAN" =>            0xD2B48C,
        "DARKOLIVEGREEN" => 0x556B2F,
        "OLIVE" =>          0x808000,
        "TEAL" =>           0x008080,
        "TURQUOISE" =>      0x40E0D0,
        "NAVY" =>           0x000080,
        "INDIGO" =>         0x4B0082,
        "ORCHID" =>         0xDA70D6,
        "LAVENDER" =>       0xE6E6FA,
        "AZURE" =>          0xF0FFFF,
        "IVORY" =>          0xFFFFF0,
        "DIMGREY" =>        0x696969,
        "SLATEGREY" =>      0x708090,
        "SNOW" =>           0xFFFAFA
    ];

    /**
     * Red color component as `Int` between `0` and `255`
     */
    public var red(get, set):Int;
    /**
     * Green color component as `Int` between `0` and `255`
     */
    public var green(get, set):Int;
    /**
     * Blue color component as `Int` between `0` and `255`
     */
    public var blue(get, set):Int;

    /**
     * Red color component as `Float` between `0.0` and `1.0`
     */
    public var redFloat(get, set):Float;
    /**
     * Green color component as `Float` between `0.0` and `1.0`
     */
    public var greenFloat(get, set):Float;
    /**
     * Blue color component as `Float` between `0.0` and `1.0`
     */
    public var blueFloat(get, set):Float;

    public var cyan(get, set):Float;
    public var magenta(get, set):Float;
    public var yellow(get, set):Float;
    public var black(get, set):Float;

    /**
     * The hue of the color in degrees (from 0 to 359)
     */
    public var hue(get, set):Float;
    /**
     * The saturation of the color (from 0 to 1)
     */
    public var saturation(get, set):Float;
    /**
     * The brightness (aka value) of the color (from 0 to 1)
     */
    public var brightness(get, set):Float;
    /**
     * The lightness of the color (from 0 to 1)
     */
    public var lightness(get, set):Float;

    /**
     * Get the color as AlphaColor
     */
    @:to public inline function toAlphaColor():AlphaColor {
        return new AlphaColor(this);
    }

    /**
     * Generate a random color (away from white or black)
     * @return The color as a Color
     */
    public static inline function random(minSatutation:Float = 0.5, minBrightness:Float = 0.5):Color
    {
        var hue = Math.random() * 360; // 0 to 360
        var saturation = Math.random() * (1.0 - minSatutation) + minSatutation; // default 0.5 to 1.0, away from white
        var brightness = Math.random() * (1.0 - minBrightness) + minBrightness; // default 0.5 to 1.0, away from black
        return Color.fromHSB(hue, saturation, brightness);
    }

    /**
     * Create a color from the least significant three bytes of an Int
     *
     * @param    value And Int with bytes in the format 0xRRGGBB
     * @return    The color as a Color
     */
    public static inline function fromInt(value:Int):Color
    {
        return new Color(value);
    }

    /**
     * Generate a color from integer RGB values (0 to 255)
     *
     * @param red    The red value of the color from 0 to 255
     * @param green    The green value of the color from 0 to 255
     * @param blue    The green value of the color from 0 to 255
     * @return The color as a Color
     */
    public static inline function fromRGB(red:Int, green:Int, blue:Int):Color
    {
        var color = new Color();
        return color.setRGB(red, green, blue);
    }

    /**
     * Generate a color from float RGB values (0 to 1)
     *
     * @param red    The red value of the color from 0 to 1
     * @param green    The green value of the color from 0 to 1
     * @param blue    The green value of the color from 0 to 1
     * @return The color as a Color
     */
    public static inline function fromRGBFloat(red:Float, green:Float, blue:Float):Color
    {
        var color = new Color();
        return color.setRGBFloat(red, green, blue);
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
    public static inline function fromCMYK(cyan:Float, magenta:Float, yellow:Float, black:Float):Color
    {
        var color = new Color();
        return color.setCMYK(cyan, magenta, yellow, black);
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
        var color = new Color();
        return color.setHSB(hue, saturation, brightness);
    }

    /**
     * Generate a color from HSL components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    The color as a Color
     */
    public static inline function fromHSL(hue:Float, saturation:Float, lightness:Float):Color
    {
        var color = new Color();
        return color.setHSL(hue, saturation, lightness);
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
        var result:Null<Color> = null;
        str = StringTools.trim(str);

        if (str.startsWith('0x'))
        {
            result = new Color(Std.parseInt(str.substring(0, 8)));
        }
        else if (str.startsWith('#'))
        {
            if (str.length >= 9) {
                var hexColor:String = "0x" + str.substring(1, 9);
                var alphaColor:AlphaColor = Std.parseInt(hexColor);
                result = alphaColor.rgb;
            }
            else {
                var hexColor:String = "0x" + str.substring(1, 7);
                result = new Color(Std.parseInt(hexColor));
            }
        }
        else
        {
            str = str.toUpperCase();
            for (key in colorLookup.keys())
            {
                if (key == str)
                {
                    result = new Color(colorLookup.get(key));
                    break;
                }
            }
        }

        return result;
    }

    /**
     * Get HSB color wheel values in an array which will be 360 elements in size
     *
     * @return    HSB color wheel as Array of Colors
     */
    public static function getHSBColorWheel():Array<Color>
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
    public static inline function interpolate(color1:Color, color2:Color, factor:Float = 0.5):Color
    {
        var r:Int = Std.int((color2.red - color1.red) * factor + color1.red);
        var g:Int = Std.int((color2.green - color1.green) * factor + color1.green);
        var b:Int = Std.int((color2.blue - color1.blue) * factor + color1.blue);

        return fromRGB(r, g, b);
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
        var output = new Array<Color>();

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
     * Multiply the RGB channels of two Colors
     */
    @:op(A * B)
    public static inline function multiply(lhs:Color, rhs:Color):Color
    {
        return Color.fromRGBFloat(lhs.redFloat * rhs.redFloat, lhs.greenFloat * rhs.greenFloat, lhs.blueFloat * rhs.blueFloat);
    }

    /**
     * Add the RGB channels of two Colors
     */
    @:op(A + B)
    public static inline function add(lhs:Color, rhs:Color):Color
    {
        return Color.fromRGB(lhs.red + rhs.red, lhs.green + rhs.green, lhs.blue + rhs.blue);
    }

    /**
     * Subtract the RGB channels of one Color from another
     */
    @:op(A - B)
    public static inline function subtract(lhs:Color, rhs:Color):Color
    {
        return Color.fromRGB(lhs.red - rhs.red, lhs.green - rhs.green, lhs.blue - rhs.blue);
    }

    /**
     * Return a String representation of the color in the format
     *
     * @param prefix Whether to include "0x" prefix at start of string
     * @return    A string of length 8 in the format 0xRRGGBB
     */
    public inline function toHexString(prefix:Bool = true):String
    {
        return (prefix ? "0x" : "") +
            StringTools.hex(red, 2) + StringTools.hex(green, 2) + StringTools.hex(blue, 2);
    }

    /**
     * Return a String representation of the color in the format #RRGGBB
     *
     * @return    A string of length 7 in the format #RRGGBB
     */
    public inline function toWebString():String
    {
        return "#" + toHexString(false);
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
        // RGB format
        result += "red: " + red + " green: " + green + " blue: " + blue + "\n";
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
    public function getDarkened(factor:Float = 0.2):Color
    {
        factor = bound(factor, 0, 1);
        var output:Color = this;
        output.lightness = output.lightness * (1 - factor);
        return output;
    }

    /**
     * Get a lightened version of this color
     *
     * @param    factor value from 0 to 1 of how much to progress toward white.
     * @return     A lightened version of this color
     */
    public inline function getLightened(factor:Float = 0.2):Color
    {
        factor = bound(factor, 0, 1);
        var output:Color = this;
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
        var output:Color = Color.WHITE - this;
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
    public inline function setRGB(red:Int, green:Int, blue:Int):Color
    {
        set_red(red);
        set_green(green);
        set_blue(blue);
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
    public inline function setRGBFloat(red:Float, green:Float, blue:Float):Color
    {
        redFloat = red;
        greenFloat = green;
        blueFloat = blue;
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
    public inline function setCMYK(cyan:Float, magenta:Float, yellow:Float, black:Float):Color
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
    public inline function setHSB(hue:Float, saturation:Float, brightness:Float):Color
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
    public inline function setHSL(hue:Float, saturation:Float, lightness:Float):Color
    {
        var chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
        var match = lightness - chroma / 2;
        return setHSChromaMatch(hue, saturation, chroma, match);
    }

    /**
     * Private utility function to perform common operations between setHSB and setHSL
     */
    private inline function setHSChromaMatch(hue:Float, saturation:Float, chroma:Float, match:Float):Color
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

    public function new(value:Int = 0)
    {
        this = value;
    }

    private inline function get_red():Int
    {
        return (this >> 16) & 0xff;
    }

    private inline function get_green():Int
    {
        return (this >> 8) & 0xff;
    }

    private inline function get_blue():Int
    {
        return this & 0xff;
    }

    private inline function get_redFloat():Float
    {
        return red / 255;
    }

    private inline function get_greenFloat():Float
    {
        return green / 255;
    }

    private inline function get_blueFloat():Float
    {
        return blue / 255;
    }

    private inline function set_red(value:Int):Int
    {
        this &= 0x00ffff;
        this |= boundChannel(value) << 16;
        return value;
    }

    private inline function set_green(value:Int):Int
    {
        this &= 0xff00ff;
        this |= boundChannel(value) << 8;
        return value;
    }

    private inline function set_blue(value:Int):Int
    {
        this &= 0xffff00;
        this |= boundChannel(value);
        return value;
    }

    private inline function set_redFloat(value:Float):Float
    {
        red = Math.round(value * 255);
        return value;
    }

    private inline function set_greenFloat(value:Float):Float
    {
        green = Math.round(value * 255);
        return value;
    }

    private inline function set_blueFloat(value:Float):Float
    {
        blue = Math.round(value * 255);
        return value;
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

    inline public function toString() {

        return this == Color.NONE ? 'NONE' : toHexString();

    }

#if hsluv

/// HSLuv helpers

    static var _hsluvTuple:Array<Float> = [0, 0, 0];

    static var _hsluvResult:Array<Float> = [0, 0, 0];

    /**
     * Generate a color from HSLuv components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    The color as a Color
     */
    public static inline function fromHSLuv(hue:Float, saturation:Float, lightness:Float):Color
    {
        var color = new Color();
        return color.setHSLuv(hue, saturation, lightness);
    }

    /**
     * Set HSLuv components.
     *
     * @param    hue            A number between 0 and 360, indicating position on a color strip or wheel.
     * @param    saturation    A number between 0 and 1, indicating how colorful or gray the color should be.  0 is gray, 1 is vibrant.
     * @param    lightness    A number between 0 and 1, indicating the lightness of the color
     * @return    This color
     */
    public inline function setHSLuv(hue:Float, saturation:Float, lightness:Float):Color
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
     *
     * @param result A pre-allocated array to store the result into.
     * @return    The HSLuv components as a float array
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
