// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Color;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.EncodedTokenAttributes.LanguageId;
import cityscape.common.Model.ITextModel;
import cityscape.common.tokens.ContiguousMultilineTokens;
import haxe.io.UInt32Array;

/**
 * Types of languages.ts (tokenization and language features).
 *
 * TODO(step 4): the provider interfaces (hover, completion, definition...)
 * come with the contributions that use them.
 */

/**
 * Encodes and decodes language ids to and from the numbers stored in tokens.
 * @internal
 */
interface ILanguageIdCodec {
    function encodeLanguageId(languageId:String):LanguageId;
    function decodeLanguageId(languageId:LanguageId):String;
}

class Token {

    public final offset:Int;

    public final type:String;

    public final language:String;

    public function new(offset:Int, type:String, language:String) {
        this.offset = offset;
        this.type = type;
        this.language = language;
    }

    public function toString():String {
        return '(' + offset + ', ' + type + ')';
    }

}

/**
 * @internal
 */
class TokenizationResult {

    public final tokens:Array<Token>;

    public final endState:IState;

    public function new(tokens:Array<Token>, endState:IState) {
        this.tokens = tokens;
        this.endState = endState;
    }

}

/**
 * @internal
 */
class EncodedTokenizationResult {

    /**
     * The tokens in binary format. Each token occupies two array indices. For token i:
     *  - at offset 2*i => startIndex
     *  - at offset 2*i + 1 => metadata
     */
    public final tokens:UInt32Array;

    public final endState:IState;

    public function new(tokens:UInt32Array, endState:IState) {
        this.tokens = tokens;
        this.endState = endState;
    }

}

/**
 * Tokenizes the lines of a language.
 *
 * Monaco's optional members are required here: `createBackgroundTokenizer`
 * returns null when the default background tokenizer should be used.
 * `backgroundTokenizerShouldOnlyVerifyTokens` (a debugging aid that runs a
 * second tokenizer to compare its results) is not ported.
 * @internal
 */
interface ITokenizationSupport {

    function getInitialState():IState;

    function tokenize(line:String, hasEOL:Bool, state:IState):TokenizationResult;

    function tokenizeEncoded(line:String, hasEOL:Bool, state:IState):EncodedTokenizationResult;

    /**
     * Can return null if default background tokenization should be used.
     */
    function createBackgroundTokenizer(textModel:ITextModel, store:IBackgroundTokenizationStore):Null<IBackgroundTokenizer>;

}

/**
 * @internal
 */
interface IBackgroundTokenizer extends IDisposable {
    /**
     * Instructs the background tokenizer to set the tokens for the given range again.
     *
     * This might be necessary if the renderer overwrote those tokens with heuristically computed ones for some viewport,
     * when the change does not even propagate to that viewport.
     */
    function requestTokens(startLineNumber:Int, endLineNumberExclusive:Int):Void;
}

/**
 * @internal
 */
interface IBackgroundTokenizationStore {
    function setTokens(tokens:Array<ContiguousMultilineTokens>):Void;

    function setEndState(lineNumber:Int, state:IState):Void;

    /**
     * Should be called to indicate that the background tokenization has finished for now.
     * (This triggers bracket pair colorization to re-parse the bracket pairs with token information)
     */
    function backgroundTokenizationFinished():Void;
}

/**
 * The state of the tokenizer between two lines.
 * It is useful to store flags such as in multiline comment, etc.
 * The model will clone the previous line's state and pass it in to tokenize the next line.
 */
interface IState {
    function clone():IState;
    function equals(other:IState):Bool;
}

/**
 * @internal
 */
typedef ITokenizationSupportChangedEvent = {
    final changedLanguages:Array<String>;
    final changedColorMap:Bool;
}

/**
 * A tokenization support created on first use (Monaco's
 * `ILazyTokenizationSupport`, whose `tokenizationSupport` is a promise):
 * `createTokenizationSupport` returns the support, or null when there is none.
 * Cityscape creates it synchronously.
 * @internal
 */
interface ILazyTokenizationSupport<TSupport> {
    function getTokenizationSupport():Null<TSupport>;
}

/**
 * @internal
 */
class LazyTokenizationSupport<TSupport:IDisposable> implements IDisposable implements ILazyTokenizationSupport<TSupport> {

    final createSupport:() -> Null<TSupport>;

    var _tokenizationSupport:Null<TSupport> = null;

    var _created = false;

    public function new(createSupport:() -> Null<TSupport>) {
        this.createSupport = createSupport;
    }

    public function dispose():Void {
        if (_tokenizationSupport != null) {
            _tokenizationSupport.dispose();
        }
    }

    public function getTokenizationSupport():Null<TSupport> {
        if (!_created) {
            _created = true;
            _tokenizationSupport = createSupport();
        }
        return _tokenizationSupport;
    }

}

/**
 * The registry of tokenization supports and of the token color map.
 *
 * Monaco has one global `TokenizationRegistry`; Cityscape has one per context
 * (`Cityscape.tokenizationRegistry`).
 * @internal
 */
interface ITokenizationRegistry<TSupport> {

    /**
     * An event triggered when:
     *  - a tokenization support is registered, unregistered or changed.
     *  - the color map is changed.
     */
    var onDidChange(default, null):Event<ITokenizationSupportChangedEvent>;

    /**
     * Fire a change event for a language.
     * This is useful for languages that embed other languages.
     */
    function handleChange(languageIds:Array<String>):Void;

    /**
     * Register a tokenization support.
     */
    function register(languageId:String, support:TSupport):IDisposable;

    /**
     * Register a tokenization support factory.
     */
    function registerFactory(languageId:String, factory:ILazyTokenizationSupport<TSupport>):IDisposable;

    /**
     * Get or create the tokenization support for a language.
     * Returns `null` if not found. Synchronous in Cityscape (Monaco returns a promise).
     */
    function getOrCreate(languageId:String):Null<TSupport>;

    /**
     * Get the tokenization support for a language.
     * Returns `null` if not found.
     */
    function get(languageId:String):Null<TSupport>;

    /**
     * Returns false if a factory is still pending.
     */
    function isResolved(languageId:String):Bool;

    /**
     * Set the new color map that all tokens will use in their ColorId binary encoded bits for foreground and background.
     */
    function setColorMap(colorMap:Array<Color>):Void;

    function getColorMap():Null<Array<Color>>;

    function getDefaultBackground():Null<Color>;
}

/**
 * Interface used to format a model
 */
typedef FormattingOptions = {
    /**
     * Size of a tab in spaces.
     */
    var tabSize:Int;
    /**
     * Prefer spaces over tabs.
     */
    var insertSpaces:Bool;
}

/**
 * @internal
 */
typedef IInplaceReplaceSupportResult = {
    var value:String;
    var range:cityscape.common.core.Range.IRange;
}
