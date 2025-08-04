package ceramic.scriptable;

/**
 * Scriptable wrapper for Std to expose standard library functions to scripts.
 *
 * This class provides essential utility functions from Haxe's standard library
 * for type conversion, parsing, and random number generation. In scripts,
 * this type is exposed as `Std` (without the Scriptable prefix).
 *
 * ## Usage in Scripts
 *
 * ```haxe
 * // Convert float to integer (truncates decimal)
 * var score = Std.int(95.7);  // 95
 * var floor = Std.int(-2.9);  // -2
 *
 * // Convert any value to string
 * var text = Std.string(42);        // "42"
 * var bool = Std.string(true);      // "true"
 * var obj = Std.string({x: 10});    // "{x: 10}"
 *
 * // Parse strings to numbers
 * var num = Std.parseInt("123");    // 123
 * var bad = Std.parseInt("abc");    // null
 * var hex = Std.parseInt("0xFF");   // 255
 *
 * var pi = Std.parseFloat("3.14");  // 3.14
 * var exp = Std.parseFloat("1e3");  // 1000
 * var nan = Std.parseFloat("xyz");  // NaN
 *
 * // Generate random integers
 * var dice = Std.random(6) + 1;     // 1-6
 * var coin = Std.random(2);         // 0 or 1
 * var pct = Std.random(100);        // 0-99
 * ```
 *
 * ## Function Reference
 *
 * - **int()**: Truncates float to integer (towards zero)
 * - **string()**: Converts any value to its string representation
 * - **parseInt()**: Parses integer from string, returns null on failure
 * - **parseFloat()**: Parses float from string, returns NaN on failure
 * - **random()**: Returns random integer from 0 to x-1
 *
 * @see Std The actual Haxe standard library
 */
class ScriptableStd {

    /**
     * Converts a Float to an Int by truncating the decimal part.
     *
     * @param x The float value to convert
     * @return The integer part of x
     */
    public static function int(x:Float):Int {
        return Std.int(x);
    }

    /**
     * Converts any value to a String representation.
     *
     * @param s The value to convert
     * @return String representation of the value
     */
    public static function string(s:Dynamic):String {
        return Std.string(s);
    }

    /**
     * Parses an integer from a string.
     *
     * Supports decimal and hexadecimal (0x prefix) formats.
     * Stops parsing at the first non-numeric character.
     *
     * @param s The string to parse
     * @return The parsed integer, or null if parsing fails
     */
    public static function parseInt(s:String):Null<Int> {
        return Std.parseInt(s);
    }

    /**
     * Parses a floating-point number from a string.
     *
     * Supports decimal notation and scientific notation (e.g., "1.23e4").
     *
     * @param s The string to parse
     * @return The parsed float, or NaN if parsing fails
     */
    public static function parseFloat(s:String):Float {
        return Std.parseFloat(s);
    }

    /**
     * Generates a random integer between 0 (inclusive) and x (exclusive).
     *
     * @param x The upper bound (exclusive)
     * @return Random integer in range [0, x)
     */
    public static function random(x:Int):Int {
        return Std.random(x);
    }

}