// Ported from vscode src/vs/editor/common/languages/supports/inplaceReplaceSupport.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.JsValues;
import cityscape.base.common.RegExp;
import cityscape.common.Languages.IInplaceReplaceSupportResult;
import cityscape.common.core.Range.IRange;

class BasicInplaceReplace {

    /**
     * Monaco's `INSTANCE` (the class holds no mutable state).
     */
    public static final INSTANCE = new BasicInplaceReplace();

    public function new() {}

    public function navigateValueSet(range1:Null<IRange>, text1:Null<String>, range2:Null<IRange>, text2:Null<String>, up:Bool):Null<IInplaceReplaceSupportResult> {

        if (range1 != null && text1 != null && text1.length > 0) {
            final result = doNavigateValueSet(text1, up);
            if (result != null && result.length > 0) {
                return {
                    range: range1,
                    value: result
                };
            }
        }

        if (range2 != null && text2 != null && text2.length > 0) {
            final result = doNavigateValueSet(text2, up);
            if (result != null && result.length > 0) {
                return {
                    range: range2,
                    value: result
                };
            }
        }

        return null;
    }

    function doNavigateValueSet(text:String, up:Bool):Null<String> {
        final numberResult = numberReplace(text, up);
        if (numberResult != null) {
            return numberResult;
        }
        return textReplace(text, up);
    }

    function numberReplace(value:String, up:Bool):Null<String> {
        final precision = Math.pow(10, value.length - (value.lastIndexOf('.') + 1));
        var n1 = jsNumber(value);
        final n2 = JsValues.parseFloat(value);

        if (!Math.isNaN(n1) && !Math.isNaN(n2) && n1 == n2) {

            if (n1 == 0 && !up) {
                return null; // don't do negative
                //			} else if(n1 === 9 && up) {
                //				return null; // don't insert 10 into a number
            }
            else {
                n1 = Math.ffloor(n1 * precision);
                n1 += up ? precision : -precision;
                return JsValues.numberToString(n1 / precision);
            }
        }

        return null;
    }

    /**
     * JavaScript's `Number(value)` on a string.
     */
    static function jsNumber(value:String):Float {
        var start = 0;
        var end = value.length;
        while (start < end && cityscape.base.common.Strings.isJsWhitespace(StringTools.fastCodeAt(value, start))) {
            start++;
        }
        while (end > start && cityscape.base.common.Strings.isJsWhitespace(StringTools.fastCodeAt(value, end - 1))) {
            end--;
        }
        final s = value.substring(start, end);
        if (s.length == 0) {
            return 0;
        }
        final radixMatch = new RegExp('^0([xXoObB])([0-9a-fA-F]+)$').exec(s);
        if (radixMatch != null) {
            final radix = switch (radixMatch[1].toLowerCase()) {
                case 'x': 16;
                case 'o': 8;
                case _: 2;
            }
            var result = 0.0;
            final digits = radixMatch[2];
            for (i in 0...digits.length) {
                final d = Std.parseInt('0x' + digits.charAt(i));
                if (d == null || d >= radix) {
                    return Math.NaN;
                }
                result = result * radix + d;
            }
            return result;
        }
        if (new RegExp('^[+-]?(Infinity|(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?)$').test(s)) {
            return JsValues.parseFloat(s);
        }
        return Math.NaN;
    }

    final _defaultValueSet:Array<Array<String>> = [
        ['true', 'false'],
        ['True', 'False'],
        ['Private', 'Public', 'Friend', 'ReadOnly', 'Partial', 'Protected', 'WriteOnly'],
        ['public', 'protected', 'private'],
    ];

    function textReplace(value:String, up:Bool):Null<String> {
        return valueSetsReplace(_defaultValueSet, value, up);
    }

    function valueSetsReplace(valueSets:Array<Array<String>>, value:String, up:Bool):Null<String> {
        var result:Null<String> = null;
        var i = 0;
        final len = valueSets.length;
        while (result == null && i < len) {
            result = valueSetReplace(valueSets[i], value, up);
            i++;
        }
        return result;
    }

    function valueSetReplace(valueSet:Array<String>, value:String, up:Bool):Null<String> {
        var idx = valueSet.indexOf(value);
        if (idx >= 0) {
            idx += up ? 1 : -1;
            if (idx < 0) {
                idx = valueSet.length - 1;
            }
            else {
                idx %= valueSet.length;
            }
            return valueSet[idx];
        }
        return null;
    }

}
