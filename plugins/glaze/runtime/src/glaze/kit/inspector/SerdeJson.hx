// Ported from serde_json 1.0.151 (src/de.rs, src/read.rs `SliceRead`, src/error.rs) and
// serde 1.0 (`de::Unexpected`, `de::Error` messages, the derived visitors), the parts
// `serde_json::from_str::<StyleRefinement>` goes through in gpui-kit 0.8.1's inspector.
// Original code Copyright David Tolnay and the serde contributors, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.inspector;

import glaze.kit.base.dock.JsonValue.JsonValueTools;
import haxe.io.Bytes;

/**
 * A serde_json error: its message, and the line and column it was found at
 * (0 when not known yet, like `ErrorCode::Message` errors made by visitors,
 * which `fixPosition` places at the current position).
 */
class SerdeError extends haxe.Exception {

    public final reason:String;

    public final line:Int;

    public final column:Int;

    public function new(reason:String, line:Int = 0, column:Int = 0) {
        super(line == 0 ? reason : '$reason at line $line column $column');
        this.reason = reason;
        this.line = line;
        this.column = column;
    }

    /** serde_json's `Display` of the error. */
    override public function toString():String {
        return message;
    }

    /** `de::Error::custom` */
    public static inline function custom(message:String):SerdeError {
        return new SerdeError(message);
    }

    /** `de::Error::invalid_type` (serde_json's wording: `null` for the unit) */
    public static function invalidType(unexpected:String, expected:String):SerdeError {
        return new SerdeError('invalid type: $unexpected, expected $expected');
    }

    /** `de::Error::invalid_value` */
    public static function invalidValue(unexpected:String, expected:String):SerdeError {
        return new SerdeError('invalid value: $unexpected, expected $expected');
    }

    /** `de::Error::invalid_length` */
    public static function invalidLength(length:Int, expected:String):SerdeError {
        return new SerdeError('invalid length $length, expected $expected');
    }

    /** `de::Error::unknown_variant` */
    public static function unknownVariant(variant:String, expected:Array<String>):SerdeError {
        return new SerdeError('unknown variant `$variant`, ' + (expected.length == 0 ? 'there are no variants' : 'expected ' + oneOf(expected)));
    }

    /** `de::Error::unknown_field` */
    public static function unknownField(field:String, expected:Array<String>):SerdeError {
        return new SerdeError('unknown field `$field`, ' + (expected.length == 0 ? 'there are no fields' : 'expected ' + oneOf(expected)));
    }

    /** `de::Error::missing_field` */
    public static function missingField(field:String):SerdeError {
        return new SerdeError('missing field `$field`');
    }

    /** `de::Error::duplicate_field` */
    public static function duplicateField(field:String):SerdeError {
        return new SerdeError('duplicate field `$field`');
    }

    /** serde's `OneOf` */
    static function oneOf(names:Array<String>):String {
        return switch names.length {
            case 1: '`${names[0]}`';
            case 2: '`${names[0]}` or `${names[1]}`';
            case _: 'one of ' + [for (name in names) '`$name`'].join(', ');
        }
    }

}

/**
 * serde's `Unexpected` values, formatted like serde_json's `JsonUnexpected`.
 */
class Unexpected {

    public static inline final UNIT = 'null';

    public static inline final SEQ = 'sequence';

    public static inline final MAP = 'map';

    public static inline final UNIT_VARIANT = 'unit variant';

    public static inline function bool(value:Bool):String {
        return 'boolean `$value`';
    }

    public static function unsigned(value:Float):String {
        return 'integer `' + JsonValueTools.formatInteger(value) + '`';
    }

    public static function signed(value:Float):String {
        return 'integer `' + JsonValueTools.formatInteger(value) + '`';
    }

    public static function float(value:Float):String {
        return 'floating point `' + JsonValueTools.formatF64(value) + '`';
    }

    /** `Unexpected::Str`: the string with Rust's `Debug` escaping */
    public static function str(value:String):String {
        final buf = new StringBuf();
        buf.add('string "');
        for (c in new haxe.iterators.StringIteratorUnicode(value)) {
            switch c {
                case '"'.code: buf.add('\\"');
                case '\\'.code: buf.add('\\\\');
                case '\n'.code: buf.add('\\n');
                case '\r'.code: buf.add('\\r');
                case '\t'.code: buf.add('\\t');
                case 0: buf.add('\\0');
                case _ if (c < 0x20 || c == 0x7f):
                    buf.add('\\u{' + StringTools.hex(c).toLowerCase() + '}');
                case _:
                    buf.addChar(c);
            }
        }
        buf.add('"');
        return buf.toString();
    }

}

/**
 * A number as serde_json's parser returns it (`ParserNumber`).
 */
enum ParserNumber {
    F64(value:Float);
    U64(value:Float);
    I64(value:Float);
}

/**
 * serde_json's `Deserializer` over a `SliceRead`: byte positions, line and
 * column reporting, whitespace, identifiers, numbers (without the
 * `float_roundtrip` feature), strings, skipped values, and the ends of
 * sequences, maps and documents. The typed visitors are in `StyleJson`.
 */
class SerdeReader {

    final slice:Bytes;

    var index:Int = 0;

    static final POW10:Array<Float> = [for (i in 0...309) Std.parseFloat('1e' + i)];

    public function new(text:String) {
        slice = Bytes.ofString(text);
    }

/// Read

    public inline function peek():Int {
        return index < slice.length ? slice.get(index) : -1;
    }

    public inline function peekOrNull():Int {
        return index < slice.length ? slice.get(index) : 0;
    }

    public inline function next():Int {
        return index < slice.length ? slice.get(index++) : -1;
    }

    public inline function nextOrNull():Int {
        return index < slice.length ? slice.get(index++) : 0;
    }

    public inline function eatChar():Void {
        index++;
    }

    function positionOfIndex(i:Int):{line:Int, column:Int} {
        var startOfLine = 0;
        var j = i - 1;
        while (j >= 0) {
            if (slice.get(j) == '\n'.code) {
                startOfLine = j + 1;
                break;
            }
            j--;
        }
        var line = 1;
        for (k in 0...startOfLine) {
            if (slice.get(k) == '\n'.code) line++;
        }
        return {line: line, column: i - startOfLine};
    }

    /** Error caused by a byte from `next()`. */
    public function error(reason:String):SerdeError {
        final p = positionOfIndex(index);
        return new SerdeError(reason, p.line, p.column);
    }

    /** Error caused by a byte from `peek()`. */
    public function peekError(reason:String):SerdeError {
        final p = positionOfIndex(index + 1 < slice.length ? index + 1 : slice.length);
        return new SerdeError(reason, p.line, p.column);
    }

    /** Places a visitor error (no position yet) at the current position. */
    public function fixPosition(err:SerdeError):SerdeError {
        return err.line == 0 ? error(err.reason) : err;
    }

/// Error codes

    public static inline final EOF_WHILE_PARSING_LIST = 'EOF while parsing a list';
    public static inline final EOF_WHILE_PARSING_OBJECT = 'EOF while parsing an object';
    public static inline final EOF_WHILE_PARSING_STRING = 'EOF while parsing a string';
    public static inline final EOF_WHILE_PARSING_VALUE = 'EOF while parsing a value';
    public static inline final EXPECTED_COLON = 'expected `:`';
    public static inline final EXPECTED_LIST_COMMA_OR_END = 'expected `,` or `]`';
    public static inline final EXPECTED_OBJECT_COMMA_OR_END = 'expected `,` or `}`';
    public static inline final EXPECTED_SOME_IDENT = 'expected ident';
    public static inline final EXPECTED_SOME_VALUE = 'expected value';
    public static inline final INVALID_ESCAPE = 'invalid escape';
    public static inline final INVALID_NUMBER = 'invalid number';
    public static inline final NUMBER_OUT_OF_RANGE = 'number out of range';
    public static inline final INVALID_UNICODE_CODE_POINT = 'invalid unicode code point';
    public static inline final CONTROL_CHARACTER_WHILE_PARSING_STRING = 'control character (\\u0000-\\u001F) found while parsing a string';
    public static inline final KEY_MUST_BE_A_STRING = 'key must be a string';
    public static inline final LONE_LEADING_SURROGATE_IN_HEX_ESCAPE = 'lone leading surrogate in hex escape';
    public static inline final TRAILING_COMMA = 'trailing comma';
    public static inline final TRAILING_CHARACTERS = 'trailing characters';
    public static inline final UNEXPECTED_END_OF_HEX_ESCAPE = 'unexpected end of hex escape';

/// Deserializer

    /** Returns the first non-whitespace byte without consuming it, or -1 at the end. */
    public function parseWhitespace():Int {
        while (true) {
            final c = peek();
            if (c == ' '.code || c == '\n'.code || c == '\t'.code || c == '\r'.code) {
                eatChar();
            }
            else {
                return c;
            }
        }
    }

    public function parseIdent(ident:String):Void {
        for (i in 0...ident.length) {
            final next = next();
            if (next == -1) {
                throw error(EOF_WHILE_PARSING_VALUE);
            }
            if (next != StringTools.fastCodeAt(ident, i)) {
                throw error(EXPECTED_SOME_IDENT);
            }
        }
    }

    /**
     * The error of a value of an unexpected type (consumes scalars to
     * describe them), positioned.
     */
    public function peekInvalidType(expected:String):SerdeError {
        final err = switch peekOrNull() {
            case 'n'.code:
                eatChar();
                parseIdent('ull');
                SerdeError.invalidType(Unexpected.UNIT, expected);
            case 't'.code:
                eatChar();
                parseIdent('rue');
                SerdeError.invalidType(Unexpected.bool(true), expected);
            case 'f'.code:
                eatChar();
                parseIdent('alse');
                SerdeError.invalidType(Unexpected.bool(false), expected);
            case '-'.code:
                eatChar();
                SerdeError.invalidType(describe(parseInteger(false)), expected);
            case c if (c >= '0'.code && c <= '9'.code):
                SerdeError.invalidType(describe(parseInteger(true)), expected);
            case '"'.code:
                eatChar();
                SerdeError.invalidType(Unexpected.str(parseStr()), expected);
            case '['.code:
                SerdeError.invalidType(Unexpected.SEQ, expected);
            case '{'.code:
                SerdeError.invalidType(Unexpected.MAP, expected);
            case _:
                return peekError(EXPECTED_SOME_VALUE);
        }
        return fixPosition(err);
    }

    public static function describe(number:ParserNumber):String {
        return switch number {
            case F64(v): Unexpected.float(v);
            case U64(v): Unexpected.unsigned(v);
            case I64(v): Unexpected.signed(v);
        }
    }

    /** `deserialize_number`: a number, or the error of another type. */
    public function parseNumberValue(expected:String):ParserNumber {
        final peek = parseWhitespace();
        if (peek == -1) {
            throw peekError(EOF_WHILE_PARSING_VALUE);
        }
        if (peek == '-'.code) {
            eatChar();
            return parseInteger(false);
        }
        if (peek >= '0'.code && peek <= '9'.code) {
            return parseInteger(true);
        }
        throw peekInvalidType(expected);
    }

    static inline function overflows(significand:Float, digit:Int):Bool {
        // u64::MAX = 18446744073709551615
        return significand >= 1844674407370955161.0 && (significand > 1844674407370955161.0 || digit > 5);
    }

    public function parseInteger(positive:Bool):ParserNumber {
        final next = next();
        if (next == -1) {
            throw error(EOF_WHILE_PARSING_VALUE);
        }
        if (next == '0'.code) {
            // There can be only one leading '0'.
            final c = peekOrNull();
            if (c >= '0'.code && c <= '9'.code) {
                throw peekError(INVALID_NUMBER);
            }
            return parseNumber(positive, 0);
        }
        if (next >= '1'.code && next <= '9'.code) {
            var significand:Float = next - '0'.code;
            while (true) {
                final c = peekOrNull();
                if (c >= '0'.code && c <= '9'.code) {
                    final digit = c - '0'.code;
                    if (overflows(significand, digit)) {
                        return F64(parseLongInteger(positive, significand));
                    }
                    eatChar();
                    significand = significand * 10 + digit;
                }
                else {
                    return parseNumber(positive, significand);
                }
            }
        }
        throw error(INVALID_NUMBER);
    }

    function parseLongInteger(positive:Bool, significand:Float):Float {
        var exponent = 0;
        while (true) {
            final c = peekOrNull();
            if (c >= '0'.code && c <= '9'.code) {
                eatChar();
                // This could overflow... if your integer is gigabytes long.
                // Ignore that possibility.
                exponent++;
            }
            else if (c == '.'.code) {
                return parseDecimal(positive, significand, exponent);
            }
            else if (c == 'e'.code || c == 'E'.code) {
                return parseExponent(positive, significand, exponent);
            }
            else {
                return f64FromParts(positive, significand, exponent);
            }
        }
    }

    function parseNumber(positive:Bool, significand:Float):ParserNumber {
        final c = peekOrNull();
        if (c == '.'.code) return F64(parseDecimal(positive, significand, 0));
        if (c == 'e'.code || c == 'E'.code) return F64(parseExponent(positive, significand, 0));
        if (positive) return U64(significand);
        // Convert into a float on `-0`.
        if (significand == 0) return F64(-0.0);
        return I64(-significand);
    }

    function parseDecimal(positive:Bool, significand:Float, exponentBeforeDecimalPoint:Int):Float {
        eatChar();

        var exponentAfterDecimalPoint = 0;
        while (true) {
            final c = peekOrNull();
            if (!(c >= '0'.code && c <= '9'.code)) break;
            final digit = c - '0'.code;
            if (overflows(significand, digit)) {
                final exponent = exponentBeforeDecimalPoint + exponentAfterDecimalPoint;
                return parseDecimalOverflow(positive, significand, exponent);
            }
            eatChar();
            significand = significand * 10 + digit;
            exponentAfterDecimalPoint -= 1;
        }

        // Error if there is not at least one digit after the decimal point.
        if (exponentAfterDecimalPoint == 0) {
            if (peek() != -1) {
                throw peekError(INVALID_NUMBER);
            }
            throw peekError(EOF_WHILE_PARSING_VALUE);
        }

        final exponent = exponentBeforeDecimalPoint + exponentAfterDecimalPoint;
        final c = peekOrNull();
        if (c == 'e'.code || c == 'E'.code) {
            return parseExponent(positive, significand, exponent);
        }
        return f64FromParts(positive, significand, exponent);
    }

    function parseDecimalOverflow(positive:Bool, significand:Float, exponent:Int):Float {
        // The next multiply/add would overflow, so just ignore all further
        // digits.
        while (true) {
            final c = peekOrNull();
            if (!(c >= '0'.code && c <= '9'.code)) break;
            eatChar();
        }
        final c = peekOrNull();
        if (c == 'e'.code || c == 'E'.code) {
            return parseExponent(positive, significand, exponent);
        }
        return f64FromParts(positive, significand, exponent);
    }

    function parseExponent(positive:Bool, significand:Float, startingExp:Int):Float {
        eatChar();

        var positiveExp = true;
        switch peekOrNull() {
            case '+'.code:
                eatChar();
            case '-'.code:
                eatChar();
                positiveExp = false;
            case _:
        }

        final next = next();
        if (next == -1) {
            throw error(EOF_WHILE_PARSING_VALUE);
        }
        // Make sure a digit follows the exponent place.
        if (!(next >= '0'.code && next <= '9'.code)) {
            throw error(INVALID_NUMBER);
        }
        var exp:Float = next - '0'.code;
        while (true) {
            final c = peekOrNull();
            if (!(c >= '0'.code && c <= '9'.code)) break;
            eatChar();
            final digit = c - '0'.code;
            if (exp >= 214748364 && (exp > 214748364 || digit > 7)) {
                final zeroSignificand = significand == 0;
                return parseExponentOverflow(positive, zeroSignificand, positiveExp);
            }
            exp = exp * 10 + digit;
        }

        var finalExp:Float = positiveExp ? startingExp + exp : startingExp - exp;
        if (finalExp > 2147483647) finalExp = 2147483647;
        if (finalExp < -2147483648) finalExp = -2147483648;
        return f64FromParts(positive, significand, Std.int(finalExp));
    }

    function parseExponentOverflow(positive:Bool, zeroSignificand:Bool, positiveExp:Bool):Float {
        // Error instead of +/- infinity.
        if (!zeroSignificand && positiveExp) {
            throw error(NUMBER_OUT_OF_RANGE);
        }
        while (true) {
            final c = peekOrNull();
            if (!(c >= '0'.code && c <= '9'.code)) break;
            eatChar();
        }
        return positive ? 0.0 : -0.0;
    }

    function f64FromParts(positive:Bool, significand:Float, exponent:Int):Float {
        var f = significand;
        while (true) {
            final abs = exponent < 0 ? -exponent : exponent;
            if (abs < POW10.length) {
                final pow = POW10[abs];
                if (exponent >= 0) {
                    f *= pow;
                    if (!Math.isFinite(f)) {
                        throw error(NUMBER_OUT_OF_RANGE);
                    }
                }
                else {
                    f /= pow;
                }
                break;
            }
            if (f == 0.0) {
                break;
            }
            if (exponent >= 0) {
                throw error(NUMBER_OUT_OF_RANGE);
            }
            f /= 1e308;
            exponent += 308;
        }
        return positive ? f : -f;
    }

    static function isEscape(c:Int):Bool {
        return c == '"'.code || c == '\\'.code || c < 0x20;
    }

    function skipToEscape():Void {
        while (index < slice.length && !isEscape(slice.get(index))) {
            index++;
        }
    }

    /** Parses a string after its opening quote (`parse_str`). */
    public function parseStr():String {
        final scratch = new haxe.io.BytesBuffer();
        var start = index;
        while (true) {
            skipToEscape();
            if (index == slice.length) {
                throw error(EOF_WHILE_PARSING_STRING);
            }
            switch slice.get(index) {
                case '"'.code:
                    scratch.addBytes(slice, start, index - start);
                    index++;
                    return scratch.getBytes().toString();
                case '\\'.code:
                    scratch.addBytes(slice, start, index - start);
                    index++;
                    parseEscape(scratch);
                    start = index;
                case _:
                    index++;
                    throw error(CONTROL_CHARACTER_WHILE_PARSING_STRING);
            }
        }
    }

    /** Skips a string after its opening quote (`ignore_str`). */
    public function ignoreStr():Void {
        while (true) {
            skipToEscape();
            if (index == slice.length) {
                throw error(EOF_WHILE_PARSING_STRING);
            }
            switch slice.get(index) {
                case '"'.code:
                    index++;
                    return;
                case '\\'.code:
                    index++;
                    ignoreEscape();
                case _:
                    throw error(CONTROL_CHARACTER_WHILE_PARSING_STRING);
            }
        }
    }

    function nextOrEof():Int {
        final c = next();
        if (c == -1) {
            throw error(EOF_WHILE_PARSING_STRING);
        }
        return c;
    }

    function peekOrEof():Int {
        final c = peek();
        if (c == -1) {
            throw error(EOF_WHILE_PARSING_STRING);
        }
        return c;
    }

    function parseEscape(scratch:haxe.io.BytesBuffer):Void {
        final ch = nextOrEof();
        switch ch {
            case '"'.code: scratch.addByte('"'.code);
            case '\\'.code: scratch.addByte('\\'.code);
            case '/'.code: scratch.addByte('/'.code);
            case 'b'.code: scratch.addByte(0x08);
            case 'f'.code: scratch.addByte(0x0c);
            case 'n'.code: scratch.addByte('\n'.code);
            case 'r'.code: scratch.addByte('\r'.code);
            case 't'.code: scratch.addByte('\t'.code);
            case 'u'.code: parseUnicodeEscape(scratch);
            case _: throw error(INVALID_ESCAPE);
        }
    }

    function ignoreEscape():Void {
        final ch = nextOrEof();
        switch ch {
            case '"'.code | '\\'.code | '/'.code | 'b'.code | 'f'.code | 'n'.code | 'r'.code | 't'.code:
            case 'u'.code:
                // At this point we don't care if the codepoint is valid. We just
                // want to consume it. We don't actually know what is valid or not
                // at this point, because that depends on if this string will
                // ultimately be parsed into a string or a byte buffer in the "real"
                // parse.
                decodeHexEscape();
            case _:
                throw error(INVALID_ESCAPE);
        }
    }

    static function hexValue(c:Int):Int {
        if (c >= '0'.code && c <= '9'.code) return c - '0'.code;
        if (c >= 'a'.code && c <= 'f'.code) return c - 'a'.code + 10;
        if (c >= 'A'.code && c <= 'F'.code) return c - 'A'.code + 10;
        return -1;
    }

    function decodeHexEscape():Int {
        if (index + 4 > slice.length) {
            index = slice.length;
            throw error(EOF_WHILE_PARSING_STRING);
        }
        var value = 0;
        var valid = true;
        for (i in 0...4) {
            final digit = hexValue(slice.get(index + i));
            if (digit < 0) valid = false;
            value = (value << 4) | (digit & 0xf);
        }
        index += 4;
        if (!valid) {
            throw error(INVALID_ESCAPE);
        }
        return value;
    }

    static function pushCodePoint(scratch:haxe.io.BytesBuffer, c:Int):Void {
        if (c < 0x80) {
            scratch.addByte(c);
        }
        else if (c < 0x800) {
            scratch.addByte(0xc0 | (c >> 6));
            scratch.addByte(0x80 | (c & 0x3f));
        }
        else if (c < 0x10000) {
            scratch.addByte(0xe0 | (c >> 12));
            scratch.addByte(0x80 | ((c >> 6) & 0x3f));
            scratch.addByte(0x80 | (c & 0x3f));
        }
        else {
            scratch.addByte(0xf0 | (c >> 18));
            scratch.addByte(0x80 | ((c >> 12) & 0x3f));
            scratch.addByte(0x80 | ((c >> 6) & 0x3f));
            scratch.addByte(0x80 | (c & 0x3f));
        }
    }

    function parseUnicodeEscape(scratch:haxe.io.BytesBuffer):Void {
        var n = decodeHexEscape();

        // Strings must have paired surrogates (deserializing a `String`).
        if (n >= 0xDC00 && n <= 0xDFFF) {
            // XXX: This is actually a trailing surrogate.
            throw error(LONE_LEADING_SURROGATE_IN_HEX_ESCAPE);
        }

        while (true) {
            if (n < 0xD800 || n > 0xDBFF) {
                pushCodePoint(scratch, n);
                return;
            }

            // n is a leading surrogate, we now expect a trailing surrogate.
            final n1 = n;

            if (peekOrEof() == '\\'.code) {
                eatChar();
            }
            else {
                eatChar();
                throw error(UNEXPECTED_END_OF_HEX_ESCAPE);
            }

            if (peekOrEof() == 'u'.code) {
                eatChar();
            }
            else {
                eatChar();
                throw error(UNEXPECTED_END_OF_HEX_ESCAPE);
            }

            final n2 = decodeHexEscape();

            if (n2 < 0xDC00 || n2 > 0xDFFF) {
                throw error(LONE_LEADING_SURROGATE_IN_HEX_ESCAPE);
            }

            pushCodePoint(scratch, (((n1 - 0xD800) << 10) | (n2 - 0xDC00)) + 0x10000);
            return;
        }
    }

    public function parseObjectColon():Void {
        final c = parseWhitespace();
        if (c == ':'.code) {
            eatChar();
            return;
        }
        if (c == -1) throw peekError(EOF_WHILE_PARSING_OBJECT);
        throw peekError(EXPECTED_COLON);
    }

    public function endSeq():Void {
        switch parseWhitespace() {
            case ']'.code:
                eatChar();
            case ','.code:
                eatChar();
                if (parseWhitespace() == ']'.code) {
                    throw peekError(TRAILING_COMMA);
                }
                throw peekError(TRAILING_CHARACTERS);
            case -1:
                throw peekError(EOF_WHILE_PARSING_LIST);
            case _:
                throw peekError(TRAILING_CHARACTERS);
        }
    }

    public function endMap():Void {
        switch parseWhitespace() {
            case '}'.code:
                eatChar();
            case ','.code:
                throw peekError(TRAILING_COMMA);
            case -1:
                throw peekError(EOF_WHILE_PARSING_OBJECT);
            case _:
                throw peekError(TRAILING_CHARACTERS);
        }
    }

    /** `Deserializer::end`: only whitespace may follow the value. */
    public function end():Void {
        if (parseWhitespace() != -1) {
            throw peekError(TRAILING_CHARACTERS);
        }
    }

    /** Skips any value (`deserialize_ignored_any`). */
    public function ignoreValue():Void {
        final scratch:Array<Int> = [];
        var enclosing:Int = -1;

        while (true) {
            final peek = parseWhitespace();
            if (peek == -1) {
                throw peekError(EOF_WHILE_PARSING_VALUE);
            }

            var frame = -1;
            switch peek {
                case 'n'.code:
                    eatChar();
                    parseIdent('ull');
                case 't'.code:
                    eatChar();
                    parseIdent('rue');
                case 'f'.code:
                    eatChar();
                    parseIdent('alse');
                case '-'.code:
                    eatChar();
                    ignoreInteger();
                case c if (c >= '0'.code && c <= '9'.code):
                    ignoreInteger();
                case '"'.code:
                    eatChar();
                    ignoreStr();
                case '['.code | '{'.code:
                    if (enclosing != -1) scratch.push(enclosing);
                    enclosing = -1;
                    eatChar();
                    frame = peek;
                case _:
                    throw peekError(EXPECTED_SOME_VALUE);
            }

            var acceptComma:Bool;
            if (frame != -1) {
                acceptComma = false;
            }
            else if (enclosing != -1) {
                frame = enclosing;
                enclosing = -1;
                acceptComma = true;
            }
            else if (scratch.length > 0) {
                frame = scratch.pop();
                acceptComma = true;
            }
            else {
                return;
            }

            while (true) {
                final c = parseWhitespace();
                if (c == ','.code && acceptComma) {
                    eatChar();
                    break;
                }
                else if ((c == ']'.code && frame == '['.code) || (c == '}'.code && frame == '{'.code)) {
                    // closes the frame below
                }
                else if (c != -1) {
                    if (acceptComma) {
                        throw peekError(frame == '['.code ? EXPECTED_LIST_COMMA_OR_END : EXPECTED_OBJECT_COMMA_OR_END);
                    }
                    else {
                        break;
                    }
                }
                else {
                    throw peekError(frame == '['.code ? EOF_WHILE_PARSING_LIST : EOF_WHILE_PARSING_OBJECT);
                }

                eatChar();
                if (scratch.length == 0) {
                    return;
                }
                frame = scratch.pop();
                acceptComma = true;
            }

            if (frame == '{'.code) {
                final c = parseWhitespace();
                if (c == '"'.code) {
                    eatChar();
                }
                else if (c != -1) {
                    throw peekError(KEY_MUST_BE_A_STRING);
                }
                else {
                    throw peekError(EOF_WHILE_PARSING_OBJECT);
                }
                ignoreStr();
                final colon = parseWhitespace();
                if (colon == ':'.code) {
                    eatChar();
                }
                else if (colon != -1) {
                    throw peekError(EXPECTED_COLON);
                }
                else {
                    throw peekError(EOF_WHILE_PARSING_OBJECT);
                }
            }

            enclosing = frame;
        }
    }

    function ignoreInteger():Void {
        final c = nextOrNull();
        if (c == '0'.code) {
            // There can be only one leading '0'.
            final p = peekOrNull();
            if (p >= '0'.code && p <= '9'.code) {
                throw peekError(INVALID_NUMBER);
            }
        }
        else if (c >= '1'.code && c <= '9'.code) {
            while (true) {
                final p = peekOrNull();
                if (!(p >= '0'.code && p <= '9'.code)) break;
                eatChar();
            }
        }
        else {
            throw error(INVALID_NUMBER);
        }

        final p = peekOrNull();
        if (p == '.'.code) {
            ignoreDecimal();
        }
        else if (p == 'e'.code || p == 'E'.code) {
            ignoreExponent();
        }
    }

    function ignoreDecimal():Void {
        eatChar();
        var atLeastOneDigit = false;
        while (true) {
            final p = peekOrNull();
            if (!(p >= '0'.code && p <= '9'.code)) break;
            eatChar();
            atLeastOneDigit = true;
        }
        if (!atLeastOneDigit) {
            throw peekError(INVALID_NUMBER);
        }
        final p = peekOrNull();
        if (p == 'e'.code || p == 'E'.code) {
            ignoreExponent();
        }
    }

    function ignoreExponent():Void {
        eatChar();
        final p = peekOrNull();
        if (p == '+'.code || p == '-'.code) eatChar();
        // Make sure a digit follows the exponent place.
        final c = nextOrNull();
        if (!(c >= '0'.code && c <= '9'.code)) {
            throw error(INVALID_NUMBER);
        }
        while (true) {
            final d = peekOrNull();
            if (!(d >= '0'.code && d <= '9'.code)) break;
            eatChar();
        }
    }

}
