// Ported from vscode src/vs/editor/contrib/snippet/browser/snippetParser.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.snippet.view;

import cityscape.base.common.CharCode;
import cityscape.base.common.JsValues;
import cityscape.base.common.RegExp;

// Types of this module:
// - TokenType, Token, Scanner
// - Marker, Text, TransformableMarker, Placeholder, Choice, Transform,
//   FormatString, Variable, VariableResolver, TextmateSnippet,
//   PlaceholderInfo
// - SnippetParser
//
// The fixed regular expressions of snippetParser.ts that only test
// characters (`Text.escape`, `SnippetParser.escape`, the escapes of
// `Choice.toTextmateString` and `_until`, `/^\d+$/`, `/[a-z0-9]+/gi` of the
// case conversions, `guessNeedsClipboard`) are written as loops. The
// regular expressions of transforms (written by the snippet author) are
// `cityscape.base.common.RegExp`s, with JavaScript's `String.replace`
// written out in `Transform.resolve`.

enum abstract TokenType(Int) from Int to Int {
    var Dollar = 0;
    var Colon = 1;
    var Comma = 2;
    var CurlyOpen = 3;
    var CurlyClose = 4;
    var Backslash = 5;
    var Forwardslash = 6;
    var Pipe = 7;
    var Int = 8;
    var VariableName = 9;
    var Format = 10;
    var Plus = 11;
    var Dash = 12;
    var QuestionMark = 13;
    var EOF = 14;
}

/**
 * A token of the scanner (Monaco's `Token` interface; a struct init class,
 * so that `{type: ..., pos: ..., len: ...}` literals work).
 */
@:structInit
class Token {

    public var type:TokenType;

    public var pos:Int;

    public var len:Int;

    public function new(type:TokenType, pos:Int, len:Int) {
        this.type = type;
        this.pos = pos;
        this.len = len;
    }

}

class Scanner {

    /**
     * Monaco's `Scanner._table` (character code to static token type): the
     * token type, or -1 when the character has no static token
     * (`undefined` in Monaco).
     */
    static function _table(ch:Int):Int {
        return switch ch {
            case CharCode.DollarSign: TokenType.Dollar;
            case CharCode.Colon: TokenType.Colon;
            case CharCode.Comma: TokenType.Comma;
            case CharCode.OpenCurlyBrace: TokenType.CurlyOpen;
            case CharCode.CloseCurlyBrace: TokenType.CurlyClose;
            case CharCode.Backslash: TokenType.Backslash;
            case CharCode.Slash: TokenType.Forwardslash;
            case CharCode.Pipe: TokenType.Pipe;
            case CharCode.Plus: TokenType.Plus;
            case CharCode.Dash: TokenType.Dash;
            case CharCode.QuestionMark: TokenType.QuestionMark;
            case _: -1;
        }
    }

    public static function isDigitCharacter(ch:Int):Bool {
        return ch >= (CharCode.Digit0:Int) && ch <= (CharCode.Digit9:Int);
    }

    public static function isVariableCharacter(ch:Int):Bool {
        return ch == (CharCode.Underline:Int)
            || (ch >= (CharCode.a:Int) && ch <= (CharCode.z:Int))
            || (ch >= (CharCode.A:Int) && ch <= (CharCode.Z:Int));
    }

    public var value:String = '';

    public var pos:Int = 0;

    public function new() {}

    public function text(value:String):Void {
        this.value = value;
        this.pos = 0;
    }

    public function tokenText(token:Token):String {
        return this.value.substr(token.pos, token.len);
    }

    /**
     * `this.value.charCodeAt(index)`, -1 out of range (JavaScript's `NaN`).
     */
    inline function codeAt(index:Int):Int {
        final value:String = this.value;
        return index < value.length ? StringTools.fastCodeAt(value, index) : -1;
    }

    public function next():Token {

        if (this.pos >= this.value.length) {
            return {type: TokenType.EOF, pos: this.pos, len: 0};
        }

        final pos = this.pos;
        var len = 0;
        var ch = codeAt(pos);
        var type:TokenType;

        // static types
        final staticType = _table(ch);
        if (staticType != -1) {
            this.pos += 1;
            return {type: staticType, pos: pos, len: 1};
        }

        // number
        if (Scanner.isDigitCharacter(ch)) {
            type = TokenType.Int;
            do {
                len += 1;
                ch = codeAt(pos + len);
            } while (Scanner.isDigitCharacter(ch));

            this.pos += len;
            return {type: type, pos: pos, len: len};
        }

        // variable name
        if (Scanner.isVariableCharacter(ch)) {
            type = TokenType.VariableName;
            do {
                ch = codeAt(pos + (++len));
            } while (Scanner.isVariableCharacter(ch) || Scanner.isDigitCharacter(ch));

            this.pos += len;
            return {type: type, pos: pos, len: len};
        }


        // format
        type = TokenType.Format;
        do {
            len += 1;
            ch = codeAt(pos + len);
        } while (
            ch != -1
            && _table(ch) == -1 // not static token
            && !Scanner.isDigitCharacter(ch) // not number
            && !Scanner.isVariableCharacter(ch) // not variable
        );

        this.pos += len;
        return {type: type, pos: pos, len: len};
    }
}

abstract class Marker {

    public var parent:Null<Marker> = null;

    var _children:Array<Marker> = [];

    public function appendChild(child:Marker):Marker {
        if (Std.isOfType(child, Text) && this._children.length > 0 && Std.isOfType(this._children[this._children.length - 1], Text)) {
            // this and previous child are text -> merge them
            (cast this._children[this._children.length - 1] : Text).value += (cast child : Text).value;
        }
        else {
            // normal adoption of child
            child.parent = this;
            this._children.push(child);
        }
        return this;
    }

    public function replace(child:Marker, others:Array<Marker>):Void {
        final parent = child.parent;
        final idx = parent.children.indexOf(child);
        final newChildren = parent.children.slice(0);
        // newChildren.splice(idx, 1, ...others) (a negative index counts from the end)
        final start = idx < 0 ? (newChildren.length + idx > 0 ? newChildren.length + idx : 0) : idx;
        newChildren.splice(start, 1);
        for (i in 0...others.length) {
            newChildren.insert(start + i, others[i]);
        }
        parent._children = newChildren;

        _fixParent(others, parent);
    }

    static function _fixParent(children:Array<Marker>, parent:Marker):Void {
        for (child in children) {
            child.parent = parent;
            _fixParent(child.children, child);
        }
    }

    public var children(get, never):Array<Marker>;
    inline function get_children():Array<Marker> {
        return this._children;
    }

    public var rightMostDescendant(get, never):Marker;
    function get_rightMostDescendant():Marker {
        if (this._children.length > 0) {
            return this._children[this._children.length - 1].rightMostDescendant;
        }
        return this;
    }

    public var snippet(get, never):Null<TextmateSnippet>;
    function get_snippet():Null<TextmateSnippet> {
        var candidate:Null<Marker> = this;
        while (true) {
            if (candidate == null) {
                return null;
            }
            if (Std.isOfType(candidate, TextmateSnippet)) {
                return cast candidate;
            }
            candidate = candidate.parent;
        }
    }

    public function toString():String {
        var result = '';
        for (cur in this.children) {
            result += cur.toString();
        }
        return result;
    }

    abstract public function toTextmateString():String;

    public function len():Int {
        return 0;
    }

    abstract public function clone():Marker;
}

class Text extends Marker {

    /**
     * `value.replace(/\$|}|\\/g, '\\$&')`.
     */
    public static function escape(value:String):String {
        return escapeChars(value, '$'.code, '}'.code, '\\'.code);
    }

    /**
     * Puts a backslash before every `a`, `b` or `c` character of `value`.
     */
    @:allow(cityscape.contrib.snippet.view)
    static function escapeChars(value:String, a:Int, b:Int, c:Int):String {
        var buf:Null<StringBuf> = null;
        for (i in 0...value.length) {
            final ch = StringTools.fastCodeAt(value, i);
            if (ch == a || ch == b || ch == c) {
                if (buf == null) {
                    buf = new StringBuf();
                    buf.addSub(value, 0, i);
                }
                buf.addChar('\\'.code);
            }
            if (buf != null) {
                buf.addChar(ch);
            }
        }
        return buf == null ? value : buf.toString();
    }

    public var value:String;

    public function new(value:String) {
        this.value = value;
    }

    override public function toString():String {
        return this.value;
    }

    public function toTextmateString():String {
        return Text.escape(this.value);
    }

    override public function len():Int {
        return this.value.length;
    }

    public function clone():Text {
        return new Text(this.value);
    }
}

abstract class TransformableMarker extends Marker {
    public var transform:Null<Transform> = null;
}

class Placeholder extends TransformableMarker {

    public static function compareByIndex(a:Placeholder, b:Placeholder):Int {
        if (a.index == b.index) {
            return 0;
        }
        else if (a.isFinalTabstop) {
            return 1;
        }
        else if (b.isFinalTabstop) {
            return -1;
        }
        else if (a.index < b.index) {
            return -1;
        }
        else if (a.index > b.index) {
            return 1;
        }
        else {
            return 0;
        }
    }

    /**
     * A number like Monaco's: the parser gives integral values, the snippet
     * session gives fractional ones to the placeholders of nested snippets
     * (`placeholder.index + nested.index / nestingLevel`).
     */
    public var index:Float;

    public function new(index:Float) {
        this.index = index;
    }

    public var isFinalTabstop(get, never):Bool;
    inline function get_isFinalTabstop():Bool {
        return this.index == 0;
    }

    public var choice(get, never):Null<Choice>;
    function get_choice():Null<Choice> {
        return this._children.length == 1 && Std.isOfType(this._children[0], Choice)
            ? cast this._children[0]
            : null;
    }

    public function toTextmateString():String {
        var transformString = '';
        if (this.transform != null) {
            transformString = this.transform.toTextmateString();
        }
        if (this.children.length == 0 && this.transform == null) {
            return '$' + JsValues.numberToString(this.index);
        }
        else if (this.children.length == 0) {
            return '$${' + JsValues.numberToString(this.index) + transformString + '}';
        }
        else if (this.choice != null) {
            return '$${' + JsValues.numberToString(this.index) + '|' + this.choice.toTextmateString() + '|' + transformString + '}';
        }
        else {
            return '$${' + JsValues.numberToString(this.index) + ':' + [for (child in this.children) child.toTextmateString()].join('') + transformString + '}';
        }
    }

    public function clone():Placeholder {
        final ret = new Placeholder(this.index);
        if (this.transform != null) {
            ret.transform = this.transform.clone();
        }
        ret._children = [for (child in this.children) child.clone()];
        return ret;
    }
}

class Choice extends Marker {

    public final options:Array<Text> = [];

    public function new() {}

    override public function appendChild(marker:Marker):Marker {
        if (Std.isOfType(marker, Text)) {
            marker.parent = this;
            this.options.push(cast marker);
        }
        return this;
    }

    override public function toString():String {
        return this.options[0].value;
    }

    public function toTextmateString():String {
        return [for (option in this.options) Text.escapeChars(option.value, '|'.code, ','.code, '\\'.code)].join(',');
    }

    override public function len():Int {
        return this.options[0].len();
    }

    public function clone():Choice {
        final ret = new Choice();
        for (option in this.options) {
            ret.appendChild(option);
        }
        return ret;
    }
}

class Transform extends Marker {

    public var regexp:RegExp = new RegExp('');

    public function new() {}

    /**
     * `value.replace(this.regexp, function () {...})` with JavaScript's
     * semantics: every match with the `g` flag (from index 0, an empty
     * match moves one character on), the first one otherwise.
     */
    public function resolve(value:String):String {
        var didMatch = false;
        var ret:String;
        final regexp = this.regexp;
        if (regexp.global) {
            final buf = new StringBuf();
            var nextSourcePosition = 0;
            regexp.lastIndex = 0;
            while (true) {
                final match = regexp.exec(value);
                if (match == null) {
                    break;
                }
                final matched:String = match[0];
                if (matched.length == 0) {
                    regexp.lastIndex = advanceStringIndex(value, regexp.lastIndex, regexp.unicode);
                }
                didMatch = true;
                buf.addSub(value, nextSourcePosition, match.index - nextSourcePosition);
                buf.add(this._replace(groupsOf(match)));
                nextSourcePosition = match.index + matched.length;
            }
            if (!didMatch) {
                ret = value;
            }
            else {
                buf.addSub(value, nextSourcePosition, value.length - nextSourcePosition);
                ret = buf.toString();
            }
        }
        else {
            final match = regexp.exec(value);
            if (match == null) {
                ret = value;
            }
            else {
                didMatch = true;
                final matched:String = match[0];
                ret = value.substring(0, match.index) + this._replace(groupsOf(match)) + value.substring(match.index + matched.length);
            }
        }
        // when the regex didn't match and when the transform has
        // else branches, then run those
        if (!didMatch && hasElseBranch()) {
            ret = this._replace([]);
        }
        return ret;
    }

    function hasElseBranch():Bool {
        for (child in this._children) {
            if (Std.isOfType(child, FormatString)) {
                final elseValue = (cast child : FormatString).elseValue;
                if (elseValue != null && elseValue.length > 0) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * The arguments of the replace function without the offset and the
     * string: the match and the groups (null when a group did not match).
     */
    static function groupsOf(match:RegExpExecArray):Array<Null<String>> {
        return [for (i in 0...match.length) match[i]];
    }

    /**
     * JavaScript's `AdvanceStringIndex`.
     */
    static function advanceStringIndex(value:String, index:Int, unicode:Bool):Int {
        if (!unicode || index + 1 >= value.length) {
            return index + 1;
        }
        final first = StringTools.fastCodeAt(value, index);
        if (first < 0xD800 || first > 0xDBFF) {
            return index + 1;
        }
        final second = StringTools.fastCodeAt(value, index + 1);
        if (second < 0xDC00 || second > 0xDFFF) {
            return index + 1;
        }
        return index + 2;
    }

    function _replace(groups:Array<Null<String>>):String {
        var ret = '';
        for (marker in this._children) {
            if (Std.isOfType(marker, FormatString)) {
                final formatString:FormatString = cast marker;
                var value:Null<String> = formatString.index >= 0 && formatString.index < groups.length ? groups[formatString.index] : null;
                if (value == null) {
                    value = '';
                }
                value = formatString.resolve(value);
                ret += value;
            }
            else {
                ret += marker.toString();
            }
        }
        return ret;
    }

    override public function toString():String {
        return '';
    }

    public function toTextmateString():String {
        // `${array}` in a template literal joins with commas
        return '/' + this.regexp.source + '/' + [for (c in this.children) c.toTextmateString()].join(',') + '/' + (this.regexp.ignoreCase ? 'i' : '') + (this.regexp.global ? 'g' : '');
    }

    public function clone():Transform {
        final ret = new Transform();
        ret.regexp = new RegExp(this.regexp.source, '' + (this.regexp.ignoreCase ? 'i' : '') + (this.regexp.global ? 'g' : ''));
        ret._children = [for (child in this.children) child.clone()];
        return ret;
    }

}

class FormatString extends Marker {

    public final index:Int;

    public final shorthandName:Null<String>;

    public final ifValue:Null<String>;

    public final elseValue:Null<String>;

    public function new(index:Int, ?shorthandName:String, ?ifValue:String, ?elseValue:String) {
        this.index = index;
        this.shorthandName = shorthandName;
        this.ifValue = ifValue;
        this.elseValue = elseValue;
    }

    public function resolve(?value:String):String {
        final isEmpty = (value == null || value.length == 0);
        if (this.shorthandName == 'upcase') {
            return isEmpty ? '' : value.toUpperCase();
        }
        else if (this.shorthandName == 'downcase') {
            return isEmpty ? '' : value.toLowerCase();
        }
        else if (this.shorthandName == 'capitalize') {
            return isEmpty ? '' : (value.charAt(0).toUpperCase() + value.substr(1));
        }
        else if (this.shorthandName == 'pascalcase') {
            return isEmpty ? '' : this._toPascalCase(value);
        }
        else if (this.shorthandName == 'camelcase') {
            return isEmpty ? '' : this._toCamelCase(value);
        }
        else if (!isEmpty && this.ifValue != null) {
            return this.ifValue;
        }
        else if (isEmpty && this.elseValue != null) {
            return this.elseValue;
        }
        else {
            return isEmpty ? '' : value;
        }
    }

    static inline function isAsciiAlphanumeric(ch:Int):Bool {
        return (ch >= 'a'.code && ch <= 'z'.code) || (ch >= 'A'.code && ch <= 'Z'.code) || (ch >= '0'.code && ch <= '9'.code);
    }

    /**
     * `value.match(/[a-z0-9]+/gi)`: the runs of ASCII letters and digits
     * (null when there is none).
     */
    static function matchWords(value:String):Null<Array<String>> {
        var result:Null<Array<String>> = null;
        var start = -1;
        for (i in 0...value.length + 1) {
            final inWord = i < value.length && isAsciiAlphanumeric(StringTools.fastCodeAt(value, i));
            if (inWord && start == -1) {
                start = i;
            }
            else if (!inWord && start != -1) {
                if (result == null) {
                    result = [];
                }
                result.push(value.substring(start, i));
                start = -1;
            }
        }
        return result;
    }

    function _toPascalCase(value:String):String {
        final match = matchWords(value);
        if (match == null) {
            return value;
        }
        return [for (word in match) word.charAt(0).toUpperCase() + word.substr(1)].join('');
    }

    function _toCamelCase(value:String):String {
        final match = matchWords(value);
        if (match == null) {
            return value;
        }
        return [for (index in 0...match.length) {
            final word = match[index];
            if (index == 0) {
                word.charAt(0).toLowerCase() + word.substr(1);
            }
            else {
                word.charAt(0).toUpperCase() + word.substr(1);
            }
        }].join('');
    }

    public function toTextmateString():String {
        var value = '$${';
        value += this.index;
        if (this.shorthandName != null && this.shorthandName.length > 0) {
            value += ':/' + this.shorthandName;

        }
        else if (this.ifValue != null && this.ifValue.length > 0 && this.elseValue != null && this.elseValue.length > 0) {
            value += ':?' + this.ifValue + ':' + this.elseValue;
        }
        else if (this.ifValue != null && this.ifValue.length > 0) {
            value += ':+' + this.ifValue;
        }
        else if (this.elseValue != null && this.elseValue.length > 0) {
            value += ':-' + this.elseValue;
        }
        value += '}';
        return value;
    }

    public function clone():FormatString {
        final ret = new FormatString(this.index, this.shorthandName, this.ifValue, this.elseValue);
        return ret;
    }
}

class Variable extends TransformableMarker {

    public var name:String;

    public function new(name:String) {
        this.name = name;
    }

    public function resolve(resolver:VariableResolver):Bool {
        var value = resolver.resolve(this);
        if (this.transform != null) {
            value = this.transform.resolve(value != null ? value : '');
        }
        if (value != null) {
            this._children = [new Text(value)];
            return true;
        }
        return false;
    }

    public function toTextmateString():String {
        var transformString = '';
        if (this.transform != null) {
            transformString = this.transform.toTextmateString();
        }
        if (this.children.length == 0) {
            return '$${' + this.name + transformString + '}';
        }
        else {
            return '$${' + this.name + ':' + [for (child in this.children) child.toTextmateString()].join('') + transformString + '}';
        }
    }

    public function clone():Variable {
        final ret = new Variable(this.name);
        if (this.transform != null) {
            ret.transform = this.transform.clone();
        }
        ret._children = [for (child in this.children) child.clone()];
        return ret;
    }
}

interface VariableResolver {
    /**
     * The value of the variable, null when it is unknown (`undefined` in
     * Monaco).
     */
    function resolve(variable:Variable):Null<String>;
}

/**
 * Monaco's `{ all: Placeholder[]; last?: Placeholder }` of
 * `TextmateSnippet.placeholderInfo`.
 */
class PlaceholderInfo {

    public final all:Array<Placeholder>;

    public final last:Null<Placeholder>;

    public function new(all:Array<Placeholder>, last:Null<Placeholder>) {
        this.all = all;
        this.last = last;
    }

}

class TextmateSnippet extends Marker {

    /**
     * The module function `walk` of snippetParser.ts.
     */
    public static function walkStatic(marker:Array<Marker>, visitor:(marker:Marker) -> Bool):Void {
        final stack = marker.copy();
        while (stack.length > 0) {
            final marker = stack.shift();
            final recurse = visitor(marker);
            if (!recurse) {
                break;
            }
            final children = marker.children;
            var i = children.length - 1;
            while (i >= 0) {
                stack.unshift(children[i]);
                i--;
            }
        }
    }

    var _placeholders:Null<PlaceholderInfo> = null;

    public function new() {}

    public var placeholderInfo(get, never):PlaceholderInfo;
    function get_placeholderInfo():PlaceholderInfo {
        if (this._placeholders == null) {
            // fill in placeholders
            final all:Array<Placeholder> = [];
            var last:Null<Placeholder> = null;
            this.walk(function(candidate) {
                if (Std.isOfType(candidate, Placeholder)) {
                    final placeholder:Placeholder = cast candidate;
                    all.push(placeholder);
                    last = last == null || last.index < placeholder.index ? placeholder : last;
                }
                return true;
            });
            this._placeholders = new PlaceholderInfo(all, last);
        }
        return this._placeholders;
    }

    public var placeholders(get, never):Array<Placeholder>;
    function get_placeholders():Array<Placeholder> {
        return this.placeholderInfo.all;
    }

    public function offset(marker:Marker):Int {
        var pos = 0;
        var found = false;
        this.walk(candidate -> {
            if (candidate == marker) {
                found = true;
                return false;
            }
            pos += candidate.len();
            return true;
        });

        if (!found) {
            return -1;
        }
        return pos;
    }

    public function fullLen(marker:Marker):Int {
        var ret = 0;
        walkStatic([marker], marker -> {
            ret += marker.len();
            return true;
        });
        return ret;
    }

    public function enclosingPlaceholders(placeholder:Placeholder):Array<Placeholder> {
        final ret:Array<Placeholder> = [];
        var parent = placeholder.parent;
        while (parent != null) {
            if (Std.isOfType(parent, Placeholder)) {
                ret.push(cast parent);
            }
            parent = parent.parent;
        }
        return ret;
    }

    public function resolveVariables(resolver:VariableResolver):TextmateSnippet {
        this.walk(candidate -> {
            if (Std.isOfType(candidate, Variable)) {
                if ((cast candidate : Variable).resolve(resolver)) {
                    this._placeholders = null;
                }
            }
            return true;
        });
        return this;
    }

    override public function appendChild(child:Marker):Marker {
        this._placeholders = null;
        return super.appendChild(child);
    }

    override public function replace(child:Marker, others:Array<Marker>):Void {
        this._placeholders = null;
        super.replace(child, others);
    }

    public function toTextmateString():String {
        var result = '';
        for (cur in this.children) {
            result += cur.toTextmateString();
        }
        return result;
    }

    /**
     * Like Monaco's: the clones of the children replace the children of
     * this snippet, and the returned snippet is empty.
     */
    public function clone():TextmateSnippet {
        final ret = new TextmateSnippet();
        this._children = [for (child in this.children) child.clone()];
        return ret;
    }

    public function walk(visitor:(marker:Marker) -> Bool):Void {
        walkStatic(this.children, visitor);
    }
}

class SnippetParser {

    /**
     * `value.replace(/\$|}|\\/g, '\\$&')`.
     */
    public static function escape(value:String):String {
        return Text.escapeChars(value, '$'.code, '}'.code, '\\'.code);
    }

    /**
     * Takes a snippet and returns the insertable string, e.g return the snippet-string
     * without any placeholder, tabstop, variables etc...
     */
    public static function asInsertText(value:String):String {
        return new SnippetParser().parse(value).toString();
    }

    /**
     * `/\${?CLIPBOARD/.test(template)`.
     */
    public static function guessNeedsClipboard(template:String):Bool {
        var index = template.indexOf('CLIPBOARD');
        while (index != -1) {
            if (index >= 1) {
                final before = StringTools.fastCodeAt(template, index - 1);
                if (before == '$'.code) {
                    return true;
                }
                if (before == '{'.code && index >= 2 && StringTools.fastCodeAt(template, index - 2) == '$'.code) {
                    return true;
                }
            }
            index = template.indexOf('CLIPBOARD', index + 1);
        }
        return false;
    }

    final _scanner:Scanner = new Scanner();

    var _token:Token = {type: TokenType.EOF, pos: 0, len: 0};

    public function new() {}

    public function parse(value:String, ?insertFinalTabstop:Bool, ?enforceFinalTabstop:Bool):TextmateSnippet {
        final snippet = new TextmateSnippet();
        this.parseFragment(value, snippet);
        this.ensureFinalTabstop(snippet, enforceFinalTabstop != null ? enforceFinalTabstop : false, insertFinalTabstop != null ? insertFinalTabstop : false);
        return snippet;
    }

    public function parseFragment(value:String, snippet:TextmateSnippet):Array<Marker> {

        final offset = snippet.children.length;
        this._scanner.text(value);
        this._token = this._scanner.next();
        while (this._parse(snippet)) {
            // nothing
        }

        // fill in values for placeholders. the first placeholder of an index
        // that has a value defines the value for all placeholders with that index
        // Keyed by `JsValues.numberToString(index)` (Haxe maps have no Float keys)
        final placeholderDefaultValues = new Map<String, Null<Array<Marker>>>();
        final incompletePlaceholders:Array<Placeholder> = [];
        snippet.walk(marker -> {
            if (Std.isOfType(marker, Placeholder)) {
                final marker:Placeholder = cast marker;
                if (marker.isFinalTabstop) {
                    placeholderDefaultValues.set('0', null);
                }
                else if (!placeholderDefaultValues.exists(JsValues.numberToString(marker.index)) && marker.children.length > 0) {
                    placeholderDefaultValues.set(JsValues.numberToString(marker.index), marker.children);
                }
                else {
                    incompletePlaceholders.push(marker);
                }
            }
            return true;
        });

        final stack = new Map<String, Bool>();

        function fillInIncompletePlaceholder(placeholder:Placeholder, stack:Map<String, Bool>):Void {
            final defaultValues = placeholderDefaultValues.get(JsValues.numberToString(placeholder.index));
            if (defaultValues == null) {
                return;
            }
            final clone = new Placeholder(placeholder.index);
            clone.transform = placeholder.transform;
            for (child in defaultValues) {
                final newChild = child.clone();
                clone.appendChild(newChild);

                // "recurse" on children that are again placeholders
                if (Std.isOfType(newChild, Placeholder)) {
                    final newChild:Placeholder = cast newChild;
                    final key = JsValues.numberToString(newChild.index);
                    if (placeholderDefaultValues.exists(key) && !stack.exists(key)) {
                        stack.set(key, true);
                        fillInIncompletePlaceholder(newChild, stack);
                        stack.remove(key);
                    }
                }
            }
            snippet.replace(placeholder, [clone]);
        }

        for (placeholder in incompletePlaceholders) {
            fillInIncompletePlaceholder(placeholder, stack);
        }

        return snippet.children.slice(offset);
    }

    public function ensureFinalTabstop(snippet:TextmateSnippet, enforceFinalTabstop:Bool, insertFinalTabstop:Bool):Void {

        if (enforceFinalTabstop || insertFinalTabstop && snippet.placeholders.length > 0) {
            var finalTabstop:Null<Placeholder> = null;
            for (p in snippet.placeholders) {
                if (p.index == 0) {
                    finalTabstop = p;
                    break;
                }
            }
            if (finalTabstop == null) {
                // the snippet uses placeholders but has no
                // final tabstop defined -> insert at the end
                snippet.appendChild(new Placeholder(0));
            }
        }

    }

    /**
     * JavaScript's truthiness of a string (`false` is null here).
     */
    static inline function truthy(value:Null<String>):Bool {
        return value != null && value.length > 0;
    }

    /**
     * `_accept(type)`: accepts the current token when it has the given type
     * (any token when `type` is null) and moves to the next one.
     */
    function _accept(?type:TokenType):Bool {
        if (type == null || this._token.type == type) {
            this._token = this._scanner.next();
            return true;
        }
        return false;
    }

    /**
     * `_accept(type, true)`: like `_accept`, returns the text of the
     * accepted token, or null (Monaco's `false`).
     */
    function _acceptValue(?type:TokenType):Null<String> {
        if (type == null || this._token.type == type) {
            final ret = this._scanner.tokenText(this._token);
            this._token = this._scanner.next();
            return ret;
        }
        return null;
    }

    function _backTo(token:Token):Bool {
        this._scanner.pos = token.pos + token.len;
        this._token = token;
        return false;
    }

    /**
     * Null where Monaco returns `false`.
     */
    function _until(type:TokenType):Null<String> {
        final start = this._token;
        while (this._token.type != type) {
            if (this._token.type == TokenType.EOF) {
                return null;
            }
            else if (this._token.type == TokenType.Backslash) {
                final nextToken = this._scanner.next();
                if (nextToken.type != TokenType.Dollar
                    && nextToken.type != TokenType.CurlyClose
                    && nextToken.type != TokenType.Backslash) {
                    return null;
                }
            }
            this._token = this._scanner.next();
        }
        final value = unescape(this._scanner.value.substring(start.pos, this._token.pos));
        this._token = this._scanner.next();
        return value;
    }

    /**
     * `value.replace(/\\(\$|}|\\)/g, '$1')`.
     */
    static function unescape(value:String):String {
        var buf:Null<StringBuf> = null;
        var i = 0;
        final len = value.length;
        while (i < len) {
            final ch = StringTools.fastCodeAt(value, i);
            if (ch == '\\'.code && i + 1 < len) {
                final next = StringTools.fastCodeAt(value, i + 1);
                if (next == '$'.code || next == '}'.code || next == '\\'.code) {
                    if (buf == null) {
                        buf = new StringBuf();
                        buf.addSub(value, 0, i);
                    }
                    buf.addChar(next);
                    i += 2;
                    continue;
                }
            }
            if (buf != null) {
                buf.addChar(ch);
            }
            i++;
        }
        return buf == null ? value : buf.toString();
    }

    function _parse(marker:Marker):Bool {
        return this._parseEscaped(marker)
            || this._parseTabstopOrVariableName(marker)
            || this._parseComplexPlaceholder(marker)
            || this._parseComplexVariable(marker)
            || this._parseAnything(marker);
    }

    // \$, \\, \} -> just text
    function _parseEscaped(marker:Marker):Bool {
        var value:Null<String>;
        if (truthy(value = this._acceptValue(TokenType.Backslash))) {
            // saw a backslash, append escaped token or that backslash
            var escaped = this._acceptValue(TokenType.Dollar);
            if (!truthy(escaped)) {
                escaped = this._acceptValue(TokenType.CurlyClose);
            }
            if (!truthy(escaped)) {
                escaped = this._acceptValue(TokenType.Backslash);
            }
            if (truthy(escaped)) {
                value = escaped;
            }

            marker.appendChild(new Text(value));
            return true;
        }
        return false;
    }

    /**
     * `/^\d+$/.test(value)`.
     */
    static function isDigits(value:String):Bool {
        if (value.length == 0) {
            return false;
        }
        for (i in 0...value.length) {
            if (!Scanner.isDigitCharacter(StringTools.fastCodeAt(value, i))) {
                return false;
            }
        }
        return true;
    }

    /**
     * `Number(value)` of a token of digits, for the index of a format
     * string (a group number).
     */
    static inline function toNumber(value:String):Int {
        return Std.parseInt(value);
    }

    /**
     * `Number(value)` of a token of digits, for a placeholder index.
     */
    static inline function toPlaceholderIndex(value:String):Float {
        return Std.parseFloat(value);
    }

    // $foo -> variable, $1 -> tabstop
    function _parseTabstopOrVariableName(parent:Marker):Bool {
        var value:Null<String> = null;
        final token = this._token;
        var match = this._accept(TokenType.Dollar);
        if (match) {
            value = this._acceptValue(TokenType.VariableName);
            if (!truthy(value)) {
                value = this._acceptValue(TokenType.Int);
            }
            match = truthy(value);
        }

        if (!match) {
            return this._backTo(token);
        }

        parent.appendChild(isDigits(value)
            ? new Placeholder(toPlaceholderIndex(value))
            : new Variable(value)
        );
        return true;
    }

    // ${1:<children>}, ${1} -> placeholder
    function _parseComplexPlaceholder(parent:Marker):Bool {
        var index:Null<String> = null;
        final token = this._token;
        final match = this._accept(TokenType.Dollar)
            && this._accept(TokenType.CurlyOpen)
            && truthy(index = this._acceptValue(TokenType.Int));

        if (!match) {
            return this._backTo(token);
        }

        final placeholder = new Placeholder(toPlaceholderIndex(index));

        if (this._accept(TokenType.Colon)) {
            // ${1:<children>}
            while (true) {

                // ...} -> done
                if (this._accept(TokenType.CurlyClose)) {
                    parent.appendChild(placeholder);
                    return true;
                }

                if (this._parse(placeholder)) {
                    continue;
                }

                // fallback
                parent.appendChild(new Text('$${' + index + ':'));
                for (child in placeholder.children) {
                    parent.appendChild(child);
                }
                return true;
            }
        }
        else if (placeholder.index > 0 && this._accept(TokenType.Pipe)) {
            // ${1|one,two,three|}
            final choice = new Choice();

            while (true) {
                if (this._parseChoiceElement(choice)) {

                    if (this._accept(TokenType.Comma)) {
                        // opt, -> more
                        continue;
                    }

                    if (this._accept(TokenType.Pipe)) {
                        placeholder.appendChild(choice);
                        if (this._accept(TokenType.CurlyClose)) {
                            // ..|} -> done
                            parent.appendChild(placeholder);
                            return true;
                        }
                    }
                }

                this._backTo(token);
                return false;
            }

        }
        else if (this._accept(TokenType.Forwardslash)) {
            // ${1/<regex>/<format>/<options>}
            if (this._parseTransform(placeholder)) {
                parent.appendChild(placeholder);
                return true;
            }

            this._backTo(token);
            return false;

        }
        else if (this._accept(TokenType.CurlyClose)) {
            // ${1}
            parent.appendChild(placeholder);
            return true;

        }
        else {
            // ${1 <- missing curly or colon
            return this._backTo(token);
        }
    }

    function _parseChoiceElement(parent:Choice):Bool {
        final token = this._token;
        final values:Array<String> = [];

        while (true) {
            if (this._token.type == TokenType.Comma || this._token.type == TokenType.Pipe) {
                break;
            }
            var value:Null<String>;
            if (truthy(value = this._acceptValue(TokenType.Backslash))) {
                // \, \|, or \\
                var escaped = this._acceptValue(TokenType.Comma);
                if (!truthy(escaped)) {
                    escaped = this._acceptValue(TokenType.Pipe);
                }
                if (!truthy(escaped)) {
                    escaped = this._acceptValue(TokenType.Backslash);
                }
                if (truthy(escaped)) {
                    value = escaped;
                }
            }
            else {
                value = this._acceptValue();
            }
            if (!truthy(value)) {
                // EOF
                this._backTo(token);
                return false;
            }
            values.push(value);
        }

        if (values.length == 0) {
            this._backTo(token);
            return false;
        }

        parent.appendChild(new Text(values.join('')));
        return true;
    }

    // ${foo:<children>}, ${foo} -> variable
    function _parseComplexVariable(parent:Marker):Bool {
        var name:Null<String> = null;
        final token = this._token;
        final match = this._accept(TokenType.Dollar)
            && this._accept(TokenType.CurlyOpen)
            && truthy(name = this._acceptValue(TokenType.VariableName));

        if (!match) {
            return this._backTo(token);
        }

        final variable = new Variable(name);

        if (this._accept(TokenType.Colon)) {
            // ${foo:<children>}
            while (true) {

                // ...} -> done
                if (this._accept(TokenType.CurlyClose)) {
                    parent.appendChild(variable);
                    return true;
                }

                if (this._parse(variable)) {
                    continue;
                }

                // fallback
                parent.appendChild(new Text('$${' + name + ':'));
                for (child in variable.children) {
                    parent.appendChild(child);
                }
                return true;
            }

        }
        else if (this._accept(TokenType.Forwardslash)) {
            // ${foo/<regex>/<format>/<options>}
            if (this._parseTransform(variable)) {
                parent.appendChild(variable);
                return true;
            }

            this._backTo(token);
            return false;

        }
        else if (this._accept(TokenType.CurlyClose)) {
            // ${foo}
            parent.appendChild(variable);
            return true;

        }
        else {
            // ${foo <- missing curly or colon
            return this._backTo(token);
        }
    }

    function _parseTransform(parent:TransformableMarker):Bool {
        // ...<regex>/<format>/<options>}

        final transform = new Transform();
        var regexValue = '';
        var regexOptions = '';

        // (1) /regex
        while (true) {
            if (this._accept(TokenType.Forwardslash)) {
                break;
            }

            var escaped:Null<String>;
            if (truthy(escaped = this._acceptValue(TokenType.Backslash))) {
                final slash = this._acceptValue(TokenType.Forwardslash);
                if (truthy(slash)) {
                    escaped = slash;
                }
                regexValue += escaped;
                continue;
            }

            if (this._token.type != TokenType.EOF) {
                regexValue += this._acceptValue();
                continue;
            }
            return false;
        }

        // (2) /format
        while (true) {
            if (this._accept(TokenType.Forwardslash)) {
                break;
            }

            var escaped:Null<String>;
            if (truthy(escaped = this._acceptValue(TokenType.Backslash))) {
                var next = this._acceptValue(TokenType.Backslash);
                if (!truthy(next)) {
                    next = this._acceptValue(TokenType.Forwardslash);
                }
                if (truthy(next)) {
                    escaped = next;
                }
                transform.appendChild(new Text(escaped));
                continue;
            }

            if (this._parseFormatString(transform) || this._parseAnything(transform)) {
                continue;
            }
            return false;
        }

        // (3) /option
        while (true) {
            if (this._accept(TokenType.CurlyClose)) {
                break;
            }
            if (this._token.type != TokenType.EOF) {
                regexOptions += this._acceptValue();
                continue;
            }
            return false;
        }

        try {
            transform.regexp = new RegExp(regexValue, regexOptions);
        }
        catch (e:Dynamic) {
            // invalid regexp
            return false;
        }

        parent.transform = transform;
        return true;
    }

    function _parseFormatString(parent:Transform):Bool {

        final token = this._token;
        if (!this._accept(TokenType.Dollar)) {
            return false;
        }

        var complex = false;
        if (this._accept(TokenType.CurlyOpen)) {
            complex = true;
        }

        final index = this._acceptValue(TokenType.Int);

        if (!truthy(index)) {
            this._backTo(token);
            return false;

        }
        else if (!complex) {
            // $1
            parent.appendChild(new FormatString(toNumber(index)));
            return true;

        }
        else if (this._accept(TokenType.CurlyClose)) {
            // ${1}
            parent.appendChild(new FormatString(toNumber(index)));
            return true;

        }
        else if (!this._accept(TokenType.Colon)) {
            this._backTo(token);
            return false;
        }

        if (this._accept(TokenType.Forwardslash)) {
            // ${1:/upcase}
            final shorthand = this._acceptValue(TokenType.VariableName);
            if (!truthy(shorthand) || !this._accept(TokenType.CurlyClose)) {
                this._backTo(token);
                return false;
            }
            else {
                parent.appendChild(new FormatString(toNumber(index), shorthand));
                return true;
            }

        }
        else if (this._accept(TokenType.Plus)) {
            // ${1:+<if>}
            final ifValue = this._until(TokenType.CurlyClose);
            if (truthy(ifValue)) {
                parent.appendChild(new FormatString(toNumber(index), null, ifValue, null));
                return true;
            }

        }
        else if (this._accept(TokenType.Dash)) {
            // ${2:-<else>}
            final elseValue = this._until(TokenType.CurlyClose);
            if (truthy(elseValue)) {
                parent.appendChild(new FormatString(toNumber(index), null, null, elseValue));
                return true;
            }

        }
        else if (this._accept(TokenType.QuestionMark)) {
            // ${2:?<if>:<else>}
            final ifValue = this._until(TokenType.Colon);
            if (truthy(ifValue)) {
                final elseValue = this._until(TokenType.CurlyClose);
                if (truthy(elseValue)) {
                    parent.appendChild(new FormatString(toNumber(index), null, ifValue, elseValue));
                    return true;
                }
            }

        }
        else {
            // ${1:<else>}
            final elseValue = this._until(TokenType.CurlyClose);
            if (truthy(elseValue)) {
                parent.appendChild(new FormatString(toNumber(index), null, null, elseValue));
                return true;
            }
        }

        this._backTo(token);
        return false;
    }

    function _parseAnything(marker:Marker):Bool {
        if (this._token.type != TokenType.EOF) {
            marker.appendChild(new Text(this._scanner.tokenText(this._token)));
            this._accept();
            return true;
        }
        return false;
    }
}
