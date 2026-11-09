// New code for Cityscape (not a port): JavaScript value semantics used where
// ported code inspects untyped input (editor options given as Haxe anonymous
// structures, JSON values).
package cityscape.base.common;

import Type.ValueType;

/**
 * JavaScript semantics on Haxe values, so that ported validation code
 * (`typeof x === 'string'`, `Boolean(x)`, `parseInt(x, 10)`, `parseFloat(x)`)
 * gives the same results on every target.
 *
 * Haxe has a single `null`: JavaScript's `undefined` and `null` both map to
 * it (see docs/DEVIATIONS.md, "Options set to null").
 */
class JsValues {

    /**
     * `typeof value === 'undefined'` (or `null`, which Haxe cannot tell apart).
     */
    public static inline function isUndefined(value:Any):Bool {
        return value == null;
    }

    /**
     * `typeof value === 'string'`.
     */
    public static function isString(value:Any):Bool {
        return value != null && Std.isOfType(value, String);
    }

    /**
     * `typeof value === 'number'`.
     */
    public static function isNumber(value:Any):Bool {
        return switch Type.typeof(value) {
            case TInt | TFloat: true;
            case _: false;
        }
    }

    /**
     * `typeof value === 'boolean'`.
     */
    public static function isBoolean(value:Any):Bool {
        return switch Type.typeof(value) {
            case TBool: true;
            case _: false;
        }
    }

    /**
     * `typeof value === 'function'`.
     */
    public static function isFunction(value:Any):Bool {
        return switch Type.typeof(value) {
            case TFunction: true;
            case _: false;
        }
    }

    /**
     * `Array.isArray(value)`.
     */
    public static function isArray(value:Any):Bool {
        return value != null && Std.isOfType(value, Array);
    }

    /**
     * `!!value && typeof value === 'object'`: anonymous structures, arrays
     * and class instances other than strings.
     */
    public static function isObject(value:Any):Bool {
        return switch Type.typeof(value) {
            case TObject: true;
            case TClass(c): c != String;
            case TEnum(_): true;
            case _: false;
        }
    }

    /**
     * Reads the field `name` of an object (anonymous structure or class
     * instance), `null` when absent or when `object` is not an object.
     */
    public static function field(object:Any, name:String):Any {
        if (!isObject(object))
            return null;
        return Reflect.field(object, name);
    }

    /**
     * `Boolean(value)`: false for `null`, `false`, `0`, `NaN` and `''`.
     */
    public static function truthy(value:Any):Bool {
        return switch Type.typeof(value) {
            case TNull: false;
            case TBool: (value : Bool);
            case TInt: (value : Int) != 0;
            case TFloat:
                final f:Float = value;
                !(f == 0 || Math.isNaN(f));
            case TClass(c) if (c == String): (value : String).length > 0;
            case _: true;
        }
    }

    /**
     * `String(value)` for the values ported code converts: strings, numbers,
     * booleans, `null` and arrays (joined with commas). Other objects give
     * `'[object Object]'`, functions `'function'`.
     */
    public static function toJsString(value:Any):String {
        return switch Type.typeof(value) {
            case TNull: 'null';
            case TBool: (value : Bool) ? 'true' : 'false';
            case TInt: Std.string((value : Int));
            case TFloat: numberToString((value : Float));
            case TClass(c) if (c == String): (value : String);
            case TClass(c) if (c == Array):
                final array:Array<Any> = value;
                final parts = [];
                for (item in array) {
                    parts.push(item == null ? '' : toJsString(item));
                }
                parts.join(',');
            case TFunction: 'function';
            case _: '[object Object]';
        }
    }

    /**
     * `String(number)` for integers (exact) and NaN / infinities; other
     * values use Haxe's `Std.string`, which matches JavaScript on js but may
     * format some decimals differently on other targets.
     */
    public static function numberToString(value:Float):String {
        if (Math.isNaN(value))
            return 'NaN';
        if (value == Math.POSITIVE_INFINITY)
            return 'Infinity';
        if (value == Math.NEGATIVE_INFINITY)
            return '-Infinity';
        if (value == Math.ffloor(value) && Math.abs(value) < 2147483648.0)
            return Std.string(Std.int(value));
        return Std.string(value);
    }

    /**
     * `parseInt(value, 10)`: `value` converted with `String(value)`, leading
     * white space skipped, an optional sign, then the longest run of decimal
     * digits. `NaN` when there is no digit.
     */
    public static function parseInt(value:Any):Float {
        if (isNumber(value))
            return parseIntOfNumber((value : Float));
        final s = toJsString(value);
        var i = skipWhiteSpace(s, 0);
        final len = s.length;
        var negative = false;
        if (i < len) {
            final c = StringTools.fastCodeAt(s, i);
            if (c == '+'.code || c == '-'.code) {
                negative = c == '-'.code;
                i++;
            }
        }
        final start = i;
        var result = 0.0;
        while (i < len) {
            final c = StringTools.fastCodeAt(s, i);
            if (c < '0'.code || c > '9'.code)
                break;
            result = result * 10 + (c - '0'.code);
            i++;
        }
        if (i == start)
            return Math.NaN;
        return negative ? -result : result;
    }

    /**
     * `parseInt(String(number), 10)`: the integer part, except for the
     * magnitudes JavaScript writes with an exponent (`1e+21`, `1.5e-7`), where
     * it is the first digit of the mantissa.
     */
    static function parseIntOfNumber(value:Float):Float {
        if (Math.isNaN(value) || !Math.isFinite(value))
            return Math.NaN;
        if (value == 0)
            return 0;
        final abs = Math.abs(value);
        if (abs >= 1e21 || abs < 1e-6) {
            var exponent = Math.floor(Math.log(abs) / Math.log(10));
            var mantissa = abs / Math.pow(10, exponent);
            if (mantissa >= 10)
                mantissa /= 10;
            else if (mantissa < 1)
                mantissa *= 10;
            final digit = Math.ffloor(mantissa);
            return value < 0 ? -digit : digit;
        }
        final truncated = Math.ffloor(abs);
        return value < 0 ? -truncated : truncated;
    }

    /**
     * `parseFloat(value)`: `value` converted with `String(value)`, leading
     * white space skipped, then the longest prefix that is a decimal literal
     * (sign, digits, fraction, exponent) or `Infinity`. `NaN` otherwise.
     */
    public static function parseFloat(value:Any):Float {
        if (isNumber(value))
            return (value : Float);
        final s = toJsString(value);
        final len = s.length;
        var i = skipWhiteSpace(s, 0);
        final start = i;
        if (i < len) {
            final c = StringTools.fastCodeAt(s, i);
            if (c == '+'.code || c == '-'.code)
                i++;
        }
        if (s.substr(i, 8) == 'Infinity') {
            return StringTools.fastCodeAt(s, start) == '-'.code ? Math.NEGATIVE_INFINITY : Math.POSITIVE_INFINITY;
        }
        final digitsStart = i;
        var digits = 0;
        while (i < len && isDigit(StringTools.fastCodeAt(s, i))) {
            i++;
            digits++;
        }
        if (i < len && StringTools.fastCodeAt(s, i) == '.'.code) {
            var j = i + 1;
            var fraction = 0;
            while (j < len && isDigit(StringTools.fastCodeAt(s, j))) {
                j++;
                fraction++;
            }
            if (digits > 0 || fraction > 0) {
                i = j;
                digits += fraction;
            }
        }
        if (digits == 0)
            return Math.NaN;
        if (i < len && (StringTools.fastCodeAt(s, i) == 'e'.code || StringTools.fastCodeAt(s, i) == 'E'.code)) {
            var j = i + 1;
            if (j < len && (StringTools.fastCodeAt(s, j) == '+'.code || StringTools.fastCodeAt(s, j) == '-'.code))
                j++;
            final expStart = j;
            while (j < len && isDigit(StringTools.fastCodeAt(s, j)))
                j++;
            if (j > expStart)
                i = j;
        }
        if (i == digitsStart)
            return Math.NaN;
        return Std.parseFloat(s.substring(start, i));
    }

    static inline function isDigit(c:Int):Bool {
        return c >= '0'.code && c <= '9'.code;
    }

    /**
     * Skips JavaScript white space and line terminators (`StrWhiteSpaceChar`).
     */
    static function skipWhiteSpace(s:String, i:Int):Int {
        final len = s.length;
        while (i < len) {
            final c = StringTools.fastCodeAt(s, i);
            final isSpace = switch c {
                case 0x09 | 0x0a | 0x0b | 0x0c | 0x0d | 0x20 | 0xa0 | 0x1680 | 0x2028 | 0x2029 | 0x202f | 0x205f | 0x3000 | 0xfeff: true;
                case _: c >= 0x2000 && c <= 0x200a;
            }
            if (!isSpace)
                break;
            i++;
        }
        return i;
    }

}
