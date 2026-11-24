// New code for the Haxe port of gpui-kit (no Rust origin). See NOTICE.md.
package glaze.kit.input;

/**
 * Computes the text of a number field that accepts expressions
 * (`NumberInput.expressions`): numbers, `+`, `-`, `*`, `/` and parentheses,
 * with the usual priorities. `136+8` is 144, `1/3` is 0.333..., `-(2+3)*4`
 * is -20.
 */
class NumberExpression {

    /**
     * The value of `text`, or null when it is not an expression (an empty
     * text, a letter, a parenthesis that is not closed, a division by zero).
     */
    public static function evaluate(text:String):Null<Float> {
        final parser = new NumberExpression(text);
        parser.skipSpaces();
        if (parser.atEnd()) return null;
        final value = parser.sum();
        parser.skipSpaces();
        if (parser.failed || !parser.atEnd() || Math.isNaN(value) || !Math.isFinite(value)) return null;
        return value;
    }

    final text:String;

    var at:Int = 0;

    var failed:Bool = false;

    function new(text:String) {
        this.text = text;
    }

    inline function atEnd():Bool {
        return at >= text.length;
    }

    function skipSpaces():Void {
        while (at < text.length && StringTools.isSpace(text, at)) at++;
    }

    /** The character at the cursor after spaces, or an empty string at the end. */
    function peek():String {
        skipSpaces();
        return at < text.length ? text.charAt(at) : '';
    }

    function sum():Float {
        var value = product();
        while (!failed) {
            final symbol = peek();
            if (symbol == '+') {
                at++;
                value += product();
            } else if (symbol == '-') {
                at++;
                value -= product();
            } else {
                break;
            }
        }
        return value;
    }

    function product():Float {
        var value = unary();
        while (!failed) {
            final symbol = peek();
            if (symbol == '*') {
                at++;
                value *= unary();
            } else if (symbol == '/') {
                at++;
                final divisor = unary();
                if (divisor == 0) failed = true;
                else value /= divisor;
            } else {
                break;
            }
        }
        return value;
    }

    function unary():Float {
        final symbol = peek();
        if (symbol == '-') {
            at++;
            return -unary();
        }
        if (symbol == '+') {
            at++;
            return unary();
        }
        return term();
    }

    function term():Float {
        final symbol = peek();
        if (symbol == '(') {
            at++;
            final value = sum();
            if (peek() != ')') failed = true;
            else at++;
            return value;
        }
        final start = at;
        var digits = 0;
        var dots = 0;
        while (at < text.length) {
            final code = text.charCodeAt(at);
            if (code >= '0'.code && code <= '9'.code) digits++;
            else if (code == '.'.code) dots++;
            else break;
            at++;
        }
        if (digits == 0 || dots > 1) {
            failed = true;
            return 0;
        }
        return Std.parseFloat(text.substring(start, at));
    }

}
