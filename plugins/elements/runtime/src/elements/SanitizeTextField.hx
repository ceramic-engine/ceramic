package elements;

import ceramic.Slug;

using StringTools;
using ceramic.Extensions;

/**
 * Advanced text field sanitization utility with mathematical operation support.
 * 
 * SanitizeTextField provides comprehensive text field value sanitization for
 * numeric inputs with support for mathematical operations, range constraints,
 * and intelligent formatting. It handles both integer and floating-point
 * values with configurable precision and validation.
 * 
 * Features:
 * - Integer and float value sanitization with min/max constraints
 * - Mathematical expression evaluation (+, -, *, /)
 * - Configurable rounding and precision control
 * - Real-time and completion-based formatting
 * - Automatic value clamping to specified ranges
 * - Empty value handling with default assignment
 * - Regex-based input cleaning and validation
 * 
 * Example usage:
 * ```haxe
 * // Sanitize integer input
 * SanitizeTextField.setTextValueToInt(field, "123", 0, 1000);
 * 
 * // Sanitize float with math operations
 * SanitizeTextField.setTextValueToFloat(field, "10+5", 0.0, 100.0, 10, true);
 * 
 * // Handle mathematical expressions
 * var hasOp = SanitizeTextField.applyFloatOrIntOperationsIfNeeded(
 *     field, "25*2", 0.0, 1000.0, false, 1
 * );
 * ```
 * 
 * @see BaseTextFieldView
 * @see Sanitize
 */
class SanitizeTextField {

    /** Size of the closure cache for performance optimization */
    public static var CLOSURE_CACHE_SIZE = 128;

    /** Regular expression for matching numeric prefixes */
    static final RE_NUMERIC_PREFIX = ~/^[0-9]+/;

    /** Regular expression for matching non-digit and non-dot characters */
    static final RE_NON_DIGIT_OR_DOT = ~/[^0-9\.]+/;

    /** Regular expression for matching spaces (from TextUtils) */
    static final RE_SPACES = TextUtils.RE_SPACES;

    /**
     * Sanitizes and sets an integer value to a text field with range validation.
     * 
     * Parses the text input as an integer, validates it within the specified
     * range, and updates both the field's value and display text. Handles
     * empty input gracefully by preserving the trimmed text.
     * 
     * @param field The text field to update
     * @param textValue The text input to parse
     * @param minValue Minimum allowed integer value
     * @param maxValue Maximum allowed integer value
     */
    public static function setTextValueToInt(field:BaseTextFieldView, textValue:String, minValue:Int, maxValue:Int) {

        var trimmedValue = textValue.trim();
        if (trimmedValue != '' && trimmedValue != '-') {
            var intValue:Null<Int> = Std.parseInt(textValue);
            if (intValue != null && !Math.isNaN(intValue) && Math.isFinite(intValue)) {
                if (intValue < minValue) {
                    intValue = minValue;
                }
                if (intValue > maxValue) {
                    intValue = maxValue;
                }
                field.setValue(field, intValue);
                field.textValue = '' + intValue;
            }
        }
        else {
            field.textValue = trimmedValue;
        }
        field.invalidateTextValue();

    }

    /**
     * Sets a default integer value when the field is empty.
     * 
     * Assigns a default value of 0 (clamped to the valid range) when
     * the text field is empty or needs a default value.
     * 
     * @param field The text field to update
     * @param minValue Minimum allowed integer value
     * @param maxValue Maximum allowed integer value
     * @return The assigned default value
     */
    public static function setEmptyToInt(field:BaseTextFieldView, minValue:Int, maxValue:Int):Int {

        var value:Int = 0;
        if (value < minValue) {
            value = minValue;
        }
        if (value > maxValue) {
            value = maxValue;
        }
        field.textValue = '' + value;
        return value;

    }

    /**
     * Sanitizes and sets a float value to a text field with advanced formatting.
     * 
     * Parses the text input as a float with intelligent formatting that preserves
     * decimal editing state. Supports comma-to-period conversion, range validation,
     * and configurable rounding. The finishing parameter controls whether to apply
     * final formatting or preserve the user's editing state.
     * 
     * @param field The text field to update
     * @param textValue The text input to parse
     * @param minValue Minimum allowed float value
     * @param maxValue Maximum allowed float value
     * @param round Rounding factor (1 = integer, >1 = decimal places)
     * @param finishing Whether to apply final formatting (true) or preserve editing state (false)
     */
    public static function setTextValueToFloat(field:BaseTextFieldView, textValue:String, minValue:Float, maxValue:Float, round:Int, finishing:Bool):Void {

        var trimmedValue = textValue.trim();
        if (trimmedValue != '' && trimmedValue != '-') {
            var textValue = textValue.replace(',', '.');
            var firstChar = textValue.charAt(0);
            var hasSign = firstChar == '-' || firstChar == '+';
            var toReplace = hasSign ? textValue.substring(1) : textValue;
            toReplace = RE_NON_DIGIT_OR_DOT.replace(toReplace, '0');
            textValue = hasSign ? firstChar + toReplace : toReplace;
            var beforeDot = textValue;
            var dotAndAfter:String = null;
            var dotIndex = textValue.indexOf('.');
            if (dotIndex != -1) {
                beforeDot = textValue.substring(0, dotIndex);
                dotAndAfter = '.' + textValue.substring(dotIndex + 1).replace('.', '0');
            }
            var floatValue:Null<Float> = Std.parseFloat(textValue);
            if (floatValue != null && !Math.isNaN(floatValue) && Math.isFinite(floatValue)) {
                if (floatValue < minValue) {
                    floatValue = minValue;
                }
                if (floatValue > maxValue) {
                    floatValue = maxValue;
                }
                if (round == 1) {
                    floatValue = Math.round(floatValue);
                }
                else if (round > 1) {
                    floatValue = Math.round(floatValue * round) / round;
                }
                field.setValue(field, floatValue);
                if (finishing) {
                    field.textValue = '' + floatValue;
                }
                else {
                    field.textValue = beforeDot + (dotAndAfter != null ? dotAndAfter : '');
                }
            }
        }
        else {
            field.textValue = trimmedValue;
        }
        field.invalidateTextValue();

    }

    /**
     * Sets a default float value when the field is empty.
     * 
     * Assigns a default value of 0.0 (clamped to the valid range and rounded
     * according to the specified precision) when the text field is empty.
     * 
     * @param field The text field to update
     * @param minValue Minimum allowed float value
     * @param maxValue Maximum allowed float value
     * @param round Rounding factor (1 = integer, >1 = decimal places)
     * @return The assigned default value
     */
    public static function setEmptyToFloat(field:BaseTextFieldView, minValue:Float, maxValue:Float, round:Int):Float {

        var value:Float = 0.0;
        if (value < minValue) {
            value = minValue;
        }
        if (value > maxValue) {
            value = maxValue;
        }
        if (round == 1) {
            value = Math.round(value);
        }
        else if (round > 1) {
            value = Math.round(value * round) / round;
        }
        field.textValue = '' + value;
        return value;

    }

    /**
     * Resets a text field to display '0' for empty float values.
     * 
     * Simple utility method to set the text field to display '0' and
     * trigger a text value invalidation for UI updates.
     * 
     * @param field The text field to reset
     */
    public static function setTextValueToEmptyFloat(field:BaseTextFieldView):Void {

        field.textValue = '0';
        field.invalidateTextValue();

    }

    /**
     * Evaluates and applies mathematical operations in text input.
     * 
     * Detects mathematical expressions in the text input (+, -, *, /) and
     * evaluates them, then applies the result to the field. Supports both
     * integer and float operations with proper range validation and rounding.
     * 
     * The method looks for operators in the text and attempts to parse the
     * operands on either side. If the operation is valid, it computes the
     * result and updates the field. If the operation is invalid but one
     * operand is valid, it uses that operand as the value.
     * 
     * @param field The text field to update
     * @param textValue The text input potentially containing math operations
     * @param minValue Minimum allowed value
     * @param maxValue Maximum allowed value
     * @param castToInt Whether to treat the result as an integer
     * @param round Rounding factor for float values
     * @return `true` if a mathematical operation was found and processed, `false` otherwise
     */
    public static function applyFloatOrIntOperationsIfNeeded(field:BaseTextFieldView, textValue:String, minValue:Float, maxValue:Float, castToInt:Bool, round:Int):Bool {

        var addIndex = textValue.indexOf('+');
        var subtractIndex = textValue.indexOf('-');
        var multiplyIndex = textValue.indexOf('*');
        var divideIndex = textValue.indexOf('/');
        if (addIndex > 0) {
            var before = textValue.substr(0, addIndex).trim();
            var after = textValue.substr(addIndex + 1).trim();
            var result = Std.parseFloat(before) + Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, ''+result, minValue, maxValue, round, true);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, round, true);
            }
            return true;
        }
        else if (subtractIndex > 0) {
            var before = textValue.substr(0, subtractIndex).trim();
            var after = textValue.substr(subtractIndex + 1).trim();
            var result = Std.parseFloat(before) - Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, ''+result, minValue, maxValue, round, true);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, round, true);
            }
            return true;
        }
        else if (multiplyIndex > 0) {
            var before = textValue.substr(0, multiplyIndex).trim();
            var after = textValue.substr(multiplyIndex + 1).trim();
            var result = Std.parseFloat(before) * Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, ''+result, minValue, maxValue, round, true);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, round, true);
            }
            return true;
        }
        else if (divideIndex > 0) {
            var before = textValue.substr(0, divideIndex).trim();
            var after = textValue.substr(divideIndex + 1).trim();
            var result = Std.parseFloat(before) / Std.parseFloat(after);
            if (!Math.isNaN(result)) {
                if (castToInt)
                    setTextValueToInt(field, ''+result, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, ''+result, minValue, maxValue, round, true);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, round, true);
            }
            return true;
        }
        else {
            return false;
        }

    }

}
