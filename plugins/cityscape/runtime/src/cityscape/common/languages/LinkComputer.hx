// Ported from vscode src/vs/editor/common/languages/linkComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.CharCode;
import cityscape.common.Languages.ILink;
import cityscape.common.core.CharacterClassifier;
import haxe.io.Bytes;

/**
 * The lines a link computer reads (a model, or the lines of a test).
 */
interface ILinkComputerTarget {
    function getLineCount():Int;
    function getLineContent(lineNumber:Int):String;
}

enum abstract State(Int) from Int to Int {
    var Invalid = 0;
    var Start = 1;
    var H = 2;
    var HT = 3;
    var HTT = 4;
    var HTTP = 5;
    var F = 6;
    var FI = 7;
    var FIL = 8;
    var BeforeColon = 9;
    var AfterColon = 10;
    var AlmostThere = 11;
    var End = 12;
    var Accept = 13;
    var LastKnownState = 14; // marker, custom states may follow
}

/**
 * An edge of the state machine (Monaco's `[State, number, State]` tuple).
 */
class Edge {
    public final from:Int;
    public final chCode:Int;
    public final to:Int;

    public function new(from:Int, chCode:Int, to:Int) {
        this.from = from;
        this.chCode = chCode;
        this.to = to;
    }
}

class Uint8Matrix {

    final _data:Bytes;
    public final rows:Int;
    public final cols:Int;

    public function new(rows:Int, cols:Int, defaultValue:Int) {
        final data = Bytes.alloc(rows * cols);
        data.fill(0, rows * cols, defaultValue);

        this._data = data;
        this.rows = rows;
        this.cols = cols;
    }

    public inline function get(row:Int, col:Int):Int {
        return this._data.get(row * this.cols + col);
    }

    public inline function set(row:Int, col:Int, value:Int):Void {
        this._data.set(row * this.cols + col, value);
    }
}

class StateMachine {

    final _states:Uint8Matrix;
    final _maxCharCode:Int;

    public function new(edges:Array<Edge>) {
        var maxCharCode = 0;
        var maxState:Int = State.Invalid;
        for (edge in edges) {
            if (edge.chCode > maxCharCode) {
                maxCharCode = edge.chCode;
            }
            if (edge.from > maxState) {
                maxState = edge.from;
            }
            if (edge.to > maxState) {
                maxState = edge.to;
            }
        }

        maxCharCode++;
        maxState++;

        final states = new Uint8Matrix(maxState, maxCharCode, State.Invalid);
        for (edge in edges) {
            states.set(edge.from, edge.chCode, edge.to);
        }

        this._states = states;
        this._maxCharCode = maxCharCode;
    }

    public function nextState(currentState:State, chCode:Int):State {
        if (chCode < 0 || chCode >= this._maxCharCode) {
            return State.Invalid;
        }
        return this._states.get(currentState, chCode);
    }
}

enum abstract CharacterClass(Int) from Int to Int {
    var None = 0;
    var ForceTermination = 1;
    var CannotEndIn = 2;
}

/**
 * The default link computer (http, https and file links in the text).
 */
class LinkComputer {

    // State machine for http:// or https:// or file:// (immutable once built)
    static var _stateMachine:Null<StateMachine> = null;

    static function getStateMachine():StateMachine {
        if (_stateMachine == null) {
            _stateMachine = new StateMachine([
                new Edge(State.Start, CharCode.h, State.H),
                new Edge(State.Start, CharCode.H, State.H),
                new Edge(State.Start, CharCode.f, State.F),
                new Edge(State.Start, CharCode.F, State.F),

                new Edge(State.H, CharCode.t, State.HT),
                new Edge(State.H, CharCode.T, State.HT),

                new Edge(State.HT, CharCode.t, State.HTT),
                new Edge(State.HT, CharCode.T, State.HTT),

                new Edge(State.HTT, CharCode.p, State.HTTP),
                new Edge(State.HTT, CharCode.P, State.HTTP),

                new Edge(State.HTTP, CharCode.s, State.BeforeColon),
                new Edge(State.HTTP, CharCode.S, State.BeforeColon),
                new Edge(State.HTTP, CharCode.Colon, State.AfterColon),

                new Edge(State.F, CharCode.i, State.FI),
                new Edge(State.F, CharCode.I, State.FI),

                new Edge(State.FI, CharCode.l, State.FIL),
                new Edge(State.FI, CharCode.L, State.FIL),

                new Edge(State.FIL, CharCode.e, State.BeforeColon),
                new Edge(State.FIL, CharCode.E, State.BeforeColon),

                new Edge(State.BeforeColon, CharCode.Colon, State.AfterColon),

                new Edge(State.AfterColon, CharCode.Slash, State.AlmostThere),

                new Edge(State.AlmostThere, CharCode.Slash, State.End),
            ]);
        }
        return _stateMachine;
    }

    // The character classes (immutable once built)
    static var _classifier:Null<CharacterClassifier> = null;

    static function getClassifier():CharacterClassifier {
        if (_classifier == null) {
            final classifier = new CharacterClassifier(CharacterClass.None);

            // allow-any-unicode-next-line
            final FORCE_TERMINATION_CHARACTERS = ' \t<>\'\"、。｡､，．：；‘〈「『〔（［｛｢｣｝］）〕』」〉’｀～…';
            for (i in 0...FORCE_TERMINATION_CHARACTERS.length) {
                classifier.set(StringTools.fastCodeAt(FORCE_TERMINATION_CHARACTERS, i), CharacterClass.ForceTermination);
            }

            final CANNOT_END_WITH_CHARACTERS = '.,;:';
            for (i in 0...CANNOT_END_WITH_CHARACTERS.length) {
                classifier.set(StringTools.fastCodeAt(CANNOT_END_WITH_CHARACTERS, i), CharacterClass.CannotEndIn);
            }
            _classifier = classifier;
        }
        return _classifier;
    }

    /**
     * JavaScript's `charCodeAt`: NaN (here -1, a class of none) out of range.
     */
    static inline function charCodeAt(line:String, index:Int):Int {
        return index >= 0 && index < line.length ? StringTools.fastCodeAt(line, index) : -1;
    }

    static function _createLink(classifier:CharacterClassifier, line:String, lineNumber:Int, linkBeginIndex:Int, linkEndIndex:Int):ILink {
        // Do not allow to end link in certain characters...
        var lastIncludedCharIndex = linkEndIndex - 1;
        do {
            final chCode = charCodeAt(line, lastIncludedCharIndex);
            final chClass:CharacterClass = classifier.get(chCode);
            if (chClass != CharacterClass.CannotEndIn) {
                break;
            }
            lastIncludedCharIndex--;
        } while (lastIncludedCharIndex > linkBeginIndex);

        // Handle links enclosed in parens, square brackets and curlys.
        if (linkBeginIndex > 0) {
            final charCodeBeforeLink = charCodeAt(line, linkBeginIndex - 1);
            final lastCharCodeInLink = charCodeAt(line, lastIncludedCharIndex);

            if (
                (charCodeBeforeLink == CharCode.OpenParen && lastCharCodeInLink == CharCode.CloseParen)
                || (charCodeBeforeLink == CharCode.OpenSquareBracket && lastCharCodeInLink == CharCode.CloseSquareBracket)
                || (charCodeBeforeLink == CharCode.OpenCurlyBrace && lastCharCodeInLink == CharCode.CloseCurlyBrace)
            ) {
                // Do not end in ) if ( is before the link start
                // Do not end in ] if [ is before the link start
                // Do not end in } if { is before the link start
                lastIncludedCharIndex--;
            }
        }

        return {
            range: {
                startLineNumber: lineNumber,
                startColumn: linkBeginIndex + 1,
                endLineNumber: lineNumber,
                endColumn: lastIncludedCharIndex + 2
            },
            url: line.substring(linkBeginIndex, lastIncludedCharIndex + 1)
        };
    }

    public static function computeLinks(model:ILinkComputerTarget, ?stateMachine:StateMachine):Array<ILink> {
        if (stateMachine == null) {
            stateMachine = getStateMachine();
        }
        final classifier = getClassifier();

        final result:Array<ILink> = [];
        for (i in 1...model.getLineCount() + 1) {
            final line = model.getLineContent(i);
            final len = line.length;

            var j = 0;
            var linkBeginIndex = 0;
            var linkBeginChCode = 0;
            var state:State = State.Start;
            var hasOpenParens = false;
            var hasOpenSquareBracket = false;
            var inSquareBrackets = false;
            var hasOpenCurlyBracket = false;

            while (j < len) {

                var resetStateMachine = false;
                final chCode = StringTools.fastCodeAt(line, j);

                if (state == State.Accept) {
                    var chClass:CharacterClass;
                    switch (chCode) {
                        case CharCode.OpenParen:
                            hasOpenParens = true;
                            chClass = CharacterClass.None;
                        case CharCode.CloseParen:
                            chClass = (hasOpenParens ? CharacterClass.None : CharacterClass.ForceTermination);
                        case CharCode.OpenSquareBracket:
                            inSquareBrackets = true;
                            hasOpenSquareBracket = true;
                            chClass = CharacterClass.None;
                        case CharCode.CloseSquareBracket:
                            inSquareBrackets = false;
                            chClass = (hasOpenSquareBracket ? CharacterClass.None : CharacterClass.ForceTermination);
                        case CharCode.OpenCurlyBrace:
                            hasOpenCurlyBracket = true;
                            chClass = CharacterClass.None;
                        case CharCode.CloseCurlyBrace:
                            chClass = (hasOpenCurlyBracket ? CharacterClass.None : CharacterClass.ForceTermination);

                        // The following three rules make it that ' or " or ` are allowed inside links
                        // only if the link is wrapped by some other quote character
                        case CharCode.SingleQuote | CharCode.DoubleQuote | CharCode.BackTick:
                            if (linkBeginChCode == chCode) {
                                chClass = CharacterClass.ForceTermination;
                            }
                            else if (linkBeginChCode == CharCode.SingleQuote || linkBeginChCode == CharCode.DoubleQuote || linkBeginChCode == CharCode.BackTick) {
                                chClass = CharacterClass.None;
                            }
                            else {
                                chClass = CharacterClass.ForceTermination;
                            }
                        case CharCode.Asterisk:
                            // `*` terminates a link if the link began with `*`
                            chClass = (linkBeginChCode == CharCode.Asterisk) ? CharacterClass.ForceTermination : CharacterClass.None;
                        case CharCode.Pipe:
                            // `|` terminates a link if the link began with `|`
                            chClass = (linkBeginChCode == CharCode.Pipe) ? CharacterClass.ForceTermination : CharacterClass.None;
                        case CharCode.Space:
                            // ` ` allow space in between [ and ]
                            chClass = (inSquareBrackets ? CharacterClass.None : CharacterClass.ForceTermination);
                        default:
                            chClass = classifier.get(chCode);
                    }

                    // Check if character terminates link
                    if (chClass == CharacterClass.ForceTermination) {
                        result.push(_createLink(classifier, line, i, linkBeginIndex, j));
                        resetStateMachine = true;
                    }
                }
                else if (state == State.End) {

                    var chClass:CharacterClass;
                    if (chCode == CharCode.OpenSquareBracket) {
                        // Allow for the authority part to contain ipv6 addresses which contain [ and ]
                        hasOpenSquareBracket = true;
                        chClass = CharacterClass.None;
                    }
                    else {
                        chClass = classifier.get(chCode);
                    }

                    // Check if character terminates link
                    if (chClass == CharacterClass.ForceTermination) {
                        resetStateMachine = true;
                    }
                    else {
                        state = State.Accept;
                    }
                }
                else {
                    state = stateMachine.nextState(state, chCode);
                    if (state == State.Invalid) {
                        resetStateMachine = true;
                    }
                }

                if (resetStateMachine) {
                    state = State.Start;
                    hasOpenParens = false;
                    hasOpenSquareBracket = false;
                    hasOpenCurlyBracket = false;

                    // Record where the link started
                    linkBeginIndex = j + 1;
                    linkBeginChCode = chCode;
                }

                j++;
            }

            if (state == State.Accept) {
                result.push(_createLink(classifier, line, i, linkBeginIndex, len));
            }

        }

        return result;
    }
}

/**
 * The module function of linkComputer.ts.
 */
class LinkComputerUtils {

    /**
     * Returns an array of all links contains in the provided
     * document. *Note* that this operation is computational
     * expensive and should not run in the UI thread.
     */
    public static function computeLinks(model:Null<ILinkComputerTarget>):Array<ILink> {
        if (model == null) {
            // Unknown caller!
            return [];
        }
        return LinkComputer.computeLinks(model);
    }

}

/**
 * The lines of a text model as a link computer target (Monaco's worker
 * mirror model).
 */
class TextModelLinkComputerTarget implements ILinkComputerTarget {

    final model:cityscape.common.Model.ITextModel;

    public function new(model:cityscape.common.Model.ITextModel) {
        this.model = model;
    }

    public function getLineCount():Int {
        return model.getLineCount();
    }

    public function getLineContent(lineNumber:Int):String {
        return model.getLineContent(lineNumber);
    }

}
