// Ported from vscode src/vs/platform/contextkey/common/scanner.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.contextkey.common;

import cityscape.base.common.CharCode;

enum abstract TokenType(Int) from Int to Int {
    var LParen = 0;
    var RParen = 1;
    var Neg = 2;
    var Eq = 3;
    var NotEq = 4;
    var Lt = 5;
    var LtEq = 6;
    var Gt = 7;
    var GtEq = 8;
    var RegexOp = 9;
    var RegexStr = 10;
    var True = 11;
    var False = 12;
    var In = 13;
    var Not = 14;
    var And = 15;
    var Or = 16;
    var Str = 17;
    var QuotedStr = 18;
    var Error = 19;
    var EOF = 20;
}

/**
 * A token (Monaco's `Token` union: `lexeme` is set for `RegexStr`, `Str`,
 * `QuotedStr` and `Error`, `isTripleEq` for `Eq` and `NotEq`).
 */
class Token {

    public final type:TokenType;
    public final offset:Int;
    public final lexeme:Null<String>;
    public final isTripleEq:Bool;

    public function new(type:TokenType, offset:Int, ?lexeme:String, isTripleEq:Bool = false) {
        this.type = type;
        this.offset = offset;
        this.lexeme = lexeme;
        this.isTripleEq = isTripleEq;
    }

}

/**
 * Example:
 * `foo == bar'` - note how single quote doesn't have a corresponding closing quote,
 * so it's reported as unexpected
 */
typedef LexingError = {
    var offset:Int;
    var lexeme:String;
    @:optional var additionalInfo:Null<String>;
}

/**
 * A simple scanner for context keys.
 *
 * The hints are Monaco's English texts (`localize` with no translation
 * table: the scanner has no context).
 */
class Scanner {

    static function hintDidYouMean(meant:Array<String>):Null<String> {
        return switch (meant.length) {
            case 1: 'Did you mean ' + meant[0] + '?';
            case 2: 'Did you mean ' + meant[0] + ' or ' + meant[1] + '?';
            case 3: 'Did you mean ' + meant[0] + ', ' + meant[1] + ' or ' + meant[2] + '?';
            default: null; // we just don't expect that many
        }
    }

    static inline final hintDidYouForgetToOpenOrCloseQuote = "Did you forget to open or close the quote?";
    static inline final hintDidYouForgetToEscapeSlash = "Did you forget to escape the '/' (slash) character? Put two backslashes before it to escape, e.g., '\\\\/\'.";

    public static function getLexeme(token:Token):String {
        return switch (token.type) {
            case TokenType.LParen: '(';
            case TokenType.RParen: ')';
            case TokenType.Neg: '!';
            case TokenType.Eq: token.isTripleEq ? '===' : '==';
            case TokenType.NotEq: token.isTripleEq ? '!==' : '!=';
            case TokenType.Lt: '<';
            case TokenType.LtEq: '<=';
            case TokenType.Gt: '>=';
            case TokenType.GtEq: '>=';
            case TokenType.RegexOp: '=~';
            case TokenType.RegexStr: token.lexeme;
            case TokenType.True: 'true';
            case TokenType.False: 'false';
            case TokenType.In: 'in';
            case TokenType.Not: 'not';
            case TokenType.And: '&&';
            case TokenType.Or: '||';
            case TokenType.Str: token.lexeme;
            case TokenType.QuotedStr: token.lexeme;
            case TokenType.Error: token.lexeme;
            case TokenType.EOF: 'EOF';
            default: throw 'Illegal state: unhandled token type: ' + (token.type : Int) + '; have you forgotten to add a case?';
        }
    }

    static function isRegexFlag(ch:Int):Bool {
        return ch == 'i'.code || ch == 'g'.code || ch == 's'.code || ch == 'm'.code || ch == 'y'.code || ch == 'u'.code;
    }

    static function keyword(lexeme:String):Null<TokenType> {
        return switch (lexeme) {
            case 'not': TokenType.Not;
            case 'in': TokenType.In;
            case 'false': TokenType.False;
            case 'true': TokenType.True;
            default: null;
        }
    }

    var _input:String = '';
    var _start:Int = 0;
    var _current:Int = 0;
    var _tokens:Array<Token> = [];
    var _errors:Array<LexingError> = [];

    public var errors(get, never):Array<LexingError>;
    function get_errors():Array<LexingError> {
        return this._errors;
    }

    public function new() {}

    public function reset(value:String):Scanner {
        this._input = value;

        this._start = 0;
        this._current = 0;
        this._tokens = [];
        this._errors = [];

        return this;
    }

    public function scan():Array<Token> {
        while (!this._isAtEnd()) {

            this._start = this._current;

            final ch = this._advance();
            switch (ch) {
                case CharCode.OpenParen:
                    this._addToken(TokenType.LParen);
                case CharCode.CloseParen:
                    this._addToken(TokenType.RParen);

                case CharCode.ExclamationMark:
                    if (this._match(CharCode.Equals)) {
                        final isTripleEq = this._match(CharCode.Equals); // eat last `=` if `!==`
                        this._tokens.push(new Token(TokenType.NotEq, this._start, null, isTripleEq));
                    }
                    else {
                        this._addToken(TokenType.Neg);
                    }

                case CharCode.SingleQuote:
                    this._quotedString();
                case CharCode.Slash:
                    this._regex();

                case CharCode.Equals:
                    if (this._match(CharCode.Equals)) { // support `==`
                        final isTripleEq = this._match(CharCode.Equals); // eat last `=` if `===`
                        this._tokens.push(new Token(TokenType.Eq, this._start, null, isTripleEq));
                    }
                    else if (this._match(CharCode.Tilde)) {
                        this._addToken(TokenType.RegexOp);
                    }
                    else {
                        this._error(hintDidYouMean(['==', '=~']));
                    }

                case CharCode.LessThan:
                    this._addToken(this._match(CharCode.Equals) ? TokenType.LtEq : TokenType.Lt);

                case CharCode.GreaterThan:
                    this._addToken(this._match(CharCode.Equals) ? TokenType.GtEq : TokenType.Gt);

                case CharCode.Ampersand:
                    if (this._match(CharCode.Ampersand)) {
                        this._addToken(TokenType.And);
                    }
                    else {
                        this._error(hintDidYouMean(['&&']));
                    }

                case CharCode.Pipe:
                    if (this._match(CharCode.Pipe)) {
                        this._addToken(TokenType.Or);
                    }
                    else {
                        this._error(hintDidYouMean(['||']));
                    }

                case CharCode.Space | CharCode.CarriageReturn | CharCode.Tab | CharCode.LineFeed | CharCode.NoBreakSpace:
                    // whitespace

                default:
                    this._string();
            }
        }

        this._start = this._current;
        this._addToken(TokenType.EOF);

        return this._tokens.copy();
    }

    function _match(expected:Int):Bool {
        if (this._isAtEnd()) {
            return false;
        }
        if (StringTools.fastCodeAt(this._input, this._current) != expected) {
            return false;
        }
        this._current++;
        return true;
    }

    function _advance():Int {
        return StringTools.fastCodeAt(this._input, this._current++);
    }

    function _peek():Int {
        return this._isAtEnd() ? CharCode.Null : StringTools.fastCodeAt(this._input, this._current);
    }

    function _addToken(type:TokenType):Void {
        this._tokens.push(new Token(type, this._start));
    }

    function _error(?additional:String):Void {
        final offset = this._start;
        final lexeme = this._input.substring(this._start, this._current);
        final errToken = new Token(TokenType.Error, this._start, lexeme);
        this._errors.push({offset: offset, lexeme: lexeme, additionalInfo: additional});
        this._tokens.push(errToken);
    }

    static var _letterRegExp:Null<cityscape.base.common.RegExp> = null;

    /**
     * One character of Monaco's
     * `/[a-zA-Z0-9_<>\-\./\\:\*\?\+\[\]\^,#@;"%\$\p{L}-]+/uy` at `index`:
     * its length in UTF-16 code units (2 for a letter outside the BMP), or 0.
     */
    function stringCharLength(index:Int):Int {
        final c = StringTools.fastCodeAt(this._input, index);
        if ((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code)) {
            return 1;
        }
        switch (c) {
            case '_'.code | '<'.code | '>'.code | '-'.code | '.'.code | '/'.code | '\\'.code | ':'.code | '*'.code | '?'.code | '+'.code | '['.code | ']'.code | '^'.code | ','.code | '#'.code | '@'.code | ';'.code | '"'.code | '%'.code | '$'.code:
                return 1;
            case _:
        }
        if (c < 128) {
            return 0;
        }
        var length = 1;
        if (c >= 0xD800 && c <= 0xDBFF && index + 1 < this._input.length) {
            final low = StringTools.fastCodeAt(this._input, index + 1);
            if (low >= 0xDC00 && low <= 0xDFFF) {
                length = 2;
            }
        }
        if (_letterRegExp == null) {
            _letterRegExp = new cityscape.base.common.RegExp('^\\p{L}$', 'u');
        }
        return _letterRegExp.test(this._input.substr(index, length)) ? length : 0;
    }

    // u - unicode, y - sticky // TODO@ulugbekna: we accept double quotes as part of the string rather than as a delimiter (to preserve old parser's behavior)
    function _string():Void {
        var end = this._start;
        while (end < this._input.length) {
            final length = stringCharLength(end);
            if (length == 0) {
                break;
            }
            end += length;
        }
        if (end > this._start) {
            this._current = end;
            final lexeme = this._input.substring(this._start, this._current);
            final keyword = Scanner.keyword(lexeme);
            if (keyword != null) {
                this._addToken(keyword);
            }
            else {
                this._tokens.push(new Token(TokenType.Str, this._start, lexeme));
            }
        }
    }

    // captures the lexeme without the leading and trailing '
    function _quotedString():Void {
        while (this._peek() != CharCode.SingleQuote && !this._isAtEnd()) { // TODO@ulugbekna: add support for escaping ' ?
            this._advance();
        }

        if (this._isAtEnd()) {
            this._error(hintDidYouForgetToOpenOrCloseQuote);
            return;
        }

        // consume the closing '
        this._advance();

        this._tokens.push(new Token(TokenType.QuotedStr, this._start + 1, this._input.substring(this._start + 1, this._current - 1)));
    }

    /*
     * Lexing a regex expression: /.../[igsmyu]*
     * Based on https://github.com/microsoft/TypeScript/blob/9247ef115e617805983740ba795d7a8164babf89/src/compiler/scanner.ts#L2129-L2181
     *
     * Note that we want slashes within a regex to be escaped, e.g., /file:\\/\\/\\// should match `file:///`
     */
    function _regex():Void {
        var p = this._current;

        var inEscape = false;
        var inCharacterClass = false;
        while (true) {
            if (p >= this._input.length) {
                this._current = p;
                this._error(hintDidYouForgetToEscapeSlash);
                return;
            }

            final ch = StringTools.fastCodeAt(this._input, p);

            if (inEscape) { // parsing an escape character
                inEscape = false;
            }
            else if (ch == CharCode.Slash && !inCharacterClass) { // end of regex
                p++;
                break;
            }
            else if (ch == CharCode.OpenSquareBracket) {
                inCharacterClass = true;
            }
            else if (ch == CharCode.Backslash) {
                inEscape = true;
            }
            else if (ch == CharCode.CloseSquareBracket) {
                inCharacterClass = false;
            }
            p++;
        }

        // Consume flags // TODO@ulugbekna: use regex instead
        while (p < this._input.length && isRegexFlag(StringTools.fastCodeAt(this._input, p))) {
            p++;
        }

        this._current = p;

        final lexeme = this._input.substring(this._start, this._current);
        this._tokens.push(new Token(TokenType.RegexStr, this._start, lexeme));
    }

    function _isAtEnd():Bool {
        return this._current >= this._input.length;
    }

}
