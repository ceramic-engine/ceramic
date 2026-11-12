// Ported from vscode src/vs/platform/contextkey/common/contextkey.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.contextkey.common;

import cityscape.base.common.CharCode;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Platform;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.platform.contextkey.common.Scanner;

enum abstract ContextKeyExprType(Int) from Int to Int {
    var False = 0;
    var True = 1;
    var Defined = 2;
    var Not = 3;
    var Equals = 4;
    var NotEquals = 5;
    var And = 6;
    var Regex = 7;
    var NotRegex = 8;
    var Or = 9;
    var In = 10;
    var NotIn = 11;
    var Greater = 12;
    var GreaterEquals = 13;
    var Smaller = 14;
    var SmallerEquals = 15;
}

interface IContextKeyExprMapper {
    function mapDefined(key:String):ContextKeyExpression;
    function mapNot(key:String):ContextKeyExpression;
    function mapEquals(key:String, value:Any):ContextKeyExpression;
    function mapNotEquals(key:String, value:Any):ContextKeyExpression;
    function mapGreater(key:String, value:Any):ContextKeyExpression;
    function mapGreaterEquals(key:String, value:Any):ContextKeyExpression;
    function mapSmaller(key:String, value:Any):ContextKeyExpression;
    function mapSmallerEquals(key:String, value:Any):ContextKeyExpression;
    function mapRegex(key:String, regexp:Null<RegExp>):ContextKeyRegexExpr;
    function mapIn(key:String, valueKey:String):ContextKeyInExpr;
    function mapNotIn(key:String, valueKey:String):ContextKeyNotInExpr;
}

/**
 * The values a context key can hold (Monaco's `ContextKeyValue`: null,
 * booleans, numbers, strings, arrays of those, records of those).
 */
typedef ContextKeyValue = Any;

/**
 * Monaco's `IContext`.
 */
interface IContext {
    function getValue(key:String):Any;
}

/**
 * Monaco's `IContextKey<T>`.
 */
interface IContextKey<T> {
    function set(value:T):Void;
    function reset():Void;
    function get():Null<T>;
}

interface IReadableSet<T> {
    function has(value:T):Bool;
}

interface IContextKeyChangeEvent {
    function affectsSome(keys:IReadableSet<String>):Bool;
    function allKeysContainedIn(keys:IReadableSet<String>):Bool;
}

/**
 * Monaco's `IContextKeyService`. There is no DOM: a scoped service is
 * created from its parent (`createScoped(null)`) and the context of a scope
 * is read from the service itself (`getContext(null)`).
 */
interface IContextKeyService {
    var onDidChangeContext(get, never):Event<IContextKeyChangeEvent>;
    function bufferChangeEvents(callback:() -> Void):Void;

    function createKey<T>(key:String, defaultValue:Null<T>):IContextKey<T>;
    function contextMatchesRules(rules:Null<ContextKeyExpression>):Bool;
    function getContextKeyValue<T>(key:String):Null<T>;

    function createScoped(target:Any):IScopedContextKeyService;
    function createOverlay(overlay:Array<{key:String, value:Any}>):IContextKeyService;
    function getContext(target:Any):IContext;

    function updateParent(parentContextKeyService:IContextKeyService):Void;
}

/**
 * Monaco's `IScopedContextKeyService` (`IContextKeyService & IDisposable`).
 */
interface IScopedContextKeyService extends IContextKeyService extends IDisposable {
}

typedef ParserConfig = {
    /**
     * with this option enabled, the parser can recover from regex parsing errors, e.g., unescaped slashes: `/src//` is accepted as `/src\//` would be
     */
    var regexParsingWithErrorRecovery:Bool;
}

typedef ParsingError = {
    var message:String;
    var offset:Int;
    var lexeme:String;
    @:optional var additionalInfo:Null<String>;
}

private class ParseError extends haxe.Exception {}

/**
 * The module values of contextkey.ts: the constants (`isMac`...), the
 * comparison helpers, `implies`, `validateWhenClauses`,
 * `expressionsAreEqualWithConstantSubstitution`.
 */
class ContextKeyUtils {

    static var _customConstantsMap:Null<Map<String, Bool>> = null;
    static var _customConstants(get, never):Map<String, Bool>;
    static function get__customConstants():Map<String, Bool> {
        if (_customConstantsMap == null) {
            _customConstantsMap = new Map();
        }
        return _customConstantsMap;
    }

    /**
     * Monaco's `CONSTANT_VALUES.get(key)`: the platform constants are read
     * from `Platform` when asked (tests change the platform), the other
     * ones were registered with `setConstant`.
     */
    public static function getConstant(key:String):Null<Bool> {
        switch (key) {
            case 'false':
                return false;
            case 'true':
                return true;
            case 'isMac':
                return Platform.isMacintosh;
            case 'isLinux':
                return Platform.isLinux;
            case 'isWindows':
                return Platform.isWindows;
            case 'isWeb':
                return Platform.isWeb;
            case 'isMacNative':
                return Platform.isMacintosh && !Platform.isWeb;
            case 'isEdge' | 'isFirefox' | 'isChrome' | 'isSafari':
                return BrowserDetection.is(key);
            case _:
                return _customConstants.get(key);
        }
    }

    /** allow register constant context keys that are known only after startup; requires running `substituteConstants` on the context key - https://github.com/microsoft/vscode/issues/174218#issuecomment-1437972127 */
    public static function setConstant(key:String, value:Bool):Void {
        if (getConstant(key) != null) {
            throw 'Illegal argument: contextkey.setConstant(k, v) invoked with already set constant `k`';
        }
        _customConstants.set(key, value);
    }

    public static function validateWhenClauses(whenClauses:Array<String>):Array<Array<{errorMessage:String, offset:Int, length:Int}>> {

        final parser = new Parser({regexParsingWithErrorRecovery: false}); // we run with no recovery to guide users to use correct regexes

        return [for (whenClause in whenClauses) {
            parser.parse(whenClause);

            if (parser.lexingErrors.length > 0) {
                [for (se in parser.lexingErrors) {
                    errorMessage: se.additionalInfo != null ? 'Unexpected token. Hint: ' + se.additionalInfo : 'Unexpected token.',
                    offset: se.offset,
                    length: se.lexeme.length,
                }];
            }
            else if (parser.parsingErrors.length > 0) {
                [for (pe in parser.parsingErrors) {
                    errorMessage: pe.additionalInfo != null ? pe.message + '. ' + pe.additionalInfo : pe.message,
                    offset: pe.offset,
                    length: pe.lexeme.length,
                }];
            }
            else {
                [];
            }
        }];
    }

    public static function expressionsAreEqualWithConstantSubstitution(a:Null<ContextKeyExpression>, b:Null<ContextKeyExpression>):Bool {
        final aExpr = a != null ? a.substituteConstants() : null;
        final bExpr = b != null ? b.substituteConstants() : null;
        if (aExpr == null && bExpr == null) {
            return true;
        }
        if (aExpr == null || bExpr == null) {
            return false;
        }
        return aExpr.equals(bExpr);
    }

    @:allow(cityscape.platform.contextkey.common)
    static function cmp(a:ContextKeyExpression, b:ContextKeyExpression):Int {
        return a.cmp(b);
    }

    @:allow(cityscape.platform.contextkey.common)
    static function cmp1(key1:String, key2:String):Int {
        if (key1 < key2) {
            return -1;
        }
        if (key1 > key2) {
            return 1;
        }
        return 0;
    }

    @:allow(cityscape.platform.contextkey.common)
    static function cmp2(key1:String, value1:Any, key2:String, value2:Any):Int {
        if (key1 < key2) {
            return -1;
        }
        if (key1 > key2) {
            return 1;
        }
        if (JsCompare.lessThan(value1, value2)) {
            return -1;
        }
        if (JsCompare.lessThan(value2, value1)) {
            return 1;
        }
        return 0;
    }

    /**
     * Returns true if it is provable `p` implies `q`.
     */
    public static function implies(p:ContextKeyExpression, q:ContextKeyExpression):Bool {

        if (p.type == ContextKeyExprType.False || q.type == ContextKeyExprType.True) {
            // false implies anything
            // anything implies true
            return true;
        }

        if (p.type == ContextKeyExprType.Or) {
            if (q.type == ContextKeyExprType.Or) {
                // `a || b || c` can only imply something like `a || b || c || d`
                return allElementsIncluded((cast p : ContextKeyOrExpr).expr, (cast q : ContextKeyOrExpr).expr);
            }
            return false;
        }

        if (q.type == ContextKeyExprType.Or) {
            for (element in (cast q : ContextKeyOrExpr).expr) {
                if (implies(p, element)) {
                    return true;
                }
            }
            return false;
        }

        if (p.type == ContextKeyExprType.And) {
            if (q.type == ContextKeyExprType.And) {
                // `a && b && c` implies `a && c`
                return allElementsIncluded((cast q : ContextKeyAndExpr).expr, (cast p : ContextKeyAndExpr).expr);
            }
            for (element in (cast p : ContextKeyAndExpr).expr) {
                if (implies(element, q)) {
                    return true;
                }
            }
            return false;
        }

        return p.equals(q);
    }

    /**
     * Returns true if all elements in `p` are also present in `q`.
     * The two arrays are assumed to be sorted
     */
    static function allElementsIncluded(p:Array<ContextKeyExpression>, q:Array<ContextKeyExpression>):Bool {
        var pIndex = 0;
        var qIndex = 0;
        while (pIndex < p.length && qIndex < q.length) {
            final cmp = p[pIndex].cmp(q[qIndex]);

            if (cmp < 0) {
                // an element from `p` is missing from `q`
                return false;
            }
            else if (cmp == 0) {
                pIndex++;
                qIndex++;
            }
            else {
                qIndex++;
            }
        }
        return (pIndex == p.length);
    }

    @:allow(cityscape.platform.contextkey.common)
    static function getTerminals(node:ContextKeyExpression):Array<ContextKeyExpression> {
        if (node.type == ContextKeyExprType.Or) {
            return (cast node : ContextKeyOrExpr).expr;
        }
        return [node];
    }

    /**
     * @returns the same instance if nothing changed.
     */
    @:allow(cityscape.platform.contextkey.common)
    static function eliminateConstantsInArray(arr:Array<ContextKeyExpression>):Array<Null<ContextKeyExpression>> {
        // Allocate array only if there is a difference
        var newArr:Null<Array<Null<ContextKeyExpression>>> = null;
        for (i in 0...arr.length) {
            final newExpr = arr[i].substituteConstants();

            if (arr[i] != newExpr) {
                // something has changed!

                // allocate array on first difference
                if (newArr == null) {
                    newArr = [];
                    for (j in 0...i) {
                        newArr[j] = arr[j];
                    }
                }
            }

            if (newArr != null) {
                newArr[i] = newExpr;
            }
        }

        if (newArr == null) {
            return cast arr;
        }
        return newArr;
    }

}

/**
 * JavaScript's loose comparisons on context key values (`==`, `<`), which
 * Monaco's expressions use on purpose.
 */
class JsCompare {

    /**
     * `Number(value)` for primitives.
     */
    public static function toNumber(value:Any):Float {
        if (value == null) {
            return 0;
        }
        if (JsValues.isNumber(value)) {
            return (value : Float);
        }
        if (JsValues.isBoolean(value)) {
            return (value : Bool) ? 1 : 0;
        }
        if (JsValues.isString(value)) {
            final s = StringTools.trim((value : String));
            if (s.length == 0) {
                return 0;
            }
            if (s == 'Infinity' || s == '+Infinity') {
                return Math.POSITIVE_INFINITY;
            }
            if (s == '-Infinity') {
                return Math.NEGATIVE_INFINITY;
            }
            // the whole string must be the number
            return isDecimalLiteral(s) ? JsValues.parseFloat(s) : Math.NaN;
        }
        return toNumber(JsValues.toJsString(value));
    }

    static function isDecimalLiteral(s:String):Bool {
        var i = 0;
        final len = s.length;
        if (i < len && (s.charAt(i) == '+' || s.charAt(i) == '-')) {
            i++;
        }
        var digits = 0;
        while (i < len && s.charCodeAt(i) >= '0'.code && s.charCodeAt(i) <= '9'.code) {
            i++;
            digits++;
        }
        if (i < len && s.charAt(i) == '.') {
            i++;
            while (i < len && s.charCodeAt(i) >= '0'.code && s.charCodeAt(i) <= '9'.code) {
                i++;
                digits++;
            }
        }
        if (digits == 0) {
            return false;
        }
        if (i < len && (s.charAt(i) == 'e' || s.charAt(i) == 'E')) {
            i++;
            if (i < len && (s.charAt(i) == '+' || s.charAt(i) == '-')) {
                i++;
            }
            var exp = 0;
            while (i < len && s.charCodeAt(i) >= '0'.code && s.charCodeAt(i) <= '9'.code) {
                i++;
                exp++;
            }
            if (exp == 0) {
                return false;
            }
        }
        return i == len;
    }

    static function isPrimitive(value:Any):Bool {
        return value == null || JsValues.isNumber(value) || JsValues.isString(value) || JsValues.isBoolean(value);
    }

    /**
     * `a === b` for primitives (and identity for objects).
     */
    public static function strictEquals(a:Any, b:Any):Bool {
        if (a == null || b == null) {
            return a == null && b == null;
        }
        if (JsValues.isNumber(a) && JsValues.isNumber(b)) {
            return (a : Float) == (b : Float);
        }
        if (JsValues.isString(a) && JsValues.isString(b)) {
            return (a : String) == (b : String);
        }
        if (JsValues.isBoolean(a) && JsValues.isBoolean(b)) {
            return (a : Bool) == (b : Bool);
        }
        if (isPrimitive(a) || isPrimitive(b)) {
            return false;
        }
        return a == b;
    }

    /**
     * `a == b` (JavaScript's loose equality; `undefined` and `null` are one
     * value here).
     */
    public static function looseEquals(a:Any, b:Any):Bool {
        if (a == null || b == null) {
            return a == null && b == null;
        }
        final aPrimitive = isPrimitive(a);
        final bPrimitive = isPrimitive(b);
        if (!aPrimitive && !bPrimitive) {
            return a == b;
        }
        if (!aPrimitive) {
            return looseEquals(JsValues.toJsString(a), b);
        }
        if (!bPrimitive) {
            return looseEquals(a, JsValues.toJsString(b));
        }
        if (JsValues.isString(a) && JsValues.isString(b)) {
            return (a : String) == (b : String);
        }
        if (JsValues.isBoolean(a) && JsValues.isBoolean(b)) {
            return (a : Bool) == (b : Bool);
        }
        // number comparisons (NaN is never equal)
        final x = toNumber(a);
        final y = toNumber(b);
        return !Math.isNaN(x) && !Math.isNaN(y) && x == y;
    }

    /**
     * `a < b` on primitives: strings compare as strings, anything else as
     * numbers (false with NaN).
     */
    public static function lessThan(a:Any, b:Any):Bool {
        if (JsValues.isString(a) && JsValues.isString(b)) {
            return (a : String) < (b : String);
        }
        final x = toNumber(isPrimitive(a) ? a : JsValues.toJsString(a));
        final y = toNumber(isPrimitive(b) ? b : JsValues.toJsString(b));
        if (Math.isNaN(x) || Math.isNaN(y)) {
            return false;
        }
        return x < y;
    }

}

/**
 * platform.ts `isEdge`, `isFirefox`, `isChrome`, `isSafari`: from the user
 * agent in a browser, false elsewhere.
 */
private class BrowserDetection {

    public static function is(key:String):Bool {
        #if (js && web)
        final nav:Dynamic = js.Syntax.code('(typeof navigator === "object" ? navigator : null)');
        if (nav == null || nav.userAgent == null) {
            return false;
        }
        final userAgent:String = nav.userAgent;
        return switch (key) {
            case 'isEdge': userAgent.indexOf('Edg/') >= 0;
            case 'isFirefox': userAgent.indexOf('Firefox') >= 0;
            case 'isChrome': userAgent.indexOf('Chrome') >= 0;
            case 'isSafari': userAgent.indexOf('Chrome') < 0 && userAgent.indexOf('Safari') >= 0;
            case _: false;
        };
        #else
        return false;
        #end
    }

}

/**
 * A parser for context key expressions.
 *
 * Example:
 * ```haxe
 * final parser = new Parser();
 * final expr = parser.parse('foo == "bar" && baz == true');
 *
 * if (expr == null) {
 *     // there were lexing or parsing errors
 *     // process lexing errors with `parser.lexingErrors`
 *     // process parsing errors with `parser.parsingErrors`
 * } else {
 *     // expr is a valid expression
 * }
 * ```
 *
 * The error messages are Monaco's English texts.
 */
class Parser {
    // Note: this doesn't produce an exact syntax tree but a normalized one
    // ContextKeyExpression's that we use as AST nodes do not expose constructors that do not normalize

    static inline final errorEmptyString = "Empty context key expression";
    static inline final hintEmptyString = "Did you forget to write an expression? You can also put 'false' or 'true' to always evaluate to false or true, respectively.";
    static inline final errorNoInAfterNot = "'in' after 'not'.";
    static inline final errorClosingParenthesis = "closing parenthesis ')'";
    static inline final errorUnexpectedToken = "Unexpected token";
    static inline final hintUnexpectedToken = "Did you forget to put && or || before the token?";
    static inline final errorUnexpectedEOF = "Unexpected end of expression";
    static inline final hintUnexpectedEOF = "Did you forget to put a context key?";


    // lifetime note: `_scanner` lives as long as the parser does, i.e., is not reset between calls to `parse`
    final _scanner = new Scanner();

    // lifetime note: `_tokens`, `_current`, and `_parsingErrors` must be reset between calls to `parse`
    var _tokens:Array<Token> = [];
    var _current = 0; // invariant: 0 <= this._current < this._tokens.length ; any incrementation of this value must first call `_isAtEnd`
    var _parsingErrors:Array<ParsingError> = [];

    final _config:ParserConfig;

    public var lexingErrors(get, never):Array<LexingError>;
    function get_lexingErrors():Array<LexingError> {
        return this._scanner.errors;
    }

    public var parsingErrors(get, never):Array<ParsingError>;
    function get_parsingErrors():Array<ParsingError> {
        return this._parsingErrors;
    }

    public function new(?config:ParserConfig) {
        this._config = config != null ? config : {regexParsingWithErrorRecovery: true};
    }

    /**
     * Parse a context key expression.
     *
     * @param input the expression to parse
     * @returns the parsed expression or `null` if there's an error - call `lexingErrors` and `parsingErrors` to see the errors
     */
    public function parse(input:String):Null<ContextKeyExpression> {

        if (input == '') {
            this._parsingErrors.push({message: errorEmptyString, offset: 0, lexeme: '', additionalInfo: hintEmptyString});
            return null;
        }

        this._tokens = this._scanner.reset(input).scan();
        // @ulugbekna: we do not stop parsing if there are lexing errors to be able to reconstruct regexes with unescaped slashes; TODO@ulugbekna: make this respect config option for recovery

        this._current = 0;
        this._parsingErrors = [];

        try {
            final expr = this._expr();
            if (!this._isAtEnd()) {
                final peek = this._peek();
                final additionalInfo = peek.type == TokenType.Str ? hintUnexpectedToken : null;
                this._parsingErrors.push({message: errorUnexpectedToken, offset: peek.offset, lexeme: Scanner.getLexeme(peek), additionalInfo: additionalInfo});
                throw new ParseError('');
            }
            return expr;
        }
        catch (e:ParseError) {
            return null;
        }
    }

    function _expr():Null<ContextKeyExpression> {
        return this._or();
    }

    function _or():Null<ContextKeyExpression> {
        final expr = [this._and()];

        while (this._matchOne(TokenType.Or)) {
            final right = this._and();
            expr.push(right);
        }

        return expr.length == 1 ? expr[0] : ContextKeyExpr.orArray(expr);
    }

    function _and():Null<ContextKeyExpression> {
        final expr = [this._term()];

        while (this._matchOne(TokenType.And)) {
            final right = this._term();
            expr.push(right);
        }

        return expr.length == 1 ? expr[0] : ContextKeyExpr.andArray(expr);
    }

    function _term():Null<ContextKeyExpression> {
        if (this._matchOne(TokenType.Neg)) {
            final peek = this._peek();
            switch (peek.type) {
                case TokenType.True:
                    this._advance();
                    return ContextKeyFalseExpr.INSTANCE;
                case TokenType.False:
                    this._advance();
                    return ContextKeyTrueExpr.INSTANCE;
                case TokenType.LParen:
                    this._advance();
                    final expr = this._expr();
                    this._consume(TokenType.RParen, errorClosingParenthesis);
                    return expr != null ? expr.negate() : null;
                case TokenType.Str:
                    this._advance();
                    return ContextKeyNotExpr.create(peek.lexeme);
                default:
                    throw this._errExpectedButGot("KEY | true | false | '(' expression ')'", peek);
            }
        }
        return this._primary();
    }

    function newRegExp(source:String, flags:Null<String>, token:Token):RegExp {
        try {
            return new RegExp(source, flags != null ? flags : '');
        }
        catch (e:Dynamic) {
            throw this._errExpectedButGot('REGEX', token);
        }
    }

    function _primary():Null<ContextKeyExpression> {

        final peek = this._peek();
        switch (peek.type) {
            case TokenType.True:
                this._advance();
                return ContextKeyExpr.trueExpr();

            case TokenType.False:
                this._advance();
                return ContextKeyExpr.falseExpr();

            case TokenType.LParen:
                this._advance();
                final expr = this._expr();
                this._consume(TokenType.RParen, errorClosingParenthesis);
                return expr;

            case TokenType.Str:
                // KEY
                final key = peek.lexeme;
                this._advance();

                // =~ regex
                if (this._matchOne(TokenType.RegexOp)) {

                    // @ulugbekna: we need to reconstruct the regex from the tokens because some extensions use unescaped slashes in regexes
                    final expr = this._peek();

                    if (!this._config.regexParsingWithErrorRecovery) {
                        this._advance();
                        if (expr.type != TokenType.RegexStr) {
                            throw this._errExpectedButGot('REGEX', expr);
                        }
                        final regexLexeme = expr.lexeme;
                        final closingSlashIndex = regexLexeme.lastIndexOf('/');
                        final flags = closingSlashIndex == regexLexeme.length - 1 ? null : this._removeFlagsGY(regexLexeme.substring(closingSlashIndex + 1));
                        final regexp = newRegExp(regexLexeme.substring(1, closingSlashIndex), flags, expr);
                        return ContextKeyRegexExpr.create(key, regexp);
                    }

                    switch (expr.type) {
                        case TokenType.RegexStr | TokenType.Error: // also handle an ErrorToken in case of smth such as /(/file)/
                            final lexemeReconstruction = [expr.lexeme]; // /REGEX/ or /REGEX/FLAGS
                            this._advance();

                            var followingToken = this._peek();
                            var parenBalance = 0;
                            for (i in 0...expr.lexeme.length) {
                                if (StringTools.fastCodeAt(expr.lexeme, i) == CharCode.OpenParen) {
                                    parenBalance++;
                                }
                                else if (StringTools.fastCodeAt(expr.lexeme, i) == CharCode.CloseParen) {
                                    parenBalance--;
                                }
                            }

                            while (!this._isAtEnd() && followingToken.type != TokenType.And && followingToken.type != TokenType.Or) {
                                switch (followingToken.type) {
                                    case TokenType.LParen:
                                        parenBalance++;
                                    case TokenType.RParen:
                                        parenBalance--;
                                    case TokenType.RegexStr | TokenType.QuotedStr:
                                        for (i in 0...followingToken.lexeme.length) {
                                            if (StringTools.fastCodeAt(followingToken.lexeme, i) == CharCode.OpenParen) {
                                                parenBalance++;
                                            }
                                            else if (i < expr.lexeme.length && StringTools.fastCodeAt(expr.lexeme, i) == CharCode.CloseParen) {
                                                parenBalance--;
                                            }
                                        }
                                    case _:
                                }
                                if (parenBalance < 0) {
                                    break;
                                }
                                lexemeReconstruction.push(Scanner.getLexeme(followingToken));
                                this._advance();
                                followingToken = this._peek();
                            }

                            final regexLexeme = lexemeReconstruction.join('');
                            final closingSlashIndex = regexLexeme.lastIndexOf('/');
                            final flags = closingSlashIndex == regexLexeme.length - 1 ? null : this._removeFlagsGY(regexLexeme.substring(closingSlashIndex + 1));
                            final regexp = newRegExp(regexLexeme.substring(1, closingSlashIndex), flags, expr);
                            return ContextKeyExpr.regex(key, regexp);

                        case TokenType.QuotedStr:
                            final serializedValue = expr.lexeme;
                            this._advance();
                            // replicate old regex parsing behavior

                            var regex:Null<RegExp> = null;

                            if (!Strings.isFalsyOrWhitespace(serializedValue)) {
                                final start = serializedValue.indexOf('/');
                                final end = serializedValue.lastIndexOf('/');
                                if (start != end && start >= 0) {

                                    final value = serializedValue.substring(start + 1, end);
                                    final caseIgnoreFlag = serializedValue.charAt(end + 1) == 'i' ? 'i' : '';
                                    regex = newRegExp(value, caseIgnoreFlag, expr);
                                }
                            }

                            if (regex == null) {
                                throw this._errExpectedButGot('REGEX', expr);
                            }

                            return ContextKeyRegexExpr.create(key, regex);

                        default:
                            throw this._errExpectedButGot('REGEX', this._peek());
                    }
                }

                // [ 'not' 'in' value ]
                if (this._matchOne(TokenType.Not)) {
                    this._consume(TokenType.In, errorNoInAfterNot);
                    final right = this._value();
                    return ContextKeyExpr.notIn(key, right);
                }

                // [ ('==' | '!=' | '<' | '<=' | '>' | '>=' | 'in') value ]
                final maybeOp = this._peek().type;
                switch (maybeOp) {
                    case TokenType.Eq:
                        this._advance();

                        final right = this._value();
                        if (this._previous().type == TokenType.QuotedStr) { // to preserve old parser behavior: "foo == 'true'" is preserved as "foo == 'true'", but "foo == true" is optimized as "foo"
                            return ContextKeyExpr.equals(key, right);
                        }
                        switch (right) {
                            case 'true':
                                return ContextKeyExpr.has(key);
                            case 'false':
                                return ContextKeyExpr.not(key);
                            default:
                                return ContextKeyExpr.equals(key, right);
                        }

                    case TokenType.NotEq:
                        this._advance();

                        final right = this._value();
                        if (this._previous().type == TokenType.QuotedStr) { // same as above with "foo != 'true'"
                            return ContextKeyExpr.notEquals(key, right);
                        }
                        switch (right) {
                            case 'true':
                                return ContextKeyExpr.not(key);
                            case 'false':
                                return ContextKeyExpr.has(key);
                            default:
                                return ContextKeyExpr.notEquals(key, right);
                        }
                    // TODO: ContextKeyExpr.smaller(key, right) accepts only `number` as `right` AND during eval of this node, we just eval to `false` if `right` is not a number
                    // consequently, package.json linter should _warn_ the user if they're passing undesired things to ops
                    case TokenType.Lt:
                        this._advance();
                        return ContextKeySmallerExpr.create(key, this._value());

                    case TokenType.LtEq:
                        this._advance();
                        return ContextKeySmallerEqualsExpr.create(key, this._value());

                    case TokenType.Gt:
                        this._advance();
                        return ContextKeyGreaterExpr.create(key, this._value());

                    case TokenType.GtEq:
                        this._advance();
                        return ContextKeyGreaterEqualsExpr.create(key, this._value());

                    case TokenType.In:
                        this._advance();
                        return ContextKeyExpr.inExpr(key, this._value());

                    default:
                        return ContextKeyExpr.has(key);
                }

            case TokenType.EOF:
                this._parsingErrors.push({message: errorUnexpectedEOF, offset: peek.offset, lexeme: '', additionalInfo: hintUnexpectedEOF});
                throw new ParseError('');

            default:
                throw this._errExpectedButGot("true | false | KEY \n\t| KEY '=~' REGEX \n\t| KEY ('==' | '!=' | '<' | '<=' | '>' | '>=' | 'in' | 'not' 'in') value", this._peek());

        }
    }

    function _value():String {
        final token = this._peek();
        switch (token.type) {
            case TokenType.Str | TokenType.QuotedStr:
                this._advance();
                return token.lexeme;
            case TokenType.True:
                this._advance();
                return 'true';
            case TokenType.False:
                this._advance();
                return 'false';
            case TokenType.In: // we support `in` as a value, e.g., "when": "languageId == in" - exists in existing extensions
                this._advance();
                return 'in';
            default:
                // this allows "when": "foo == " which's used by existing extensions
                // we do not call `_advance` on purpose - we don't want to eat unintended tokens
                return '';
        }
    }

    function _removeFlagsGY(flags:String):String {
        return StringTools.replace(StringTools.replace(flags, 'g', ''), 'y', '');
    }

    // careful: this can throw if current token is the initial one (ie index = 0)
    function _previous():Token {
        return this._tokens[this._current - 1];
    }

    function _matchOne(token:TokenType):Bool {
        if (this._check(token)) {
            this._advance();
            return true;
        }

        return false;
    }

    function _advance():Token {
        if (!this._isAtEnd()) {
            this._current++;
        }
        return this._previous();
    }

    function _consume(type:TokenType, message:String):Token {
        if (this._check(type)) {
            return this._advance();
        }

        throw this._errExpectedButGot(message, this._peek());
    }

    function _errExpectedButGot(expected:String, got:Token, ?additionalInfo:String):ParseError {
        final message = 'Expected: ' + expected + '\nReceived: \'' + Scanner.getLexeme(got) + '\'.';
        final offset = got.offset;
        final lexeme = Scanner.getLexeme(got);
        this._parsingErrors.push({message: message, offset: offset, lexeme: lexeme, additionalInfo: additionalInfo});
        return new ParseError('');
    }

    function _check(type:TokenType):Bool {
        return this._peek().type == type;
    }

    function _peek():Token {
        return this._tokens[this._current];
    }

    function _isAtEnd():Bool {
        return this._peek().type == TokenType.EOF;
    }
}

/**
 * The factory of context key expressions. Haxe keywords are renamed:
 * `false()` is `falseExpr()`, `true()` is `trueExpr()`, `in` is `inExpr`;
 * `and` and `or` take any number of arguments like Monaco's rest parameters
 * (`andArray`, `orArray` take an array).
 */
class ContextKeyExpr {

    public static function falseExpr():ContextKeyExpression {
        return ContextKeyFalseExpr.INSTANCE;
    }

    public static function trueExpr():ContextKeyExpression {
        return ContextKeyTrueExpr.INSTANCE;
    }

    public static function has(key:String):ContextKeyExpression {
        return ContextKeyDefinedExpr.create(key);
    }

    public static function equals(key:String, value:Any):ContextKeyExpression {
        return ContextKeyEqualsExpr.create(key, value);
    }

    public static function notEquals(key:String, value:Any):ContextKeyExpression {
        return ContextKeyNotEqualsExpr.create(key, value);
    }

    public static function regex(key:String, value:RegExp):ContextKeyExpression {
        return ContextKeyRegexExpr.create(key, value);
    }

    public static function inExpr(key:String, value:String):ContextKeyExpression {
        return ContextKeyInExpr.create(key, value);
    }

    public static function notIn(key:String, value:String):ContextKeyExpression {
        return ContextKeyNotInExpr.create(key, value);
    }

    public static function not(key:String):ContextKeyExpression {
        return ContextKeyNotExpr.create(key);
    }

    public static function and(...expr:Null<ContextKeyExpression>):Null<ContextKeyExpression> {
        // A typed copy: `Rest.toArray()` of a `Null<T>` is not an `Array<Null<T>>` on C#
        final list:Array<Null<ContextKeyExpression>> = [for (e in expr) e];
        return ContextKeyAndExpr.create(list, null, true);
    }

    public static function andArray(expr:Array<Null<ContextKeyExpression>>):Null<ContextKeyExpression> {
        return ContextKeyAndExpr.create(expr, null, true);
    }

    public static function or(...expr:Null<ContextKeyExpression>):Null<ContextKeyExpression> {
        final list:Array<Null<ContextKeyExpression>> = [for (e in expr) e];
        return ContextKeyOrExpr.create(list, null, true);
    }

    public static function orArray(expr:Array<Null<ContextKeyExpression>>):Null<ContextKeyExpression> {
        return ContextKeyOrExpr.create(expr, null, true);
    }

    public static function greater(key:String, value:Float):ContextKeyExpression {
        return ContextKeyGreaterExpr.create(key, value);
    }

    public static function greaterEquals(key:String, value:Float):ContextKeyExpression {
        return ContextKeyGreaterEqualsExpr.create(key, value);
    }

    public static function smaller(key:String, value:Float):ContextKeyExpression {
        return ContextKeySmallerExpr.create(key, value);
    }

    public static function smallerEquals(key:String, value:Float):ContextKeyExpression {
        return ContextKeySmallerEqualsExpr.create(key, value);
    }

    static var _parser:Null<Parser> = null;

    public static function deserialize(serialized:Null<String>):Null<ContextKeyExpression> {
        if (serialized == null) { // an empty string needs to be handled by the parser to get a corresponding parsing error reported
            return null;
        }
        if (_parser == null) {
            _parser = new Parser({regexParsingWithErrorRecovery: false});
        }
        final expr = _parser.parse(serialized);
        return expr;
    }

}

/**
 * A context key expression (Monaco's `ContextKeyExpression` union and its
 * `IContextKeyExpression` interface).
 */
abstract class ContextKeyExpression {

    public final type:ContextKeyExprType;

    function new(type:ContextKeyExprType) {
        this.type = type;
    }

    abstract public function cmp(other:ContextKeyExpression):Int;
    abstract public function equals(other:ContextKeyExpression):Bool;
    abstract public function substituteConstants():Null<ContextKeyExpression>;
    abstract public function evaluate(context:IContext):Bool;
    abstract public function serialize():String;
    abstract public function keys():Array<String>;
    abstract public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression;
    abstract public function negate():ContextKeyExpression;

}

class ContextKeyFalseExpr extends ContextKeyExpression {
    static var _instance:Null<ContextKeyFalseExpr> = null;
    public static var INSTANCE(get, never):ContextKeyFalseExpr;
    static function get_INSTANCE():ContextKeyFalseExpr {
        if (_instance == null) {
            _instance = new ContextKeyFalseExpr();
        }
        return _instance;
    }

    function new() {
        super(ContextKeyExprType.False);
    }

    public function cmp(other:ContextKeyExpression):Int {
        return this.type - other.type;
    }

    public function equals(other:ContextKeyExpression):Bool {
        return (other.type == this.type);
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        return this;
    }

    public function evaluate(context:IContext):Bool {
        return false;
    }

    public function serialize():String {
        return 'false';
    }

    public function keys():Array<String> {
        return [];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return this;
    }

    public function negate():ContextKeyExpression {
        return ContextKeyTrueExpr.INSTANCE;
    }
}

class ContextKeyTrueExpr extends ContextKeyExpression {
    static var _instance:Null<ContextKeyTrueExpr> = null;
    public static var INSTANCE(get, never):ContextKeyTrueExpr;
    static function get_INSTANCE():ContextKeyTrueExpr {
        if (_instance == null) {
            _instance = new ContextKeyTrueExpr();
        }
        return _instance;
    }

    function new() {
        super(ContextKeyExprType.True);
    }

    public function cmp(other:ContextKeyExpression):Int {
        return this.type - other.type;
    }

    public function equals(other:ContextKeyExpression):Bool {
        return (other.type == this.type);
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        return this;
    }

    public function evaluate(context:IContext):Bool {
        return true;
    }

    public function serialize():String {
        return 'true';
    }

    public function keys():Array<String> {
        return [];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return this;
    }

    public function negate():ContextKeyExpression {
        return ContextKeyFalseExpr.INSTANCE;
    }
}

class ContextKeyDefinedExpr extends ContextKeyExpression {
    public static function create(key:String, ?negated:ContextKeyExpression):ContextKeyExpression {
        final constantValue = ContextKeyUtils.getConstant(key);
        if (constantValue != null) {
            return constantValue ? ContextKeyTrueExpr.INSTANCE : ContextKeyFalseExpr.INSTANCE;
        }
        return new ContextKeyDefinedExpr(key, negated);
    }

    public final key:String;
    var negated:Null<ContextKeyExpression>;

    function new(key:String, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.Defined);
        this.key = key;
        this.negated = negated;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        return ContextKeyUtils.cmp1(this.key, (cast other : ContextKeyDefinedExpr).key);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            return (this.key == (cast other : ContextKeyDefinedExpr).key);
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        final constantValue = ContextKeyUtils.getConstant(this.key);
        if (constantValue != null) {
            return constantValue ? ContextKeyTrueExpr.INSTANCE : ContextKeyFalseExpr.INSTANCE;
        }
        return this;
    }

    public function evaluate(context:IContext):Bool {
        return JsValues.truthy(context.getValue(this.key));
    }

    public function serialize():String {
        return this.key;
    }

    public function keys():Array<String> {
        return [this.key];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapDefined(this.key);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyNotExpr.create(this.key, this);
        }
        return this.negated;
    }
}

class ContextKeyEqualsExpr extends ContextKeyExpression {

    public static function create(key:String, value:Any, ?negated:ContextKeyExpression):ContextKeyExpression {
        if (JsValues.isBoolean(value)) {
            return ((value : Bool) ? ContextKeyDefinedExpr.create(key, negated) : ContextKeyNotExpr.create(key, negated));
        }
        final constantValue = ContextKeyUtils.getConstant(key);
        if (constantValue != null) {
            final trueValue = constantValue ? 'true' : 'false';
            return (JsCompare.strictEquals(value, trueValue) ? ContextKeyTrueExpr.INSTANCE : ContextKeyFalseExpr.INSTANCE);
        }
        return new ContextKeyEqualsExpr(key, value, negated);
    }

    final key:String;
    final value:Any;
    var negated:Null<ContextKeyExpression>;

    function new(key:String, value:Any, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.Equals);
        this.key = key;
        this.value = value;
        this.negated = negated;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        final o:ContextKeyEqualsExpr = cast other;
        return ContextKeyUtils.cmp2(this.key, this.value, o.key, o.value);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            final o:ContextKeyEqualsExpr = cast other;
            return (this.key == o.key && JsCompare.strictEquals(this.value, o.value));
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        final constantValue = ContextKeyUtils.getConstant(this.key);
        if (constantValue != null) {
            final trueValue = constantValue ? 'true' : 'false';
            return (JsCompare.strictEquals(this.value, trueValue) ? ContextKeyTrueExpr.INSTANCE : ContextKeyFalseExpr.INSTANCE);
        }
        return this;
    }

    public function evaluate(context:IContext):Bool {
        // Intentional ==
        return JsCompare.looseEquals(context.getValue(this.key), this.value);
    }

    public function serialize():String {
        return this.key + ' == \'' + JsValues.toJsString(this.value) + '\'';
    }

    public function keys():Array<String> {
        return [this.key];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapEquals(this.key, this.value);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyNotEqualsExpr.create(this.key, this.value, this);
        }
        return this.negated;
    }
}

class ContextKeyInExpr extends ContextKeyExpression {

    public static function create(key:String, valueKey:String):ContextKeyInExpr {
        return new ContextKeyInExpr(key, valueKey);
    }

    var negated:Null<ContextKeyExpression> = null;
    final key:String;
    final valueKey:String;

    function new(key:String, valueKey:String) {
        super(ContextKeyExprType.In);
        this.key = key;
        this.valueKey = valueKey;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        final o:ContextKeyInExpr = cast other;
        return ContextKeyUtils.cmp2(this.key, this.valueKey, o.key, o.valueKey);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            final o:ContextKeyInExpr = cast other;
            return (this.key == o.key && this.valueKey == o.valueKey);
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        return this;
    }

    public function evaluate(context:IContext):Bool {
        final source = context.getValue(this.valueKey);

        final item = context.getValue(this.key);

        if (JsValues.isArray(source)) {
            final array:Array<Any> = source;
            for (element in array) {
                if (JsCompare.strictEquals(element, item)) {
                    return true;
                }
            }
            return false;
        }

        if (JsValues.isString(item) && source != null && JsValues.isObject(source)) {
            if (Std.isOfType(source, haxe.ds.StringMap)) {
                return (cast source : haxe.ds.StringMap<Any>).exists(item);
            }
            return Reflect.hasField(source, item);
        }
        return false;
    }

    public function serialize():String {
        return this.key + ' in \'' + this.valueKey + '\'';
    }

    public function keys():Array<String> {
        return [this.key, this.valueKey];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapIn(this.key, this.valueKey);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyNotInExpr.create(this.key, this.valueKey);
        }
        return this.negated;
    }
}

class ContextKeyNotInExpr extends ContextKeyExpression {

    public static function create(key:String, valueKey:String):ContextKeyNotInExpr {
        return new ContextKeyNotInExpr(key, valueKey);
    }

    final _negated:ContextKeyInExpr;
    final key:String;
    final valueKey:String;

    function new(key:String, valueKey:String) {
        super(ContextKeyExprType.NotIn);
        this.key = key;
        this.valueKey = valueKey;
        this._negated = ContextKeyInExpr.create(key, valueKey);
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        return this._negated.cmp((cast other : ContextKeyNotInExpr)._negated);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            return this._negated.equals((cast other : ContextKeyNotInExpr)._negated);
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        return this;
    }

    public function evaluate(context:IContext):Bool {
        return !this._negated.evaluate(context);
    }

    public function serialize():String {
        return this.key + ' not in \'' + this.valueKey + '\'';
    }

    public function keys():Array<String> {
        return this._negated.keys();
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapNotIn(this.key, this.valueKey);
    }

    public function negate():ContextKeyExpression {
        return this._negated;
    }
}

class ContextKeyNotEqualsExpr extends ContextKeyExpression {

    public static function create(key:String, value:Any, ?negated:ContextKeyExpression):ContextKeyExpression {
        if (JsValues.isBoolean(value)) {
            if ((value : Bool)) {
                return ContextKeyNotExpr.create(key, negated);
            }
            return ContextKeyDefinedExpr.create(key, negated);
        }
        final constantValue = ContextKeyUtils.getConstant(key);
        if (constantValue != null) {
            final falseValue = constantValue ? 'true' : 'false';
            return (JsCompare.strictEquals(value, falseValue) ? ContextKeyFalseExpr.INSTANCE : ContextKeyTrueExpr.INSTANCE);
        }
        return new ContextKeyNotEqualsExpr(key, value, negated);
    }

    final key:String;
    final value:Any;
    var negated:Null<ContextKeyExpression>;

    function new(key:String, value:Any, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.NotEquals);
        this.key = key;
        this.value = value;
        this.negated = negated;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        final o:ContextKeyNotEqualsExpr = cast other;
        return ContextKeyUtils.cmp2(this.key, this.value, o.key, o.value);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            final o:ContextKeyNotEqualsExpr = cast other;
            return (this.key == o.key && JsCompare.strictEquals(this.value, o.value));
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        final constantValue = ContextKeyUtils.getConstant(this.key);
        if (constantValue != null) {
            final falseValue = constantValue ? 'true' : 'false';
            return (JsCompare.strictEquals(this.value, falseValue) ? ContextKeyFalseExpr.INSTANCE : ContextKeyTrueExpr.INSTANCE);
        }
        return this;
    }

    public function evaluate(context:IContext):Bool {
        // Intentional !=
        return !JsCompare.looseEquals(context.getValue(this.key), this.value);
    }

    public function serialize():String {
        return this.key + ' != \'' + JsValues.toJsString(this.value) + '\'';
    }

    public function keys():Array<String> {
        return [this.key];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapNotEquals(this.key, this.value);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyEqualsExpr.create(this.key, this.value, this);
        }
        return this.negated;
    }
}

class ContextKeyNotExpr extends ContextKeyExpression {

    public static function create(key:String, ?negated:ContextKeyExpression):ContextKeyExpression {
        final constantValue = ContextKeyUtils.getConstant(key);
        if (constantValue != null) {
            return (constantValue ? ContextKeyFalseExpr.INSTANCE : ContextKeyTrueExpr.INSTANCE);
        }
        return new ContextKeyNotExpr(key, negated);
    }

    final key:String;
    var negated:Null<ContextKeyExpression>;

    function new(key:String, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.Not);
        this.key = key;
        this.negated = negated;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        return ContextKeyUtils.cmp1(this.key, (cast other : ContextKeyNotExpr).key);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            return (this.key == (cast other : ContextKeyNotExpr).key);
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        final constantValue = ContextKeyUtils.getConstant(this.key);
        if (constantValue != null) {
            return (constantValue ? ContextKeyFalseExpr.INSTANCE : ContextKeyTrueExpr.INSTANCE);
        }
        return this;
    }

    public function evaluate(context:IContext):Bool {
        return (!JsValues.truthy(context.getValue(this.key)));
    }

    public function serialize():String {
        return '!' + this.key;
    }

    public function keys():Array<String> {
        return [this.key];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapNot(this.key);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyDefinedExpr.create(this.key, this);
        }
        return this.negated;
    }
}

/**
 * The comparison expressions (`>`, `>=`, `<`, `<=`): the value is a number,
 * or a string that is not one (then the expression is always false).
 */
abstract class ContextKeyCompareExpr extends ContextKeyExpression {

    /**
     * Monaco's `withFloatOrStr`: a string holding a number becomes the
     * number; other values than strings and numbers give false.
     */
    static function withFloatOrStr(value:Any):{ok:Bool, value:Any} {
        if (JsValues.isString(value)) {
            final n = JsValues.parseFloat(value);
            if (!Math.isNaN(n)) {
                value = n;
            }
        }
        if (JsValues.isString(value) || JsValues.isNumber(value)) {
            return {ok: true, value: value};
        }
        return {ok: false, value: null};
    }

    @:allow(cityscape.platform.contextkey.common)
    static function createCompare(type:ContextKeyExprType, key:String, _value:Any, negated:Null<ContextKeyExpression>):ContextKeyExpression {
        final r = withFloatOrStr(_value);
        if (!r.ok) {
            return ContextKeyFalseExpr.INSTANCE;
        }
        return switch (type) {
            case ContextKeyExprType.Greater: @:privateAccess new ContextKeyGreaterExpr(key, r.value, negated);
            case ContextKeyExprType.GreaterEquals: @:privateAccess new ContextKeyGreaterEqualsExpr(key, r.value, negated);
            case ContextKeyExprType.Smaller: @:privateAccess new ContextKeySmallerExpr(key, r.value, negated);
            case _: @:privateAccess new ContextKeySmallerEqualsExpr(key, r.value, negated);
        };
    }

    final key:String;
    final value:Any;
    var negated:Null<ContextKeyExpression>;

    function new(type:ContextKeyExprType, key:String, value:Any, negated:Null<ContextKeyExpression>) {
        super(type);
        this.key = key;
        this.value = value;
        this.negated = negated;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        final o:ContextKeyCompareExpr = cast other;
        return ContextKeyUtils.cmp2(this.key, this.value, o.key, o.value);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            final o:ContextKeyCompareExpr = cast other;
            return (this.key == o.key && JsCompare.strictEquals(this.value, o.value));
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        return this;
    }

    public function evaluate(context:IContext):Bool {
        if (JsValues.isString(this.value)) {
            return false;
        }
        final left = JsValues.parseFloat(context.getValue(this.key));
        final right:Float = this.value;
        if (Math.isNaN(left)) {
            return false;
        }
        return compare(left, right);
    }

    abstract function compare(left:Float, right:Float):Bool;

    abstract function compareOperator():String;

    public function serialize():String {
        return this.key + ' ' + compareOperator() + ' ' + JsValues.toJsString(this.value);
    }

    public function keys():Array<String> {
        return [this.key];
    }

}

class ContextKeyGreaterExpr extends ContextKeyCompareExpr {

    public static function create(key:String, _value:Any, ?negated:ContextKeyExpression):ContextKeyExpression {
        return ContextKeyCompareExpr.createCompare(ContextKeyExprType.Greater, key, _value, negated);
    }

    function new(key:String, value:Any, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.Greater, key, value, negated);
    }

    function compare(left:Float, right:Float):Bool {
        return left > right;
    }

    function compareOperator():String {
        return '>';
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapGreater(this.key, this.value);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeySmallerEqualsExpr.create(this.key, this.value, this);
        }
        return this.negated;
    }
}

class ContextKeyGreaterEqualsExpr extends ContextKeyCompareExpr {

    public static function create(key:String, _value:Any, ?negated:ContextKeyExpression):ContextKeyExpression {
        return ContextKeyCompareExpr.createCompare(ContextKeyExprType.GreaterEquals, key, _value, negated);
    }

    function new(key:String, value:Any, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.GreaterEquals, key, value, negated);
    }

    function compare(left:Float, right:Float):Bool {
        return left >= right;
    }

    function compareOperator():String {
        return '>=';
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapGreaterEquals(this.key, this.value);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeySmallerExpr.create(this.key, this.value, this);
        }
        return this.negated;
    }
}

class ContextKeySmallerExpr extends ContextKeyCompareExpr {

    public static function create(key:String, _value:Any, ?negated:ContextKeyExpression):ContextKeyExpression {
        return ContextKeyCompareExpr.createCompare(ContextKeyExprType.Smaller, key, _value, negated);
    }

    function new(key:String, value:Any, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.Smaller, key, value, negated);
    }

    function compare(left:Float, right:Float):Bool {
        return left < right;
    }

    function compareOperator():String {
        return '<';
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapSmaller(this.key, this.value);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyGreaterEqualsExpr.create(this.key, this.value, this);
        }
        return this.negated;
    }
}

class ContextKeySmallerEqualsExpr extends ContextKeyCompareExpr {

    public static function create(key:String, _value:Any, ?negated:ContextKeyExpression):ContextKeyExpression {
        return ContextKeyCompareExpr.createCompare(ContextKeyExprType.SmallerEquals, key, _value, negated);
    }

    function new(key:String, value:Any, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.SmallerEquals, key, value, negated);
    }

    function compare(left:Float, right:Float):Bool {
        return left <= right;
    }

    function compareOperator():String {
        return '<=';
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapSmallerEquals(this.key, this.value);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyGreaterExpr.create(this.key, this.value, this);
        }
        return this.negated;
    }
}

class ContextKeyRegexExpr extends ContextKeyExpression {

    public static function create(key:String, regexp:Null<RegExp>):ContextKeyRegexExpr {
        return new ContextKeyRegexExpr(key, regexp);
    }

    var negated:Null<ContextKeyExpression> = null;
    final key:String;
    final regexp:Null<RegExp>;

    function new(key:String, regexp:Null<RegExp>) {
        super(ContextKeyExprType.Regex);
        this.key = key;
        this.regexp = regexp;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        final o:ContextKeyRegexExpr = cast other;
        if (this.key < o.key) {
            return -1;
        }
        if (this.key > o.key) {
            return 1;
        }
        final thisSource = this.regexp != null ? this.regexp.source : '';
        final otherSource = o.regexp != null ? o.regexp.source : '';
        if (thisSource < otherSource) {
            return -1;
        }
        if (thisSource > otherSource) {
            return 1;
        }
        return 0;
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            final o:ContextKeyRegexExpr = cast other;
            final thisSource = this.regexp != null ? this.regexp.source : '';
            final otherSource = o.regexp != null ? o.regexp.source : '';
            return (this.key == o.key && thisSource == otherSource);
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        return this;
    }

    public function evaluate(context:IContext):Bool {
        final value = context.getValue(this.key);
        if (this.regexp == null) {
            return false;
        }
        // `RegExp.test` converts its argument with `String(value)`
        final str = value == null ? 'undefined' : JsValues.toJsString(value);
        this.regexp.lastIndex = 0;
        return this.regexp.test(str);
    }

    public function serialize():String {
        final value = this.regexp != null
            ? '/' + this.regexp.source + '/' + this.regexp.flags
            : '/invalid/';
        return this.key + ' =~ ' + value;
    }

    public function keys():Array<String> {
        return [this.key];
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return mapFnc.mapRegex(this.key, this.regexp);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            this.negated = ContextKeyNotRegexExpr.create(this);
        }
        return this.negated;
    }
}

class ContextKeyNotRegexExpr extends ContextKeyExpression {

    public static function create(actual:ContextKeyRegexExpr):ContextKeyExpression {
        return new ContextKeyNotRegexExpr(actual);
    }

    final _actual:ContextKeyRegexExpr;

    function new(actual:ContextKeyRegexExpr) {
        super(ContextKeyExprType.NotRegex);
        this._actual = actual;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        return this._actual.cmp((cast other : ContextKeyNotRegexExpr)._actual);
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            return this._actual.equals((cast other : ContextKeyNotRegexExpr)._actual);
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        return this;
    }

    public function evaluate(context:IContext):Bool {
        return !this._actual.evaluate(context);
    }

    public function serialize():String {
        return '!(' + this._actual.serialize() + ')';
    }

    public function keys():Array<String> {
        return this._actual.keys();
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return new ContextKeyNotRegexExpr(cast this._actual.map(mapFnc));
    }

    public function negate():ContextKeyExpression {
        return this._actual;
    }
}

class ContextKeyAndExpr extends ContextKeyExpression {

    public static function create(_expr:Array<Null<ContextKeyExpression>>, negated:Null<ContextKeyExpression>, extraRedundantCheck:Bool):Null<ContextKeyExpression> {
        return ContextKeyAndExpr._normalizeArr(_expr, negated, extraRedundantCheck);
    }

    public final expr:Array<ContextKeyExpression>;
    var negated:Null<ContextKeyExpression>;

    function new(expr:Array<ContextKeyExpression>, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.And);
        this.expr = expr;
        this.negated = negated;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        final o:ContextKeyAndExpr = cast other;
        if (this.expr.length < o.expr.length) {
            return -1;
        }
        if (this.expr.length > o.expr.length) {
            return 1;
        }
        for (i in 0...this.expr.length) {
            final r = ContextKeyUtils.cmp(this.expr[i], o.expr[i]);
            if (r != 0) {
                return r;
            }
        }
        return 0;
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            final o:ContextKeyAndExpr = cast other;
            if (this.expr.length != o.expr.length) {
                return false;
            }
            for (i in 0...this.expr.length) {
                if (!this.expr[i].equals(o.expr[i])) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        final exprArr = ContextKeyUtils.eliminateConstantsInArray(this.expr);
        if (exprArr == cast this.expr) {
            // no change
            return this;
        }
        return ContextKeyAndExpr.create(exprArr, this.negated, false);
    }

    public function evaluate(context:IContext):Bool {
        for (i in 0...this.expr.length) {
            if (!this.expr[i].evaluate(context)) {
                return false;
            }
        }
        return true;
    }

    static function _normalizeArr(arr:Array<Null<ContextKeyExpression>>, negated:Null<ContextKeyExpression>, extraRedundantCheck:Bool):Null<ContextKeyExpression> {
        final expr:Array<ContextKeyExpression> = [];
        var hasTrue = false;

        for (e in arr) {
            if (e == null) {
                continue;
            }

            if (e.type == ContextKeyExprType.True) {
                // anything && true ==> anything
                hasTrue = true;
                continue;
            }

            if (e.type == ContextKeyExprType.False) {
                // anything && false ==> false
                return ContextKeyFalseExpr.INSTANCE;
            }

            if (e.type == ContextKeyExprType.And) {
                for (x in (cast e : ContextKeyAndExpr).expr) {
                    expr.push(x);
                }
                continue;
            }

            expr.push(e);
        }

        if (expr.length == 0 && hasTrue) {
            return ContextKeyTrueExpr.INSTANCE;
        }

        if (expr.length == 0) {
            return null;
        }

        if (expr.length == 1) {
            return expr[0];
        }

        haxe.ds.ArraySort.sort(expr, ContextKeyUtils.cmp);

        // eliminate duplicate terms
        var i = 1;
        while (i < expr.length) {
            if (expr[i - 1].equals(expr[i])) {
                expr.splice(i, 1);
                i--;
            }
            i++;
        }

        if (expr.length == 1) {
            return expr[0];
        }

        // We must distribute any OR expression because we don't support parens
        // OR extensions will be at the end (due to sorting rules)
        while (expr.length > 1) {
            final lastElement = expr[expr.length - 1];
            if (lastElement.type != ContextKeyExprType.Or) {
                break;
            }
            // pop the last element
            expr.pop();

            // pop the second to last element
            final secondToLastElement = expr.pop();

            final isFinished = (expr.length == 0);

            // distribute `lastElement` over `secondToLastElement`
            final resultElement = ContextKeyOrExpr.create(
                [for (el in (cast lastElement : ContextKeyOrExpr).expr) ContextKeyAndExpr.create([el, secondToLastElement], null, extraRedundantCheck)],
                null,
                isFinished
            );

            if (resultElement != null) {
                expr.push(resultElement);
                haxe.ds.ArraySort.sort(expr, ContextKeyUtils.cmp);
            }
        }

        if (expr.length == 1) {
            return expr[0];
        }

        // resolve false AND expressions
        if (extraRedundantCheck) {
            for (i in 0...expr.length) {
                for (j in (i + 1)...expr.length) {
                    if (expr[i].negate().equals(expr[j])) {
                        // A && !A case
                        return ContextKeyFalseExpr.INSTANCE;
                    }
                }
            }

            if (expr.length == 1) {
                return expr[0];
            }
        }

        return new ContextKeyAndExpr(expr, negated);
    }

    public function serialize():String {
        return [for (e in this.expr) e.serialize()].join(' && ');
    }

    public function keys():Array<String> {
        final result:Array<String> = [];
        for (expr in this.expr) {
            for (k in expr.keys()) {
                result.push(k);
            }
        }
        return result;
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return new ContextKeyAndExpr([for (expr in this.expr) expr.map(mapFnc)], null);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            final result:Array<Null<ContextKeyExpression>> = [];
            for (expr in this.expr) {
                result.push(expr.negate());
            }
            this.negated = ContextKeyOrExpr.create(result, this, true);
        }
        return this.negated;
    }
}

class ContextKeyOrExpr extends ContextKeyExpression {

    public static function create(_expr:Array<Null<ContextKeyExpression>>, negated:Null<ContextKeyExpression>, extraRedundantCheck:Bool):Null<ContextKeyExpression> {
        return ContextKeyOrExpr._normalizeArr(_expr, negated, extraRedundantCheck);
    }

    public final expr:Array<ContextKeyExpression>;
    var negated:Null<ContextKeyExpression>;

    function new(expr:Array<ContextKeyExpression>, negated:Null<ContextKeyExpression>) {
        super(ContextKeyExprType.Or);
        this.expr = expr;
        this.negated = negated;
    }

    public function cmp(other:ContextKeyExpression):Int {
        if (other.type != this.type) {
            return this.type - other.type;
        }
        final o:ContextKeyOrExpr = cast other;
        if (this.expr.length < o.expr.length) {
            return -1;
        }
        if (this.expr.length > o.expr.length) {
            return 1;
        }
        for (i in 0...this.expr.length) {
            final r = ContextKeyUtils.cmp(this.expr[i], o.expr[i]);
            if (r != 0) {
                return r;
            }
        }
        return 0;
    }

    public function equals(other:ContextKeyExpression):Bool {
        if (other.type == this.type) {
            final o:ContextKeyOrExpr = cast other;
            if (this.expr.length != o.expr.length) {
                return false;
            }
            for (i in 0...this.expr.length) {
                if (!this.expr[i].equals(o.expr[i])) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    public function substituteConstants():Null<ContextKeyExpression> {
        final exprArr = ContextKeyUtils.eliminateConstantsInArray(this.expr);
        if (exprArr == cast this.expr) {
            // no change
            return this;
        }
        return ContextKeyOrExpr.create(exprArr, this.negated, false);
    }

    public function evaluate(context:IContext):Bool {
        for (i in 0...this.expr.length) {
            if (this.expr[i].evaluate(context)) {
                return true;
            }
        }
        return false;
    }

    static function _normalizeArr(arr:Array<Null<ContextKeyExpression>>, negated:Null<ContextKeyExpression>, extraRedundantCheck:Bool):Null<ContextKeyExpression> {
        var expr:Array<ContextKeyExpression> = [];
        var hasFalse = false;

        if (arr != null) {
            for (i in 0...arr.length) {
                final e = arr[i];
                if (e == null) {
                    continue;
                }

                if (e.type == ContextKeyExprType.False) {
                    // anything || false ==> anything
                    hasFalse = true;
                    continue;
                }

                if (e.type == ContextKeyExprType.True) {
                    // anything || true ==> true
                    return ContextKeyTrueExpr.INSTANCE;
                }

                if (e.type == ContextKeyExprType.Or) {
                    expr = expr.concat((cast e : ContextKeyOrExpr).expr);
                    continue;
                }

                expr.push(e);
            }

            if (expr.length == 0 && hasFalse) {
                return ContextKeyFalseExpr.INSTANCE;
            }

            haxe.ds.ArraySort.sort(expr, ContextKeyUtils.cmp);
        }

        if (expr.length == 0) {
            return null;
        }

        if (expr.length == 1) {
            return expr[0];
        }

        // eliminate duplicate terms
        var i = 1;
        while (i < expr.length) {
            if (expr[i - 1].equals(expr[i])) {
                expr.splice(i, 1);
                i--;
            }
            i++;
        }

        if (expr.length == 1) {
            return expr[0];
        }

        // resolve true OR expressions
        if (extraRedundantCheck) {
            for (i in 0...expr.length) {
                for (j in (i + 1)...expr.length) {
                    if (expr[i].negate().equals(expr[j])) {
                        // A || !A case
                        return ContextKeyTrueExpr.INSTANCE;
                    }
                }
            }

            if (expr.length == 1) {
                return expr[0];
            }
        }

        return new ContextKeyOrExpr(expr, negated);
    }

    public function serialize():String {
        return [for (e in this.expr) e.serialize()].join(' || ');
    }

    public function keys():Array<String> {
        final result:Array<String> = [];
        for (expr in this.expr) {
            for (k in expr.keys()) {
                result.push(k);
            }
        }
        return result;
    }

    public function map(mapFnc:IContextKeyExprMapper):ContextKeyExpression {
        return new ContextKeyOrExpr([for (expr in this.expr) expr.map(mapFnc)], null);
    }

    public function negate():ContextKeyExpression {
        if (this.negated == null) {
            final result:Array<ContextKeyExpression> = [];
            for (expr in this.expr) {
                result.push(expr.negate());
            }

            // We don't support parens, so here we distribute the AND over the OR terminals
            // We always take the first 2 AND pairs and distribute them
            while (result.length > 1) {
                final LEFT = result.shift();
                final RIGHT = result.shift();

                final all:Array<Null<ContextKeyExpression>> = [];
                for (left in ContextKeyUtils.getTerminals(LEFT)) {
                    for (right in ContextKeyUtils.getTerminals(RIGHT)) {
                        all.push(ContextKeyAndExpr.create([left, right], null, false));
                    }
                }

                result.unshift(ContextKeyOrExpr.create(all, null, false));
            }

            this.negated = ContextKeyOrExpr.create(cast result, this, true);
        }
        return this.negated;
    }
}

typedef ContextKeyInfo = {
    final key:String;
    @:optional final type:String;
    @:optional final description:String;
}

/**
 * A context key with a default value: an expression (`has(key)`) that can
 * be bound to a context key service (`bindTo(editor.contextKeyService)`).
 *
 * `metaOrHide` is a description, `true` to hide the key from the list of
 * all keys, or `{type, description}`.
 */
class RawContextKey<T> extends ContextKeyDefinedExpr {

    static var _infoArray:Null<Array<ContextKeyInfo>> = null;
    static var _info(get, never):Array<ContextKeyInfo>;
    static function get__info():Array<ContextKeyInfo> {
        if (_infoArray == null) {
            _infoArray = [];
        }
        return _infoArray;
    }

    public static function all():Array<ContextKeyInfo> {
        return _info.copy();
    }

    final _defaultValue:Null<T>;

    public function new(key:String, defaultValue:Null<T>, ?metaOrHide:Any) {
        super(key, null);
        this._defaultValue = defaultValue;

        // collect all context keys into a central place
        // (`metaOrHide` is read with its type: on C# an `Any` compared with
        // `true` is a reference comparison of boxed values, never equal)
        if (metaOrHide != null && JsValues.isObject(metaOrHide)) {
            _info.push({key: key, type: JsValues.field(metaOrHide, 'type'), description: JsValues.field(metaOrHide, 'description')});
        }
        else {
            final hide = Std.isOfType(metaOrHide, Bool) && (metaOrHide : Bool);
            if (!hide) {
                final description:Null<String> = Std.isOfType(metaOrHide, String) ? (metaOrHide : String) : null;
                _info.push({key: key, description: description, type: defaultValue != null ? JsTypeof.of(defaultValue) : null});
            }
        }
    }

    public function bindTo(target:IContextKeyService):IContextKey<T> {
        return target.createKey(this.key, this._defaultValue);
    }

    public function getValue(target:IContextKeyService):Null<T> {
        return target.getContextKeyValue(this.key);
    }

    public function toNegated():ContextKeyExpression {
        return this.negate();
    }

    public function isEqualTo(value:Any):ContextKeyExpression {
        return ContextKeyEqualsExpr.create(this.key, value);
    }

    public function notEqualsTo(value:Any):ContextKeyExpression {
        return ContextKeyNotEqualsExpr.create(this.key, value);
    }
}

private class JsTypeof {
    public static function of(value:Any):String {
        if (JsValues.isBoolean(value)) {
            return 'boolean';
        }
        if (JsValues.isNumber(value)) {
            return 'number';
        }
        if (JsValues.isString(value)) {
            return 'string';
        }
        return 'object';
    }
}
