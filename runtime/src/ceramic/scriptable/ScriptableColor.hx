package ceramic.scriptable;

/**
 * Same feature-set as `ceramic.Color`, but used through static methods
 * in environments when abstract is not usable (hscript)
 */
class ScriptableColor {

    public static function random(minSatutation:Float = 0.5, minBrightness:Float = 0.5):Color
    {
        return Color.random(minSatutation, minBrightness);
    }

    public static function fromInt(value:Int):Color
    {
        return Color.fromInt(value);
    }

    public static function fromRGB(red:Int, green:Int, blue:Int):Color
    {
        return Color.fromRGB(red, green, blue);
    }

    public static function fromRGBFloat(red:Float, green:Float, blue:Float):Color
    {
        return Color.fromRGBFloat(red, green, blue);
    }

    public static function fromCMYK(cyan:Float, magenta:Float, yellow:Float, black:Float):Color
    {
        return Color.fromCMYK(cyan, magenta, yellow, black);
    }

    public static function fromHSL(hue:Float, saturation:Float, lightness:Float):Color
    {
        return Color.fromHSL(hue, saturation, lightness);
    }

    public static function fromString(str:String):Null<Color>
    {
        return Color.fromString(str);
    }

    public static function getHSBColorWheel():Array<Color>
    {
        return Color.getHSBColorWheel();
    }

    public static inline function interpolate(color1:Color, color2:Color, factor:Float = 0.5):Color
    {
        return Color.interpolate(color1, color2, factor);
    }

    public static function gradient(color1:Color, color2:Color, steps:Int, ?ease:Float->Float):Array<Color>
    {
        return Color.gradient(color1, color2, steps, ease);
    }

    public static function multiply(lhs:Color, rhs:Color):Color
    {
        return Color.multiply(lhs, rhs);
    }

    public static function add(lhs:Color, rhs:Color):Color
    {
        return Color.add(lhs, rhs);
    }

    public static function subtract(lhs:Color, rhs:Color):Color
    {
        return Color.subtract(lhs, rhs);
    }

    public static function toHexString(color:Color, prefix:Bool = true):String
    {
        return color.toHexString(prefix);
    }

    public static function toWebString(color:Color):String
    {
        return color.toWebString();
    }

    public static function getColorInfo(color:Color):String
    {
        return color.getColorInfo();
    }

    public static function getDarkened(color:Color, factor:Float = 0.2):Color
    {
        return color.getDarkened(factor);
    }

    public static function getLightened(color:Color, factor:Float = 0.2):Color
    {
        return color.getLightened(factor);
    }

    public static function getInverted(color:Color):Color
    {
        return color.getInverted();
    }

    public static function getRed(color:Color):Int
    {
        return color.red;
    }

    private static function getGreen(color:Color):Int
    {
        return color.green;
    }

    private static function getBlue(color:Color):Int
    {
        return color.blue;
    }

    private static function getRedFloat(color:Color):Float
    {
        return color.redFloat;
    }

    private inline function getGreenFloat(color:Color):Float
    {
        return color.greenFloat;
    }

    private inline function getBlueFloat(color:Color):Float
    {
        return color.blueFloat;
    }
}