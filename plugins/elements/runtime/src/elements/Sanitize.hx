package elements;

using StringTools;

/**
 * Utility class for sanitizing and converting text input to numeric values.
 * 
 * The Sanitize class provides safe conversion methods for transforming
 * user input strings into numeric types with proper validation and
 * error handling. It handles various input formats and edge cases
 * commonly encountered in user interfaces.
 * 
 * Features:
 * - Safe string to float conversion with validation
 * - Handles different decimal separators (comma and period)
 * - Graceful handling of invalid input
 * - Preservation of trailing decimal points during editing
 * - NaN and infinity checking for robust validation
 * 
 * Example usage:
 * ```haxe
 * var value = Sanitize.stringToFloat("123.45");   // Returns 123.45
 * var value = Sanitize.stringToFloat("123,45");   // Returns 123.45 (comma converted)
 * var value = Sanitize.stringToFloat("invalid");  // Returns 0.0
 * var value = Sanitize.stringToFloat("");         // Returns 0.0
 * ```
 * 
 * @see SanitizeTextField
 */
class Sanitize {

    /**
     * Converts a string to a Float value with safe validation.
     * 
     * This method performs several sanitization steps:
     * 1. Trims whitespace from the input
     * 2. Converts comma decimal separators to periods
     * 3. Handles trailing decimal points gracefully
     * 4. Validates the result for NaN and infinity
     * 5. Returns 0.0 for any invalid input
     * 
     * The method preserves trailing decimal points by temporarily removing
     * them before parsing, which is useful for interactive editing scenarios
     * where users are in the process of typing a decimal number.
     * 
     * @param textValue The string to convert to a float
     * @return A valid float value, or 0.0 if the input is invalid
     */
    public static function stringToFloat(textValue:String):Float {

        if (textValue.trim() != '') {
            textValue = textValue.replace(',', '.');
            var endsWithDot = false;
            if (textValue.endsWith('.')) {
                endsWithDot = true;
                textValue = textValue.substring(0, textValue.length - 1);
            }
            var floatValue:Null<Float> = Std.parseFloat(textValue);
            if (floatValue != null && !Math.isNaN(floatValue) && Math.isFinite(floatValue)) {
                return floatValue;
            }
        }

        return 0;

    }

}
