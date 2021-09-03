package elements;

import ceramic.Slug;

using StringTools;
using ceramic.Extensions;

class SanitizeTextField {

    public static var CLOSURE_CACHE_SIZE = 128;

    static final RE_NUMERIC_PREFIX = ~/^[0-9]+/;

    static final RE_SPACES = TextUtils.RE_SPACES;

    public static function setTextValueToInt(field:TextFieldView, textValue:String, minValue:Int, maxValue:Int) {

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

    public static function setEmptyToInt(field:TextFieldView, minValue:Int, maxValue:Int):Int {

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

    public static function setTextValueToFloat(field:TextFieldView, textValue:String, minValue:Float, maxValue:Float):Void {

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
                field.setValue(field, floatValue);
                field.textValue = '' + floatValue + (endsWithDot && !hasMultipleDots ? '.' : '');
            }
        }
        else {
            field.textValue = trimmedValue;
        }
        field.invalidateTextValue();

    }

    public static function setEmptyToFloat(field:TextFieldView, minValue:Float, maxValue:Float):Float {

        var value:Float = 0.0;
        if (value < minValue) {
            value = minValue;
        }
        if (value > maxValue) {
            value = maxValue;
        }
        field.textValue = '' + value;
        return value;

    }

    public static function setTextValueToEmptyFloat(field:TextFieldView):Void {

        field.textValue = '0';
        field.invalidateTextValue();

    }

}
