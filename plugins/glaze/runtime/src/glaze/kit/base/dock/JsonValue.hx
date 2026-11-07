// New code for the Haxe port of gpui-kit: stands for `serde_json::Value` and
// for the JSON text serde_json 1.0.151 (David Tolnay, MIT OR Apache-2.0)
// reads and writes for the dock's persisted layout, floats formatted like
// zmij 1.0.23 (David Tolnay, MIT OR Apache-2.0), the formatter serde_json
// uses. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.SpringMath;

/**
 * A JSON value, like `serde_json::Value` built with the `preserve_order`
 * feature (the reference harness enables it): object keys keep their order.
 *
 * Numbers keep serde_json's distinction between integers and floats, since
 * `1` and `1.0` are different values there (and written back as they came).
 * Integers are stored in a `Float`, exact up to 2^53.
 */
enum JsonValue {
    JNull;
    JBool(value:Bool);
    JInt(value:Float);
    JFloat(value:Float);
    /**
     * A float serialized from an `f32` field (serde's `serialize_f32`):
     * written with the shortest digits that read back as the same `f32`
     * (`350.0`, `233.33333`). It equals the `JFloat` of the same value, like
     * the `Value` serde_json builds from an `f32`.
     */
    JFloat32(value:Float);
    JString(value:String);
    JArray(values:Array<JsonValue>);
    JObject(object:JsonObject);
}

/**
 * The map of a JSON object, in insertion order (`IndexMap`). A key set twice
 * keeps its first position and its last value, like serde_json.
 */
class JsonObject {

    public final keys:Array<String> = [];

    final values:Map<String, JsonValue> = new Map();

    public function new() {}

    public function set(key:String, value:JsonValue):Void {
        if (!values.exists(key)) keys.push(key);
        values.set(key, value);
    }

    public inline function get(key:String):Null<JsonValue> {
        return values.get(key);
    }

    public inline function exists(key:String):Bool {
        return values.exists(key);
    }

    public inline function length():Int {
        return keys.length;
    }

}

/**
 * Reading, writing and comparing `JsonValue`s.
 */
class JsonValueTools {

    /**
     * `serde_json::from_str::<Value>`: throws a `JsonError` on invalid JSON
     * or trailing characters.
     */
    public static function parse(text:String):JsonValue {
        return new JsonParser(text).parseDocument();
    }

    /**
     * `serde_json::to_string`: compact.
     */
    public static function stringify(value:JsonValue):String {
        final buf = new StringBuf();
        write(buf, value, null, 0);
        return buf.toString();
    }

    /**
     * `serde_json::to_string_pretty`: two space indent.
     */
    public static function stringifyPretty(value:JsonValue):String {
        final buf = new StringBuf();
        write(buf, value, '  ', 0);
        return buf.toString();
    }

    /**
     * Derived `PartialEq` of `serde_json::Value`: an integer never equals a
     * float, objects compare as maps (the order of keys does not matter).
     */
    public static function equals(a:JsonValue, b:JsonValue):Bool {
        return switch [a, b] {
            case [JNull, JNull]: true;
            case [JBool(x), JBool(y)]: x == y;
            case [JInt(x), JInt(y)]: x == y;
            case [JFloat(x) | JFloat32(x), JFloat(y) | JFloat32(y)]: x == y;
            case [JString(x), JString(y)]: x == y;
            case [JArray(x), JArray(y)]:
                if (x.length != y.length) return false;
                for (i in 0...x.length) if (!equals(x[i], y[i])) return false;
                true;
            case [JObject(x), JObject(y)]:
                if (x.length() != y.length()) return false;
                for (key in x.keys) {
                    final other = y.get(key);
                    if (other == null || !equals(x.get(key), other)) return false;
                }
                true;
            case _: false;
        }
    }

    /**
     * A JSON object from key / value pairs (Rust `json!({...})`).
     */
    public static function object(pairs:Array<{key:String, value:JsonValue}>):JsonValue {
        final object = new JsonObject();
        for (pair in pairs) object.set(pair.key, pair.value);
        return JObject(object);
    }

    static function write(buf:StringBuf, value:JsonValue, indent:Null<String>, depth:Int):Void {
        switch value {
            case JNull:
                buf.add('null');
            case JBool(v):
                buf.add(v ? 'true' : 'false');
            case JInt(v):
                buf.add(formatInteger(v));
            case JFloat(v):
                buf.add(formatF64(v));
            case JFloat32(v):
                buf.add(formatF32(v));
            case JString(v):
                writeString(buf, v);
            case JArray(values):
                if (values.length == 0) {
                    buf.add('[]');
                    return;
                }
                buf.add('[');
                for (i in 0...values.length) {
                    if (i > 0) buf.add(',');
                    newline(buf, indent, depth + 1);
                    write(buf, values[i], indent, depth + 1);
                }
                newline(buf, indent, depth);
                buf.add(']');
            case JObject(object):
                if (object.length() == 0) {
                    buf.add('{}');
                    return;
                }
                buf.add('{');
                var first = true;
                for (key in object.keys) {
                    if (!first) buf.add(',');
                    first = false;
                    newline(buf, indent, depth + 1);
                    writeString(buf, key);
                    buf.add(indent != null ? ': ' : ':');
                    write(buf, object.get(key), indent, depth + 1);
                }
                newline(buf, indent, depth);
                buf.add('}');
        }
    }

    static inline function newline(buf:StringBuf, indent:Null<String>, depth:Int):Void {
        if (indent == null) return;
        buf.add('\n');
        for (_ in 0...depth) buf.add(indent);
    }

    static final HEX = '0123456789abcdef';

    /**
     * serde_json's string escaping: `"`, `\`, `\b`, `\f`, `\n`, `\r`, `\t`,
     * other control characters as `\u00xx`; everything else is written as is.
     */
    public static function writeString(buf:StringBuf, value:String):Void {
        buf.add('"');
        var start = 0;
        final length = value.length;
        for (i in 0...length) {
            final c = StringTools.fastCodeAt(value, i);
            if (c >= 0x20 && c != '"'.code && c != '\\'.code) continue;
            if (i > start) buf.add(value.substring(start, i));
            start = i + 1;
            switch c {
                case '"'.code: buf.add('\\"');
                case '\\'.code: buf.add('\\\\');
                case 0x08: buf.add('\\b');
                case 0x0c: buf.add('\\f');
                case '\n'.code: buf.add('\\n');
                case '\r'.code: buf.add('\\r');
                case '\t'.code: buf.add('\\t');
                case _:
                    buf.add('\\u00');
                    buf.add(HEX.charAt(c >> 4));
                    buf.add(HEX.charAt(c & 15));
            }
        }
        if (length > start) buf.add(value.substring(start, length));
        buf.add('"');
    }

    /**
     * An integer stored in a float, written without fraction or exponent.
     */
    public static function formatInteger(value:Float):String {
        if (value > -2147483648.0 && value < 2147483648.0) {
            return Std.string(Std.int(value));
        }
        var negative = value < 0;
        var rest = Math.abs(value);
        final digits = new StringBuf();
        final reversed:Array<Int> = [];
        while (rest >= 1) {
            final digit = Std.int(rest % 10);
            reversed.push(digit);
            rest = Math.ffloor(rest / 10);
        }
        if (negative) digits.add('-');
        var i = reversed.length - 1;
        while (i >= 0) {
            digits.add(reversed[i]);
            i--;
        }
        return digits.toString();
    }

    /**
     * serde_json's `f32` output (zmij): the shortest digits that read back as
     * the same `f32`, fixed notation for a decimal exponent in -6..=12,
     * scientific otherwise (`1e-7`, `1.5e+13`). Integers keep a `.0`.
     */
    public static function formatF32(value:Float):String {
        return formatFloat(SpringMath.f32(value), true);
    }

    /**
     * serde_json's `f64` output (zmij): fixed notation for a decimal exponent
     * in -5..=15.
     */
    public static function formatF64(value:Float):String {
        return formatFloat(value, false);
    }

    static function formatFloat(value:Float, single:Bool):String {
        if (Math.isNaN(value) || !Math.isFinite(value)) {
            // serde_json writes non finite floats as null
            return 'null';
        }
        final negative = value < 0 || (value == 0 && 1 / value < 0);
        final abs = Math.abs(value);
        final sign = negative ? '-' : '';
        if (abs == 0) return sign + '0.0';

        final shortest = shortestDigits(abs, single);
        final digits = shortest.digits;
        final exp = shortest.exp;
        final length = digits.length;
        final fixedMin = single ? -6 : -5;
        final fixedMax = single ? 12 : 15;

        if (exp >= fixedMin && exp <= fixedMax) {
            if (length - 1 <= exp) {
                return sign + digits + zeros(exp - (length - 1)) + '.0';
            }
            else if (exp >= 0) {
                return sign + digits.substr(0, exp + 1) + '.' + digits.substr(exp + 1);
            }
            else {
                return sign + '0.' + zeros(-exp - 1) + digits;
            }
        }

        final mantissa = length > 1 ? digits.charAt(0) + '.' + digits.substr(1) : digits;
        return sign + mantissa + 'e' + (exp >= 0 ? '+' : '-') + Std.string(exp >= 0 ? exp : -exp);
    }

    static function zeros(count:Int):String {
        final buf = new StringBuf();
        for (_ in 0...count) buf.add('0');
        return buf.toString();
    }

    /**
     * The shortest decimal digits `d1d2...dn` and exponent `e` such that
     * `d1.d2...dn * 10^e` reads back as `value` (an `f32` when `single`), the
     * candidate closest to `value` first.
     */
    static function shortestDigits(value:Float, single:Bool):{digits:String, exp:Int} {
        final maxDigits = single ? 9 : 17;
        var exp = Math.floor(Math.log(value) / Math.log(10));
        // log10 can be off by one near powers of ten
        if (pow10(exp) > value) exp--;
        if (pow10(exp + 1) <= value) exp++;

        for (precision in 1...maxDigits + 1) {
            final shift = precision - 1 - exp;
            final scaled = shift >= 0 ? value * pow10(shift) : value / pow10(-shift);
            final low = Math.ffloor(scaled);
            final high = low + 1;
            final candidates = scaled - low <= high - scaled ? [low, high] : [high, low];
            for (candidate in candidates) {
                if (candidate <= 0) continue;
                final text = formatInteger(candidate);
                final candidateExp = exp + (text.length - precision);
                final parsed = Std.parseFloat(text.charAt(0) + (text.length > 1 ? '.' + text.substr(1) : '') + 'e' + candidateExp);
                final readBack = single ? SpringMath.f32(parsed) : parsed;
                if (readBack == value) {
                    return {digits: trimZeros(text), exp: candidateExp};
                }
            }
        }

        // Not reached for finite values; keep every digit as a fallback.
        final shift = maxDigits - 1 - exp;
        final scaled = shift >= 0 ? value * pow10(shift) : value / pow10(-shift);
        return {digits: trimZeros(formatInteger(Math.fround(scaled))), exp: exp};
    }

    static function trimZeros(digits:String):String {
        var end = digits.length;
        while (end > 1 && digits.charAt(end - 1) == '0') end--;
        return digits.substr(0, end);
    }

    static function pow10(exp:Int):Float {
        return Math.pow(10, exp);
    }

}

/**
 * A parse error, with serde_json's wording where it matters.
 */
class JsonError extends haxe.Exception {}

/**
 * A strict JSON reader (RFC 8259, like serde_json).
 */
private class JsonParser {

    final text:String;

    var pos:Int = 0;

    public function new(text:String) {
        this.text = text;
    }

    public function parseDocument():JsonValue {
        skipWhitespace();
        final value = parseValue();
        skipWhitespace();
        if (pos < text.length) fail('trailing characters');
        return value;
    }

    function fail(message:String):Dynamic {
        throw new JsonError('$message at offset $pos');
    }

    inline function peek():Int {
        return pos < text.length ? StringTools.fastCodeAt(text, pos) : -1;
    }

    function skipWhitespace():Void {
        while (pos < text.length) {
            final c = StringTools.fastCodeAt(text, pos);
            if (c == ' '.code || c == '\n'.code || c == '\r'.code || c == '\t'.code) pos++;
            else break;
        }
    }

    function expectWord(word:String):Void {
        if (text.substr(pos, word.length) != word) fail('expected value');
        pos += word.length;
    }

    function parseValue():JsonValue {
        return switch peek() {
            case 'n'.code:
                expectWord('null');
                JNull;
            case 't'.code:
                expectWord('true');
                JBool(true);
            case 'f'.code:
                expectWord('false');
                JBool(false);
            case '"'.code:
                JString(parseString());
            case '['.code:
                parseArray();
            case '{'.code:
                parseObject();
            case c if (c == '-'.code || (c >= '0'.code && c <= '9'.code)):
                parseNumber();
            case -1:
                fail('EOF while parsing a value');
            case _:
                fail('expected value');
        }
    }

    function parseArray():JsonValue {
        pos++;
        final values:Array<JsonValue> = [];
        skipWhitespace();
        if (peek() == ']'.code) {
            pos++;
            return JArray(values);
        }
        while (true) {
            skipWhitespace();
            values.push(parseValue());
            skipWhitespace();
            final c = peek();
            pos++;
            if (c == ','.code) continue;
            if (c == ']'.code) break;
            fail('expected `,` or `]`');
        }
        return JArray(values);
    }

    function parseObject():JsonValue {
        pos++;
        final object = new JsonObject();
        skipWhitespace();
        if (peek() == '}'.code) {
            pos++;
            return JObject(object);
        }
        while (true) {
            skipWhitespace();
            if (peek() != '"'.code) fail('key must be a string');
            final key = parseString();
            skipWhitespace();
            if (peek() != ':'.code) fail('expected `:`');
            pos++;
            skipWhitespace();
            object.set(key, parseValue());
            skipWhitespace();
            final c = peek();
            pos++;
            if (c == ','.code) continue;
            if (c == '}'.code) break;
            fail('expected `,` or `}`');
        }
        return JObject(object);
    }

    function parseString():String {
        pos++;
        final buf = new StringBuf();
        var start = pos;
        while (true) {
            if (pos >= text.length) fail('EOF while parsing a string');
            final c = StringTools.fastCodeAt(text, pos);
            if (c == '"'.code) {
                buf.add(text.substring(start, pos));
                pos++;
                return buf.toString();
            }
            if (c < 0x20) fail('control character (\\u0000-\\u001F) found while parsing a string');
            if (c != '\\'.code) {
                pos++;
                continue;
            }
            buf.add(text.substring(start, pos));
            pos++;
            final e = peek();
            pos++;
            switch e {
                case '"'.code: buf.add('"');
                case '\\'.code: buf.add('\\');
                case '/'.code: buf.add('/');
                case 'b'.code: buf.addChar(0x08);
                case 'f'.code: buf.addChar(0x0c);
                case 'n'.code: buf.add('\n');
                case 'r'.code: buf.add('\r');
                case 't'.code: buf.add('\t');
                case 'u'.code:
                    var code = parseHex4();
                    if (code >= 0xD800 && code <= 0xDBFF) {
                        if (text.substr(pos, 2) != '\\u') fail('unexpected end of hex escape');
                        pos += 2;
                        final low = parseHex4();
                        if (low < 0xDC00 || low > 0xDFFF) fail('lone leading surrogate in hex escape');
                        code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
                    }
                    else if (code >= 0xDC00 && code <= 0xDFFF) {
                        fail('lone leading surrogate in hex escape');
                    }
                    buf.addChar(code);
                case _:
                    fail('invalid escape');
            }
            start = pos;
        }
    }

    function parseHex4():Int {
        var value = 0;
        for (_ in 0...4) {
            final c = peek();
            pos++;
            final digit = if (c >= '0'.code && c <= '9'.code) c - '0'.code
                else if (c >= 'a'.code && c <= 'f'.code) c - 'a'.code + 10
                else if (c >= 'A'.code && c <= 'F'.code) c - 'A'.code + 10
                else fail('invalid escape');
            value = value * 16 + digit;
        }
        return value;
    }

    function parseNumber():JsonValue {
        final start = pos;
        final negative = peek() == '-'.code;
        if (negative) pos++;
        if (peek() == '0'.code) {
            pos++;
        }
        else if (peek() >= '1'.code && peek() <= '9'.code) {
            while (peek() >= '0'.code && peek() <= '9'.code) pos++;
        }
        else {
            fail('invalid number');
        }
        var isFloat = false;
        if (peek() == '.'.code) {
            isFloat = true;
            pos++;
            if (!(peek() >= '0'.code && peek() <= '9'.code)) fail('invalid number');
            while (peek() >= '0'.code && peek() <= '9'.code) pos++;
        }
        if (peek() == 'e'.code || peek() == 'E'.code) {
            isFloat = true;
            pos++;
            if (peek() == '+'.code || peek() == '-'.code) pos++;
            if (!(peek() >= '0'.code && peek() <= '9'.code)) fail('invalid number');
            while (peek() >= '0'.code && peek() <= '9'.code) pos++;
        }
        final literal = text.substring(start, pos);
        final value = Std.parseFloat(literal);
        // serde_json reads `-0` as the float -0.0, and integers out of the
        // i64 / u64 range as floats.
        if (!isFloat && negative && value == 0) return JFloat(-0.0);
        if (!isFloat && Math.abs(value) < 18446744073709551616.0) return JInt(value);
        return JFloat(value);
    }

}
