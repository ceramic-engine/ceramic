package elements;

import ceramic.Slug;

using StringTools;
using ceramic.Extensions;

class SanitizeTextField {

    public static var CLOSURE_CACHE_SIZE = 128;

    static final RE_NUMERIC_PREFIX = ~/^[0-9]+/;

    static final RE_SPACES = TextUtils.RE_SPACES;

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

    public static function setTextValueToFloat(field:BaseTextFieldView, textValue:String, minValue:Float, maxValue:Float, decimals:Int):Void {

        var trimmedValue = textValue.trim();
        if (trimmedValue != '' && trimmedValue != '-') {
            var textValue = textValue.replace(',', '.');
            var endsWithDot = false;
            var hasMultipleDots = false;
            if (textValue.endsWith('.')) {
                endsWithDot = true;
                var firstDotIndex = textValue.indexOf('.');
                if (firstDotIndex < textValue.length - 1) {
                    hasMultipleDots = true;
                }
                textValue = textValue.substring(0, textValue.length - 1);
            }
            var floatValue:Null<Float> = Std.parseFloat(textValue);
            if (floatValue != null && !Math.isNaN(floatValue) && Math.isFinite(floatValue)) {
                if (floatValue < minValue) {
                    floatValue = minValue;
                }
                if (floatValue > maxValue) {
                    floatValue = maxValue;
                }
                if (decimals == 0) {
                    floatValue = Math.round(floatValue);
                }
                else if (decimals >= 1) {
                    var power = Math.pow(10, decimals);
                    floatValue = Math.round(floatValue * power) / power;
                }
                field.setValue(field, floatValue);
                field.textValue = '' + floatValue + (endsWithDot && !hasMultipleDots ? '.' : '');
            }
        }
        else {
            field.textValue = trimmedValue;
        }
        field.invalidateTextValue();

    }

    public static function setEmptyToFloat(field:BaseTextFieldView, minValue:Float, maxValue:Float, decimals:Int):Float {

        var value:Float = 0.0;
        if (value < minValue) {
            value = minValue;
        }
        if (value > maxValue) {
            value = maxValue;
        }
        if (decimals == 0) {
            value = Math.round(value);
        }
        else if (decimals >= 1) {
            var power = Math.pow(10, decimals);
            value = Math.round(value * power) / power;
        }
        field.textValue = '' + value;
        return value;

    }

    public static function setTextValueToEmptyFloat(field:BaseTextFieldView):Void {

        field.textValue = '0';
        field.invalidateTextValue();

    }

    public static function applyFloatOrIntOperationsIfNeeded(field:BaseTextFieldView, textValue:String, minValue:Float, maxValue:Float, castToInt:Bool, decimals:Int):Bool {

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
                    setTextValueToFloat(field, ''+result, minValue, maxValue, decimals);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, decimals);
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
                    setTextValueToFloat(field, ''+result, minValue, maxValue, decimals);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, decimals);
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
                    setTextValueToFloat(field, ''+result, minValue, maxValue, decimals);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, decimals);
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
                    setTextValueToFloat(field, ''+result, minValue, maxValue, decimals);
            }
            else {
                if (castToInt)
                    setTextValueToInt(field, before, Std.int(minValue), Std.int(maxValue));
                else
                    setTextValueToFloat(field, before, minValue, maxValue, decimals);
            }
            return true;
        }
        else {
            return false;
        }

    }

}
