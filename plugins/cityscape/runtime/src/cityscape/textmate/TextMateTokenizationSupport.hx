// Ported from vscode src/vs/workbench/services/textMate/browser/tokenizationSupport/textMateTokenizationSupport.ts
// and tokenizationSupportWithLineLimit.ts (not in the monaco-editor build; loreline-monaco's provider.js does the same with fewer options).
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.textmate;

import cityscape.base.common.Event;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.languages.NullTokenize;
import textmate.IGrammar;

/**
 * A TextMate grammar as an `ITokenizationSupport`: `grammar.tokenizeLine2`
 * gives the binary tokens (already in Monaco's format) and the end state.
 *
 * Like VS Code's `TextMateTokenizationSupport`:
 * - the end state is the start state object when they are equal (saves an
 *   object, and the state store compares states with `equals` anyway);
 * - with a time limit, a line that takes too long keeps the tokens found so
 *   far and returns the state at the beginning of the line;
 * - when the grammar has embedded languages, `onDidEncounterLanguage` fires
 *   the first time a language id is seen in the tokens;
 * - with a line length limit (VS Code's `TokenizationSupportWithLineLimit`,
 *   `editor.maxTokenizationLineLength`), longer lines are not tokenized.
 *
 * loreline-monaco's provider.js uses no limit (`timeLimitMs` and
 * `maxTokenizationLineLength` 0) and always returns the new state: the
 * tokens are the same.
 */
class TextMateTokenizationSupport implements ITokenizationSupport {

    final _grammar:IGrammar;

    final _initialState:StateStack;

    final _containsEmbeddedLanguages:Bool;

    final _encodedLanguageId:LanguageId;

    final _seenLanguages:Array<Bool> = [];

    final _onDidEncounterLanguage = new Emitter<LanguageId>();

    public final onDidEncounterLanguage:Event<LanguageId>;

    /**
     * Milliseconds a line may take (0: no limit). VS Code uses 500.
     */
    public var timeLimitMs:Int;

    /**
     * Lines longer than this (UTF-16 units) are not tokenized (0: no limit).
     * VS Code's default `editor.maxTokenizationLineLength` is 20000.
     */
    public var maxTokenizationLineLength:Int;

    public function new(grammar:IGrammar, initialState:StateStack, containsEmbeddedLanguages:Bool, encodedLanguageId:LanguageId, timeLimitMs:Int = 0, maxTokenizationLineLength:Int = 0) {
        _grammar = grammar;
        _initialState = initialState;
        _containsEmbeddedLanguages = containsEmbeddedLanguages;
        _encodedLanguageId = encodedLanguageId;
        this.timeLimitMs = timeLimitMs;
        this.maxTokenizationLineLength = maxTokenizationLineLength;
        onDidEncounterLanguage = _onDidEncounterLanguage.event;
    }

    public function getInitialState():IState {
        return new TextMateState(_initialState);
    }

    public function tokenize(line:String, hasEOL:Bool, state:IState):TokenizationResult {
        throw 'Not supported!';
    }

    public function tokenizeEncoded(line:String, hasEOL:Bool, state:IState):EncodedTokenizationResult {
        if (maxTokenizationLineLength > 0 && line.length >= maxTokenizationLineLength) {
            return NullTokenize.nullTokenizeEncoded(_encodedLanguageId, state);
        }

        final stack = (cast state : TextMateState).stack;
        final textMateResult = _grammar.tokenizeLine2(line, stack, timeLimitMs);

        if (textMateResult.stoppedEarly) {
            // return the state at the beginning of the line
            return new EncodedTokenizationResult(textMateResult.tokens, state);
        }

        if (_containsEmbeddedLanguages) {
            final seenLanguages = _seenLanguages;
            final tokens = textMateResult.tokens;
            // Must check if any of the embedded languages was hit
            for (i in 0...(tokens.length >>> 1)) {
                final metadata:Int = tokens[(i << 1) + 1];
                final languageId:Int = TokenMetadata.getLanguageId(metadata);
                if (seenLanguages[languageId] != true) {
                    seenLanguages[languageId] = true;
                    _onDidEncounterLanguage.fire(languageId);
                }
            }
        }

        // try to save an object if possible
        final endState:IState = stack.equals(textMateResult.ruleStack) ? state : new TextMateState(textMateResult.ruleStack);
        return new EncodedTokenizationResult(textMateResult.tokens, endState);
    }

    public function createBackgroundTokenizer(textModel:ITextModel, store:IBackgroundTokenizationStore):Null<IBackgroundTokenizer> {
        return null;
    }

}

/**
 * A TextMate `StateStack` as an `IState`. In vscode, `StateStack` itself
 * implements `IState` (same `clone` and `equals`); the Haxe port of
 * vscode-textmate does not depend on Cityscape, so the stack is wrapped.
 * Stacks are immutable: `clone()` returns the same object, like
 * `StateStackImpl.clone()`.
 */
class TextMateState implements IState {

    public final stack:StateStack;

    public inline function new(stack:StateStack) {
        this.stack = stack;
    }

    public function clone():IState {
        return this;
    }

    public function equals(other:IState):Bool {
        if (other == this) {
            return true;
        }
        if (!Std.isOfType(other, TextMateState)) {
            return false;
        }
        return stack.equals((cast other : TextMateState).stack);
    }

}
