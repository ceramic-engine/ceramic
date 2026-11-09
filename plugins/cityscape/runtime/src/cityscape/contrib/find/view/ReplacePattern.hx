// Ported from vscode src/vs/editor/contrib/find/browser/replacePattern.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.find.view;

import cityscape.base.common.CharCode;
import cityscape.base.common.Search;

/**
 * A replace string, parsed: a static value, or pieces that refer to the
 * groups of a match (`$1`, `$&`) with case operations (`\u`, `\U`, `\l`,
 * `\L`).
 *
 * Monaco keeps the state in a `StaticValueReplacePattern` or a
 * `DynamicPiecesReplacePattern`; here it is the two fields `_staticValue`
 * (static) and `_pieces` (dynamic).
 */
class ReplacePattern {

    public static function fromStaticValue(value:String):ReplacePattern {
        return new ReplacePattern([ReplacePiece.staticValueStatic(value)]);
    }

    final _staticValue:Null<String>;
    final _pieces:Null<Array<ReplacePiece>>;

    public var hasReplacementPatterns(get, never):Bool;
    function get_hasReplacementPatterns():Bool {
        return (this._pieces != null);
    }

    public function new(pieces:Null<Array<ReplacePiece>>) {
        if (pieces == null || pieces.length == 0) {
            this._staticValue = '';
            this._pieces = null;
        } else if (pieces.length == 1 && pieces[0].staticValue != null) {
            this._staticValue = pieces[0].staticValue;
            this._pieces = null;
        } else {
            this._staticValue = null;
            this._pieces = pieces;
        }
    }

    public function buildReplaceString(matches:Null<Array<String>>, ?preserveCase:Bool):String {
        if (this._pieces == null) {
            if (preserveCase == true) {
                return Search.buildReplaceStringWithCasePreserved(matches, this._staticValue);
            } else {
                return this._staticValue;
            }
        }

        var result = '';
        for (i in 0...this._pieces.length) {
            final piece = this._pieces[i];
            if (piece.staticValue != null) {
                // static value ReplacePiece
                result += piece.staticValue;
                continue;
            }

            // match index ReplacePiece
            var match:String = ReplacePattern._substitute(piece.matchIndex, matches);
            if (piece.caseOps != null && piece.caseOps.length > 0) {
                final repl:Array<String> = [];
                final lenOps:Int = piece.caseOps.length;
                var opIdx:Int = 0;
                for (idx in 0...match.length) {
                    if (opIdx >= lenOps) {
                        repl.push(match.substr(idx));
                        break;
                    }
                    switch (piece.caseOps[opIdx]) {
                        case 'U':
                            repl.push(match.charAt(idx).toUpperCase());
                        case 'u':
                            repl.push(match.charAt(idx).toUpperCase());
                            opIdx++;
                        case 'L':
                            repl.push(match.charAt(idx).toLowerCase());
                        case 'l':
                            repl.push(match.charAt(idx).toLowerCase());
                            opIdx++;
                        default:
                            repl.push(match.charAt(idx));
                    }
                }
                match = repl.join('');
            }
            result += match;
        }

        return result;
    }

    static function _substitute(matchIndex:Int, matches:Null<Array<String>>):String {
        if (matches == null) {
            return '';
        }
        if (matchIndex == 0) {
            return matches[0];
        }

        var remainder = '';
        while (matchIndex > 0) {
            if (matchIndex < matches.length) {
                // A match can be undefined
                final match = matches[matchIndex];
                return (match != null ? match : '') + remainder;
            }
            remainder = Std.string(matchIndex % 10) + remainder;
            matchIndex = Std.int(matchIndex / 10);
        }
        return '$' + remainder;
    }

}

/**
 * A replace piece can either be a static string or an index to a specific match.
 */
class ReplacePiece {

    public static function staticValueStatic(value:String):ReplacePiece {
        return new ReplacePiece(value, -1, null);
    }

    public static function matchIndexStatic(index:Int):ReplacePiece {
        return new ReplacePiece(null, index, null);
    }

    public static function caseOpsStatic(index:Int, caseOps:Array<String>):ReplacePiece {
        return new ReplacePiece(null, index, caseOps);
    }

    public final staticValue:Null<String>;
    public final matchIndex:Int;
    public final caseOps:Null<Array<String>>;

    function new(staticValue:Null<String>, matchIndex:Int, caseOps:Null<Array<String>>) {
        this.staticValue = staticValue;
        this.matchIndex = matchIndex;
        if (caseOps == null || caseOps.length == 0) {
            this.caseOps = null;
        } else {
            this.caseOps = caseOps.slice(0);
        }
    }

}

class ReplacePieceBuilder {

    final _source:String;
    var _lastCharIndex:Int;
    final _result:Array<ReplacePiece>;
    var _resultLen:Int;
    var _currentStaticPiece:String;

    public function new(source:String) {
        this._source = source;
        this._lastCharIndex = 0;
        this._result = [];
        this._resultLen = 0;
        this._currentStaticPiece = '';
    }

    public function emitUnchanged(toCharIndex:Int):Void {
        this._emitStatic(this._source.substring(this._lastCharIndex, toCharIndex));
        this._lastCharIndex = toCharIndex;
    }

    public function emitStatic(value:String, toCharIndex:Int):Void {
        this._emitStatic(value);
        this._lastCharIndex = toCharIndex;
    }

    function _emitStatic(value:String):Void {
        if (value.length == 0) {
            return;
        }
        this._currentStaticPiece += value;
    }

    public function emitMatchIndex(index:Int, toCharIndex:Int, caseOps:Array<String>):Void {
        if (this._currentStaticPiece.length != 0) {
            this._result[this._resultLen++] = ReplacePiece.staticValueStatic(this._currentStaticPiece);
            this._currentStaticPiece = '';
        }
        this._result[this._resultLen++] = ReplacePiece.caseOpsStatic(index, caseOps);
        this._lastCharIndex = toCharIndex;
    }

    public function finalize():ReplacePattern {
        this.emitUnchanged(this._source.length);
        if (this._currentStaticPiece.length != 0) {
            this._result[this._resultLen++] = ReplacePiece.staticValueStatic(this._currentStaticPiece);
            this._currentStaticPiece = '';
        }
        return new ReplacePattern(this._result);
    }

}

/**
 * Module functions of replacePattern.ts.
 */
class ReplacePatternParser {

    /**
     * \n			=> inserts a LF
     * \t			=> inserts a TAB
     * \\			=> inserts a "\".
     * \u			=> upper-cases one character in a match.
     * \U			=> upper-cases ALL remaining characters in a match.
     * \l			=> lower-cases one character in a match.
     * \L			=> lower-cases ALL remaining characters in a match.
     * $$			=> inserts a "$".
     * $& and $0	=> inserts the matched substring.
     * $n			=> Where n is a non-negative integer lesser than 100, inserts the nth parenthesized submatch string
     * everything else stays untouched
     *
     * Also see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace#Specifying_a_string_as_a_parameter
     */
    public static function parseReplaceString(replaceString:Null<String>):ReplacePattern {
        if (replaceString == null || replaceString.length == 0) {
            return new ReplacePattern(null);
        }

        final caseOps:Array<String> = [];
        final result = new ReplacePieceBuilder(replaceString);

        final len = replaceString.length;
        var i = 0;
        while (i < len) {
            final chCode = StringTools.fastCodeAt(replaceString, i);

            if (chCode == CharCode.Backslash) {

                // move to next char
                i++;

                if (i >= len) {
                    // string ends with a \
                    break;
                }

                final nextChCode = StringTools.fastCodeAt(replaceString, i);

                switch (nextChCode) {
                    case CharCode.Backslash:
                        // \\ => inserts a "\"
                        result.emitUnchanged(i - 1);
                        result.emitStatic('\\', i + 1);
                    case CharCode.n:
                        // \n => inserts a LF
                        result.emitUnchanged(i - 1);
                        result.emitStatic('\n', i + 1);
                    case CharCode.t:
                        // \t => inserts a TAB
                        result.emitUnchanged(i - 1);
                        result.emitStatic('\t', i + 1);
                    // Case modification of string replacements, patterned after Boost, but only applied
                    // to the replacement text, not subsequent content.
                    // \u => upper-cases one character.
                    // \U => upper-cases ALL following characters.
                    // \l => lower-cases one character.
                    // \L => lower-cases ALL following characters.
                    case CharCode.u | CharCode.U | CharCode.l | CharCode.L:
                        result.emitUnchanged(i - 1);
                        result.emitStatic('', i + 1);
                        caseOps.push(String.fromCharCode(nextChCode));
                    case _:
                }

                i++;
                continue;
            }

            if (chCode == CharCode.DollarSign) {

                // move to next char
                i++;

                if (i >= len) {
                    // string ends with a $
                    break;
                }

                final nextChCode = StringTools.fastCodeAt(replaceString, i);

                if (nextChCode == CharCode.DollarSign) {
                    // $$ => inserts a "$"
                    result.emitUnchanged(i - 1);
                    result.emitStatic('$', i + 1);
                    i++;
                    continue;
                }

                if (nextChCode == CharCode.Digit0 || nextChCode == CharCode.Ampersand) {
                    // $& and $0 => inserts the matched substring.
                    result.emitUnchanged(i - 1);
                    result.emitMatchIndex(0, i + 1, caseOps);
                    caseOps.resize(0);
                    i++;
                    continue;
                }

                if ((CharCode.Digit1 : Int) <= nextChCode && nextChCode <= (CharCode.Digit9 : Int)) {
                    // $n

                    var matchIndex = nextChCode - CharCode.Digit0;

                    // peek next char to probe for $nn
                    if (i + 1 < len) {
                        final nextNextChCode = StringTools.fastCodeAt(replaceString, i + 1);
                        if ((CharCode.Digit0 : Int) <= nextNextChCode && nextNextChCode <= (CharCode.Digit9 : Int)) {
                            // $nn

                            // move to next char
                            i++;
                            matchIndex = matchIndex * 10 + (nextNextChCode - CharCode.Digit0);

                            result.emitUnchanged(i - 2);
                            result.emitMatchIndex(matchIndex, i + 1, caseOps);
                            caseOps.resize(0);
                            i++;
                            continue;
                        }
                    }

                    result.emitUnchanged(i - 1);
                    result.emitMatchIndex(matchIndex, i + 1, caseOps);
                    caseOps.resize(0);
                    i++;
                    continue;
                }
            }
            i++;
        }

        return result.finalize();
    }

}
