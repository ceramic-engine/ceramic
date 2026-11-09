// New code for Cityscape (not a port): JavaScript's RegExp for the ported code.
package cityscape.base.common;

/**
 * JavaScript's `RegExp`, as the ported Monaco code uses it: `exec` with
 * `lastIndex` stepping for the `g` (and `y`) flag, match indices in UTF-16
 * code units, `null` for groups that did not take part in the match, the
 * `global`/`ignoreCase`/`multiline`/`unicode` properties.
 *
 * On JavaScript this is the native `RegExp`. Elsewhere it is Haxe's `EReg`
 * (PCRE2 on hxcpp, compiled in UTF mode with Unicode properties, on the
 * UTF-16 code units of Haxe strings), and the JavaScript source is
 * translated into a PCRE2 pattern with the JavaScript meaning:
 *
 * - `\d`, `\w`, `\b` (and `\D`, `\W`, `\B`) are ASCII only, like JavaScript
 *   (PCRE2 would make them Unicode aware);
 * - `\s` is JavaScript's whitespace set;
 * - `.` does not match `\n`, `\r`, U+2028 or U+2029 (any character with `s`);
 * - `^` and `$` match at the start and end of the input only, or around
 *   `\n`, `\r`, U+2028 and U+2029 with `m` (PCRE2's `$` would also match
 *   before a final `\n`);
 * - `\uXXXX`, `\u{X...}` (surrogate pairs joined), `\v`, `\0`, `\/` and the
 *   identity escapes of letters without the `u` flag (`\a` is `a`);
 * - `[]` (matches nothing), `[^]` (any character), `[` inside a class (a
 *   literal, never a POSIX class);
 * - `\p{Script=X}`, `\p{sc=X}`, `\p{General_Category=X}`, `\p{gc=X}` become
 *   `\p{X}`.
 *
 * Known differences left on the native targets (documented in
 * DEVIATIONS.md): lookbehinds must have a fixed length in PCRE2 10.42; a
 * backreference to a group that did not match fails in PCRE2 (it matches
 * the empty string in JavaScript); lone surrogates (in the pattern or in
 * the text) are not supported in UTF mode; case insensitive matching uses
 * PCRE2's Unicode case folding.
 */
class RegExp {

    /**
     * The pattern (JavaScript's `source`: `(?:)` for an empty pattern).
     */
    public final source:String;

    /**
     * The flags, in JavaScript's canonical order (`dgimsuy`).
     */
    public final flags:String;

    public final global:Bool;

    public final ignoreCase:Bool;

    public final multiline:Bool;

    public final dotAll:Bool;

    public final unicode:Bool;

    public final sticky:Bool;

    #if js

    final native:js.lib.RegExp;

    /**
     * The index at which the next `exec` starts (with `g` or `y`).
     */
    public var lastIndex(get, set):Int;
    inline function get_lastIndex():Int {
        return native.lastIndex;
    }
    inline function set_lastIndex(value:Int):Int {
        return native.lastIndex = value;
    }

    #else

    final ereg:EReg;

    /**
     * The number of capturing groups (group 0, the whole match, included).
     */
    final groupCount:Int;

    /**
     * The index at which the next `exec` starts (with `g` or `y`).
     */
    public var lastIndex:Int = 0;

    #end

    /**
     * `new RegExp(source, flags)`. Throws on an invalid pattern or flag.
     */
    public function new(source:String, flags:String = '') {
        var hasIndices = false;
        var global = false;
        var ignoreCase = false;
        var multiline = false;
        var dotAll = false;
        var unicode = false;
        var sticky = false;
        for (i in 0...flags.length) {
            final c = StringTools.fastCodeAt(flags, i);
            final seen = switch c {
                case 'd'.code: final s = hasIndices; hasIndices = true; s;
                case 'g'.code: final s = global; global = true; s;
                case 'i'.code: final s = ignoreCase; ignoreCase = true; s;
                case 'm'.code: final s = multiline; multiline = true; s;
                case 's'.code: final s = dotAll; dotAll = true; s;
                case 'u'.code: final s = unicode; unicode = true; s;
                case 'y'.code: final s = sticky; sticky = true; s;
                case _: throw 'Invalid flags supplied to RegExp constructor \'' + flags + '\'';
            }
            if (seen) {
                throw 'Invalid flags supplied to RegExp constructor \'' + flags + '\'';
            }
        }
        this.global = global;
        this.ignoreCase = ignoreCase;
        this.multiline = multiline;
        this.dotAll = dotAll;
        this.unicode = unicode;
        this.sticky = sticky;
        this.flags = (hasIndices ? 'd' : '') + (global ? 'g' : '') + (ignoreCase ? 'i' : '') + (multiline ? 'm' : '') + (dotAll ? 's' : '') + (unicode ? 'u' : '') + (sticky ? 'y' : '');

        #if js
        this.native = new js.lib.RegExp(source, this.flags);
        this.source = this.native.source;
        #else
        this.source = (source.length == 0 ? '(?:)' : source);
        final translation = new JsToPcre(source, multiline, dotAll, unicode);
        final pattern = translation.translate();
        this.groupCount = translation.groupCount + 1;
        this.ereg = new EReg(pattern, ignoreCase ? 'i' : '');
        #end
    }

    /**
     * Runs the regular expression on `str`, from `lastIndex` with the `g` or
     * `y` flag (and then updates `lastIndex`), from the start otherwise.
     */
    public function exec(str:String):Null<RegExpExecArray> {
        #if js
        final m = native.exec(str);
        return m == null ? null : cast m;
        #else
        final useLastIndex = (global || sticky);
        final start = useLastIndex ? lastIndex : 0;
        if (start < 0 || start > str.length) {
            if (useLastIndex) {
                lastIndex = 0;
            }
            return null;
        }
        if (!ereg.matchSub(str, start, str.length - start)) {
            if (useLastIndex) {
                lastIndex = 0;
            }
            return null;
        }
        final pos = ereg.matchedPos();
        if (sticky && pos.pos != start) {
            lastIndex = 0;
            return null;
        }
        final values:Array<Null<String>> = [];
        for (i in 0...groupCount) {
            values.push(ereg.matched(i));
        }
        if (useLastIndex) {
            lastIndex = pos.pos + pos.len;
        }
        return cast new RegExpExecArrayData(values, pos.pos, str);
        #end
    }

    /**
     * Whether the regular expression matches `str` (updates `lastIndex` like
     * `exec`).
     */
    public function test(str:String):Bool {
        return exec(str) != null;
    }

    public function toString():String {
        return '/' + source + '/' + flags;
    }

    /**
     * Whether `c` is in JavaScript's `\w` class (`[A-Za-z0-9_]`).
     */
    public static inline function isAsciiWordChar(c:Int):Bool {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code;
    }

}

#if js
private typedef RegExpExecArrayImpl = js.lib.RegExp.RegExpMatch;
#else
private typedef RegExpExecArrayImpl = RegExpExecArrayData;

/**
 * The data of a match on the native targets.
 */
@:allow(cityscape.base.common.RegExp)
class RegExpExecArrayData {

    public final values:Array<Null<String>>;

    public final index:Int;

    public final input:String;

    function new(values:Array<Null<String>>, index:Int, input:String) {
        this.values = values;
        this.index = index;
        this.input = input;
    }

}
#end

/**
 * JavaScript's `RegExpExecArray`: `m[0]` is the match, `m[i]` the groups
 * (null when a group did not take part), `m.index` where the match starts
 * (in UTF-16 code units).
 */
abstract RegExpExecArray(RegExpExecArrayImpl) {

    public var index(get, never):Int;
    inline function get_index():Int {
        return this.index;
    }

    public var input(get, never):String;
    inline function get_input():String {
        return this.input;
    }

    public var length(get, never):Int;
    inline function get_length():Int {
        #if js
        return this.length;
        #else
        return this.values.length;
        #end
    }

    @:arrayAccess public inline function get(i:Int):Null<String> {
        #if js
        return this[i];
        #else
        return this.values[i];
        #end
    }

}

#if !js
/**
 * Translates a JavaScript regular expression source into a PCRE2 pattern
 * with the same meaning (see `RegExp`).
 */
private class JsToPcre {

    static inline final WORD = 'A-Za-z0-9_';

    static inline final NOT_WORD = '\\x{0}-\\x{2F}\\x{3A}-\\x{40}\\x{5B}-\\x{5E}\\x{60}\\x{7B}-\\x{10FFFF}';

    static inline final DIGIT = '0-9';

    static inline final NOT_DIGIT = '\\x{0}-\\x{2F}\\x{3A}-\\x{10FFFF}';

    static inline final SPACE = '\\x{9}-\\x{D}\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}';

    static inline final NOT_SPACE = '\\x{0}-\\x{8}\\x{E}-\\x{1F}\\x{21}-\\x{9F}\\x{A1}-\\x{167F}\\x{1681}-\\x{1FFF}\\x{200B}-\\x{2027}\\x{202A}-\\x{202E}\\x{2030}-\\x{205E}\\x{2060}-\\x{2FFF}\\x{3001}-\\x{FEFE}\\x{FF00}-\\x{10FFFF}';

    static inline final LINE_TERMINATORS = '\\n\\r\\x{2028}\\x{2029}';

    static inline final WORD_BOUNDARY = '(?:(?<=[A-Za-z0-9_])(?![A-Za-z0-9_])|(?<![A-Za-z0-9_])(?=[A-Za-z0-9_]))';

    static inline final NOT_WORD_BOUNDARY = '(?:(?<=[A-Za-z0-9_])(?=[A-Za-z0-9_])|(?<![A-Za-z0-9_])(?![A-Za-z0-9_]))';

    final src:String;

    final multiline:Bool;

    final dotAll:Bool;

    final unicode:Bool;

    var pos:Int = 0;

    final out:StringBuf = new StringBuf();

    public var groupCount(default, null):Int = 0;

    public function new(src:String, multiline:Bool, dotAll:Bool, unicode:Bool) {
        this.src = src;
        this.multiline = multiline;
        this.dotAll = dotAll;
        this.unicode = unicode;
    }

    public function translate():String {
        if (src.length == 0) {
            return '(?:)';
        }
        final len = src.length;
        while (pos < len) {
            final c = StringTools.fastCodeAt(src, pos);
            switch c {
                case '\\'.code:
                    translateEscape(false);
                case '['.code:
                    translateClass();
                case '.'.code:
                    pos++;
                    out.add(dotAll ? '[\\x{0}-\\x{10FFFF}]' : '[^' + LINE_TERMINATORS + ']');
                case '^'.code:
                    pos++;
                    out.add(multiline ? '(?<![^' + LINE_TERMINATORS + '])' : '\\A');
                case '$'.code:
                    pos++;
                    out.add(multiline ? '(?![^' + LINE_TERMINATORS + '])' : '\\z');
                case '('.code:
                    pos++;
                    if (pos < len && StringTools.fastCodeAt(src, pos) == '?'.code) {
                        if (pos + 2 < len && StringTools.fastCodeAt(src, pos + 1) == '<'.code) {
                            final d = StringTools.fastCodeAt(src, pos + 2);
                            if (d != '='.code && d != '!'.code) {
                                // Named group
                                groupCount++;
                            }
                        }
                    }
                    else {
                        groupCount++;
                    }
                    out.addChar('('.code);
                default:
                    addCodeUnitsUntilSpecial();
            }
        }
        return out.toString();
    }

    /**
     * Copies the source as it is up to the next character that needs a
     * translation.
     */
    function addCodeUnitsUntilSpecial():Void {
        final start = pos;
        final len = src.length;
        while (pos < len) {
            final c = StringTools.fastCodeAt(src, pos);
            if (c == '\\'.code || c == '['.code || c == '.'.code || c == '^'.code || c == '$'.code || c == '('.code) {
                break;
            }
            pos++;
        }
        out.addSub(src, start, pos - start);
    }

    static inline function isHex(c:Int):Bool {
        return (c >= '0'.code && c <= '9'.code) || (c >= 'a'.code && c <= 'f'.code) || (c >= 'A'.code && c <= 'F'.code);
    }

    /**
     * Reads `\uXXXX` or `\u{X...}` at `pos` (on the backslash). Returns the
     * code unit or code point, -1 if it is not one (`\u` alone is a literal
     * `u` without the `u` flag).
     */
    function readUnicodeEscape():Int {
        final len = src.length;
        if (pos + 1 < len && StringTools.fastCodeAt(src, pos + 1) == 'u'.code) {
            if (pos + 5 < len && isHex(StringTools.fastCodeAt(src, pos + 2)) && isHex(StringTools.fastCodeAt(src, pos + 3)) && isHex(StringTools.fastCodeAt(src, pos + 4)) && isHex(StringTools.fastCodeAt(src, pos + 5))) {
                final value = Std.parseInt('0x' + src.substr(pos + 2, 4));
                pos += 6;
                return value;
            }
            if (unicode && pos + 2 < len && StringTools.fastCodeAt(src, pos + 2) == '{'.code) {
                final end = src.indexOf('}', pos + 3);
                if (end > pos + 3) {
                    final value = Std.parseInt('0x' + src.substring(pos + 3, end));
                    if (value != null) {
                        pos = end + 1;
                        return value;
                    }
                }
            }
        }
        return -1;
    }

    /**
     * A `\uXXXX` escape, joined with the low surrogate escape that follows a
     * high surrogate one.
     */
    function readCodePointEscape():Int {
        var value = readUnicodeEscape();
        if (value >= 0xD800 && value <= 0xDBFF) {
            final save = pos;
            final low = (pos < src.length && StringTools.fastCodeAt(src, pos) == '\\'.code) ? readUnicodeEscape() : -1;
            if (low >= 0xDC00 && low <= 0xDFFF) {
                value = ((value - 0xD800) << 10) + (low - 0xDC00) + 0x10000;
            }
            else {
                pos = save;
                throw 'RegExp: lone surrogate escapes are not supported on this target';
            }
        }
        else if (value >= 0xDC00 && value <= 0xDFFF) {
            throw 'RegExp: lone surrogate escapes are not supported on this target';
        }
        return value;
    }

    static function hexEscape(value:Int):String {
        return '\\x{' + StringTools.hex(value) + '}';
    }

    /**
     * Translates the escape at `pos` (on the backslash), outside or inside a
     * character class.
     */
    function translateEscape(inClass:Bool):Void {
        final len = src.length;
        if (pos + 1 >= len) {
            // A trailing backslash: invalid in JavaScript too
            throw 'RegExp: \\ at end of pattern';
        }
        final c = StringTools.fastCodeAt(src, pos + 1);
        switch c {
            case 'd'.code:
                pos += 2;
                out.add(inClass ? DIGIT : '[' + DIGIT + ']');
            case 'D'.code:
                pos += 2;
                out.add(inClass ? NOT_DIGIT : '[^' + DIGIT + ']');
            case 'w'.code:
                pos += 2;
                out.add(inClass ? WORD : '[' + WORD + ']');
            case 'W'.code:
                pos += 2;
                out.add(inClass ? NOT_WORD : '[^' + WORD + ']');
            case 's'.code:
                pos += 2;
                out.add(inClass ? SPACE : '[' + SPACE + ']');
            case 'S'.code:
                pos += 2;
                out.add(inClass ? NOT_SPACE : '[^' + SPACE + ']');
            case 'b'.code:
                pos += 2;
                out.add(inClass ? '\\x{8}' : WORD_BOUNDARY);
            case 'B'.code if (!inClass):
                pos += 2;
                out.add(NOT_WORD_BOUNDARY);
            case 'v'.code:
                pos += 2;
                out.add('\\x{B}');
            case 'u'.code:
                final value = readCodePointEscape();
                if (value == -1) {
                    // `\u` alone: the letter u
                    pos += 2;
                    out.add('u');
                }
                else {
                    out.add(hexEscape(value));
                }
            case 'x'.code:
                if (pos + 3 < len && isHex(StringTools.fastCodeAt(src, pos + 2)) && isHex(StringTools.fastCodeAt(src, pos + 3))) {
                    out.add('\\x{' + src.substr(pos + 2, 2) + '}');
                    pos += 4;
                }
                else {
                    pos += 2;
                    out.add('x');
                }
            case '0'.code if (pos + 2 >= len || !(StringTools.fastCodeAt(src, pos + 2) >= '0'.code && StringTools.fastCodeAt(src, pos + 2) <= '9'.code)):
                pos += 2;
                out.add('\\x{0}');
            case 'c'.code:
                if (pos + 2 < len) {
                    final l = StringTools.fastCodeAt(src, pos + 2);
                    if ((l >= 'a'.code && l <= 'z'.code) || (l >= 'A'.code && l <= 'Z'.code)) {
                        out.add(hexEscape(l % 32));
                        pos += 3;
                        return;
                    }
                }
                pos += 1;
                out.add('\\\\');
            case 'p'.code | 'P'.code if (unicode && pos + 2 < len && StringTools.fastCodeAt(src, pos + 2) == '{'.code):
                final end = src.indexOf('}', pos + 3);
                if (end == -1) {
                    throw 'RegExp: invalid property name';
                }
                var name = src.substring(pos + 3, end);
                final eq = name.indexOf('=');
                if (eq != -1) {
                    name = name.substr(eq + 1);
                }
                out.add('\\' + String.fromCharCode(c) + '{' + name + '}');
                pos = end + 1;
            case 'k'.code:
                // Named backreference, same syntax
                pos += 2;
                out.add('\\k');
            case 't'.code | 'n'.code | 'r'.code | 'f'.code:
                pos += 2;
                out.add('\\' + String.fromCharCode(c));
            case '/'.code:
                pos += 2;
                out.add('/');
            case _ if (c >= '1'.code && c <= '9'.code):
                // Backreference (or octal escape without the u flag)
                pos += 2;
                out.add('\\' + String.fromCharCode(c));
            case _ if ((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code)):
                // Identity escape of a letter: the letter itself
                pos += 2;
                out.addChar(c);
            case _:
                // Escaped syntax character or other symbol: literal in both
                pos += 2;
                out.addChar('\\'.code);
                out.addChar(c);
        }
    }

    /**
     * Translates the character class at `pos` (on the opening bracket).
     */
    function translateClass():Void {
        final len = src.length;
        pos++;
        var negated = false;
        if (pos < len && StringTools.fastCodeAt(src, pos) == '^'.code) {
            negated = true;
            pos++;
        }
        if (pos < len && StringTools.fastCodeAt(src, pos) == ']'.code) {
            // `[]` matches nothing, `[^]` any character
            pos++;
            out.add(negated ? '[\\x{0}-\\x{10FFFF}]' : '(?!)');
            return;
        }
        out.add(negated ? '[^' : '[');
        while (pos < len) {
            final c = StringTools.fastCodeAt(src, pos);
            if (c == ']'.code) {
                pos++;
                out.addChar(']'.code);
                return;
            }
            if (c == '\\'.code) {
                final classEscape = isClassEscapeAt(pos);
                translateEscape(true);
                if (classEscape && pos + 1 < len && StringTools.fastCodeAt(src, pos) == '-'.code && StringTools.fastCodeAt(src, pos + 1) != ']'.code) {
                    // `[\w-?]`: a hyphen after a class escape is a literal in
                    // JavaScript (Annex B), a range in PCRE once `\w` is expanded
                    pos++;
                    out.add('\\-');
                }
                continue;
            }
            if (c == '-'.code && isClassEscapeAt(pos + 1)) {
                // `[a-\d]`: a hyphen before a class escape is a literal too
                pos++;
                out.add('\\-');
                continue;
            }
            if (c == '['.code) {
                // A literal in JavaScript, never a POSIX class
                pos++;
                out.add('\\[');
                continue;
            }
            pos++;
            out.addChar(c);
        }
        throw 'RegExp: missing terminating ] for character class';
    }

    /**
     * Whether a class escape (`\d`, `\D`, `\w`, `\W`, `\s`, `\S`) starts at `p`.
     */
    function isClassEscapeAt(p:Int):Bool {
        if (p + 1 >= src.length || StringTools.fastCodeAt(src, p) != '\\'.code) {
            return false;
        }
        return switch StringTools.fastCodeAt(src, p + 1) {
            case 'd'.code | 'D'.code | 'w'.code | 'W'.code | 's'.code | 'S'.code: true;
            case _: false;
        }
    }

}
#end
