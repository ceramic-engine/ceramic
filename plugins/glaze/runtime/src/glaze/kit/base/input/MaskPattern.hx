// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mask_pattern.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-018 (a comma is a decimal separator in a number mask). See DEVIATIONS.md.
package glaze.kit.base.input;

/**
 * One slot of a mask pattern. Chars are code points.
 */
@:using(glaze.kit.base.input.MaskPattern.MaskTokenTools)
enum MaskToken {
    /** Digit, equivalent to `[0-9]` */
    Digit;
    /** Letter, equivalent to `[a-zA-Z]` */
    Letter;
    /** Letter or digit, equivalent to `[a-zA-Z0-9]` */
    LetterOrDigit;
    /** Separator */
    Sep(c:Int);
    /** Any character */
    Any;
}

class MaskTokenTools {

    /** Check if the token is any character. */
    public static function isAny(self:MaskToken):Bool {
        return self.match(Any);
    }

    /**
     * Check if the token is a match for the given character. A separator
     * only matches itself.
     */
    public static function isMatch(self:MaskToken, ch:Int):Bool {
        return switch self {
            case Digit: isAsciiDigit(ch);
            case Letter: isAsciiAlphabetic(ch);
            case LetterOrDigit: isAsciiDigit(ch) || isAsciiAlphabetic(ch);
            case Any: true;
            case Sep(c): c == ch;
        }
    }

    /** Is the token a separator (can be ignored). */
    public static function isSep(self:MaskToken):Bool {
        return self.match(Sep(_));
    }

    /** Check if the token is a number. */
    public static function isNumber(self:MaskToken):Bool {
        return self.match(Digit);
    }

    public static function placeholder(self:MaskToken):Int {
        return switch self {
            case Sep(c): c;
            case _: '_'.code;
        }
    }

    public static function maskChar(self:MaskToken, ch:Int):Int {
        return switch self {
            case Digit | LetterOrDigit | Letter: ch;
            case Sep(c): c;
            case Any: ch;
        }
    }

    /** The original char, or -1 (Rust `None`) for a separator. */
    public static function unmaskChar(self:MaskToken, ch:Int):Int {
        return switch self {
            case Digit: ch;
            case Letter: ch;
            case LetterOrDigit: ch;
            case Any: ch;
            case _: -1;
        }
    }

    public static function equals(self:MaskToken, other:MaskToken):Bool {
        return Type.enumEq(self, other);
    }

    public static inline function isAsciiDigit(ch:Int):Bool {
        return ch >= '0'.code && ch <= '9'.code;
    }

    public static inline function isAsciiAlphabetic(ch:Int):Bool {
        return (ch >= 'a'.code && ch <= 'z'.code) || (ch >= 'A'.code && ch <= 'Z'.code);
    }

}

/**
 * How an input formats and validates its text. `None` is the default.
 *
 * Build a pattern with `MaskPatternTools.create("(999)999-9999")` (Rust
 * `MaskPattern::new`, or `From<&str>`), a number with
 * `MaskPatternTools.number(','.code)`.
 */
@:using(glaze.kit.base.input.MaskPattern.MaskPatternTools)
enum MaskPattern {
    None;
    Pattern(pattern:String, tokens:Array<MaskToken>);
    /**
     * `separator`: group separator, e.g. "," or " " (a code point, or null);
     * `fraction`: number of fraction digits, e.g. 2 for 123.45 (or null).
     */
    Number(separator:Null<Int>, fraction:Null<Int>);
}

class MaskPatternTools {

    /**
     * Create a new mask pattern.
     *
     * - `9`: Digit
     * - `A`: Letter
     * - `#`: Letter or Digit
     * - `*`: Any character
     * - other characters: Separator
     *
     * For example: `(999)999-9999` (US phone number: (123)456-7890),
     * `99999-9999` (ZIP code), `AAAA-99-####`, `*999*` ((123) or [123]).
     */
    public static function create(pattern:String):MaskPattern {
        final tokens = [for (ch in chars(pattern)) switch ch {
            case '9'.code: MaskToken.Digit;
            case 'A'.code: MaskToken.Letter;
            case '#'.code: MaskToken.LetterOrDigit;
            case '*'.code: MaskToken.Any;
            case _: MaskToken.Sep(ch);
        }];

        return Pattern(pattern, tokens);
    }

    public static function tokens(self:MaskPattern):Null<Array<MaskToken>> {
        return switch self {
            case Pattern(_, tokens): tokens;
            case Number(_, _): null;
            case None: null;
        }
    }

    /** Create a new number mask with a group separator, e.g. "," or " ". */
    public static function number(sep:Null<Int>):MaskPattern {
        return Number(sep, null);
    }

    public static function placeholder(self:MaskPattern):Null<String> {
        return switch self {
            case Pattern(_, tokens):
                final buf = new StringBuf();
                for (token in tokens) buf.addChar(token.placeholder());
                buf.toString();
            case Number(_, _): null;
            case None: null;
        }
    }

    /** Return true if the mask pattern is None or has no pattern. */
    public static function isNone(self:MaskPattern):Bool {
        return switch self {
            case Pattern(_, tokens): tokens.length == 0;
            case Number(_, _): false;
            case None: true;
        }
    }

    /**
     * Check if the mask text is valid. Always true when the mask pattern is
     * None.
     */
    public static function isValid(self:MaskPattern, maskText:String):Bool {
        if (isNone(self)) {
            return true;
        }

        var textIndex = 0;
        final maskTextChars = chars(maskText);
        switch self {
            case Pattern(_, tokens):
                for (token in tokens) {
                    if (textIndex >= maskTextChars.length) {
                        break;
                    }

                    final ch = maskTextChars[textIndex];
                    if (token.isMatch(ch)) {
                        textIndex += 1;
                    }
                }
                return textIndex == maskTextChars.length;
            case Number(separator, _):
                if (maskText.length == 0) {
                    return true;
                }

                // Modified for ceramic-gpui (DEV-018): a comma is a decimal
                // separator, unless the mask groups digits with it.
                final maskText = commaIsDecimal(separator) ? StringTools.replace(maskText, ',', '.') : maskText;

                // check if the text is valid number
                final parts = maskText.split('.');
                final intPart = parts[0];
                final fracPart = parts.length > 1 ? parts[1] : null;

                // only one dot is valid
                if (parts.length > 2) {
                    return false;
                }

                final intChars = chars(intPart);
                final signPositions = [for (i in 0...intChars.length) if (isSign(intChars[i])) i];

                // only one sign is valid
                // sign is only valid at the beginning of the string
                if (signPositions.length > 1 || (signPositions.length > 0 && signPositions[0] > 0)) {
                    return false;
                }

                // check if the integer part is valid
                for (i in 0...intChars.length) {
                    final ch = intChars[i];
                    if (!(MaskTokenTools.isAsciiDigit(ch) || isSign(ch) && i == 0 || (separator != null && ch == separator))) {
                        return false;
                    }
                }

                // check if the fraction part is valid
                if (fracPart != null) {
                    for (ch in chars(fracPart)) {
                        if (!(MaskTokenTools.isAsciiDigit(ch) || (separator != null && ch == separator))) {
                            return false;
                        }
                    }
                }

                return true;
            case None:
                return true;
        }
    }

    /** Check if `ch` is a valid input char at the given position. */
    public static function isValidAt(self:MaskPattern, ch:Int, pos:Int):Bool {
        if (isNone(self)) {
            return true;
        }

        switch self {
            case Pattern(_, tokens):
                if (pos >= 0 && pos < tokens.length) {
                    final token = tokens[pos];
                    if (token.isMatch(ch)) {
                        return true;
                    }

                    if (token.isSep()) {
                        // If next token is match, it's valid
                        if (pos + 1 < tokens.length) {
                            final nextToken = tokens[pos + 1];
                            if (nextToken.isMatch(ch)) {
                                return true;
                            }
                        }
                    }
                }

                return false;
            case Number(_, _):
                return true;
            case None:
                return true;
        }
    }

    /**
     * Format the text according to the mask pattern. For example, with the
     * pattern `(999)999-999`, `123456789` becomes `(123)456-789`.
     */
    public static function mask(self:MaskPattern, text:String):String {
        if (isNone(self)) {
            return text;
        }

        switch self {
            case Number(separator, fraction):
                // Modified for ceramic-gpui (DEV-018): a comma typed or pasted
                // as the decimal separator becomes a dot.
                final text = commaIsDecimal(separator) ? StringTools.replace(text, ',', '.') : text;
                if (separator != null) {
                    final sep:Int = separator;
                    // Remove the existing group separator
                    final text = StringTools.replace(text, String.fromCharCode(sep), '');

                    final parts = text.split('.');
                    final intPart = parts[0];

                    // Limit the fraction part to the given range
                    final fracPart:Null<String> = if (parts.length > 1) {
                        final fracChars = chars(parts[1]);
                        final take = fraction != null ? fraction : fracChars.length;
                        final buf = new StringBuf();
                        for (i in 0...(take < fracChars.length ? take : fracChars.length)) buf.addChar(fracChars[i]);
                        buf.toString();
                    }
                    else null;

                    // Reverse the integer part for easier grouping
                    final intChars = chars(intPart);
                    intChars.reverse();

                    // Removing the sign from formatting to avoid cases such as: -,123
                    var maybeSigned:Null<Int> = null;
                    for (i in 0...intChars.length) {
                        if (isSign(intChars[i])) {
                            maybeSigned = intChars[i];
                            intChars.splice(i, 1);
                            break;
                        }
                    }

                    final result:Array<Int> = [];
                    for (i in 0...intChars.length) {
                        if (i > 0 && i % 3 == 0) {
                            result.push(sep);
                        }
                        result.push(intChars[i]);
                    }
                    result.reverse();
                    final intWithSep = fromChars(result);

                    var finalStr = if (fracPart != null) {
                        if (fraction == 0) {
                            intWithSep;
                        }
                        else {
                            intWithSep + '.' + fracPart;
                        }
                    }
                    else {
                        intWithSep;
                    }

                    if (maybeSigned != null) {
                        finalStr = String.fromCharCode(maybeSigned) + finalStr;
                    }

                    return finalStr;
                }

                return text;
            case Pattern(_, tokens):
                final result = new StringBuf();
                var textIndex = 0;
                final textChars = chars(text);
                for (pos in 0...tokens.length) {
                    final token = tokens[pos];
                    if (textIndex >= textChars.length) {
                        break;
                    }
                    final ch = textChars[textIndex];
                    // Break if expected char is not match
                    if (!token.isSep() && !isValidAt(self, ch, pos)) {
                        break;
                    }
                    final maskCh = token.maskChar(ch);
                    result.addChar(maskCh);
                    if (ch == maskCh) {
                        textIndex += 1;
                        continue;
                    }
                }
                return result.toString();
            case None:
                return text;
        }
    }

    /** Extract the original text from masked text. */
    public static function unmask(self:MaskPattern, maskText:String):String {
        switch self {
            case Number(separator, _):
                if (separator != null) {
                    final buf = new StringBuf();
                    for (ch in chars(maskText)) {
                        if (ch == separator) {
                            continue;
                        }
                        buf.addChar(ch);
                    }

                    var result = buf.toString();
                    if (result.indexOf('.') != -1) {
                        var end = result.length;
                        while (end > 0 && StringTools.fastCodeAt(result, end - 1) == '0'.code) end--;
                        result = result.substr(0, end);
                    }
                    return result;
                }

                return maskText;
            case Pattern(_, tokens):
                final result = new StringBuf();
                final maskTextChars = chars(maskText);
                for (textIndex in 0...tokens.length) {
                    final token = tokens[textIndex];
                    if (textIndex >= maskTextChars.length) {
                        break;
                    }
                    final ch = maskTextChars[textIndex];
                    final unmaskCh = token.unmaskChar(ch);
                    if (unmaskCh != -1) {
                        result.addChar(unmaskCh);
                    }
                }
                return result.toString();
            case None:
                return maskText;
        }
    }

    /**
     * Normalize full-width and CJK number characters into their ASCII
     * equivalents, e.g. `１２３。５` to `123.5`.
     *
     * Every mapping is 1 char to 1 char with the same UTF-16 length, so the
     * IME marked-range offsets (in UTF-16) stay valid. The UTF-8 byte length
     * may shrink (3 bytes to 1): the caller must use the normalized string for
     * all byte-offset calculations. Returns `text` itself when nothing changes
     * (Rust `Cow::Borrowed`).
     */
    public static function normalizeNumberInput(text:String):String {
        var changed = false;
        final textChars = chars(text);
        for (ch in textChars) {
            if (normalizeChar(ch) != -1) {
                changed = true;
                break;
            }
        }

        if (!changed) {
            return text;
        }

        final buf = new StringBuf();
        for (ch in textChars) {
            final normalized = normalizeChar(ch);
            buf.addChar(normalized != -1 ? normalized : ch);
        }
        return buf.toString();
    }

    static function normalizeChar(ch:Int):Int {
        // Full-width digits 0-9
        if (ch >= 0xFF10 && ch <= 0xFF19) return ch - 0xFF10 + '0'.code;
        return switch ch {
            // Full-width plus
            case 0xFF0B: '+'.code;
            // Full-width hyphen and minus sign
            case 0xFF0D | 0x2212: '-'.code;
            // Full-width dot and ideographic full stop
            case 0xFF0E | 0x3002: '.'.code;
            // Full-width comma
            case 0xFF0C: ','.code;
            case _: -1;
        }
    }

    static inline function isSign(ch:Int):Bool {
        return ch == '+'.code || ch == '-'.code;
    }

    /**
     * Deliberate deviation DEV-018: whether a number mask takes a comma as the
     * decimal separator (the one software keypads show in regions that write
     * decimals with a comma). Not when the mask groups digits with a comma (or
     * a dot), where the comma keeps its meaning of group separator.
     */
    public static function commaIsDecimal(separator:Null<Int>):Bool {
        return separator != ','.code && separator != '.'.code;
    }

    /** The code points of a string (Rust `str::chars`). */
    @:allow(glaze.kit.base.input)
    static function chars(s:String):Array<Int> {
        return [for (c in new haxe.iterators.StringIteratorUnicode(s)) c];
    }

    static function fromChars(chars:Array<Int>):String {
        final buf = new StringBuf();
        for (c in chars) buf.addChar(c);
        return buf.toString();
    }

}
