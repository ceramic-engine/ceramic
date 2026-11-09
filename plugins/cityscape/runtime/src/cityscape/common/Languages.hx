// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Cancellation.CancellationToken;
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

typedef FoldingContext = {}

/**
 * A provider of folding ranges for editor models.
 *
 * Monaco's `provideFoldingRanges` returns a `ProviderResult` (the ranges,
 * null, or a promise of them). Here the provider gives its result to
 * `resolve`, once, at once or later (an LSP request): an array of ranges, or
 * null when it has none for this model (the indentation ranges are used when
 * every provider gives null).
 */
interface FoldingRangeProvider {

    /**
     * @internal
     */
    var id(default, null):Null<String>;

    /**
     * An optional event to signal that the folding ranges from this provider have changed.
     */
    var onDidChange(default, null):Null<Event<FoldingRangeProvider>>;

    /**
     * Provides the folding ranges for a specific model.
     */
    function provideFoldingRanges(model:ITextModel, context:FoldingContext, token:CancellationToken, resolve:(ranges:Null<Array<FoldingRange>>) -> Void):Void;
}

typedef FoldingRange = {

    /**
     * The one-based start line of the range to fold. The folded area starts after the line's last character.
     */
    var start:Int;

    /**
     * The one-based end line of the range to fold. The folded area ends with the line's last character.
     */
    var end:Int;

    /**
     * Describes the {@link FoldingRangeKind Kind} of the folding range such as {@link FoldingRangeKind.Comment Comment} or
     * {@link FoldingRangeKind.Region Region}. The kind is used to categorize folding ranges and used by commands
     * like 'Fold all comments'. See
     * {@link FoldingRangeKind} for an enumeration of standardized kinds.
     */
    @:optional var kind:Null<FoldingRangeKind>;
}

class FoldingRangeKind {
    /**
     * Kind for folding range representing a comment. The value of the kind is 'comment'.
     */
    public static final Comment = new FoldingRangeKind('comment');
    /**
     * Kind for folding range representing a import. The value of the kind is 'imports'.
     */
    public static final Imports = new FoldingRangeKind('imports');
    /**
     * Kind for folding range representing regions (for example marked by `#region`, `#endregion`).
     * The value of the kind is 'region'.
     */
    public static final Region = new FoldingRangeKind('region');

    /**
     * Returns a {@link FoldingRangeKind} for the given value.
     *
     * @param value of the kind.
     */
    public static function fromValue(value:String):FoldingRangeKind {
        switch (value) {
            case 'comment': return FoldingRangeKind.Comment;
            case 'imports': return FoldingRangeKind.Imports;
            case 'region': return FoldingRangeKind.Region;
        }
        return new FoldingRangeKind(value);
    }

    public var value:String;

    /**
     * Creates a new {@link FoldingRangeKind}.
     *
     * @param value of the kind.
     */
    public function new(value:String) {
        this.value = value;
    }
}

//#region document highlights (contrib/wordHighlighter)

/**
 * A document highlight kind.
 */
enum abstract DocumentHighlightKind(Int) from Int to Int {
    /**
     * A textual occurrence.
     */
    var Text = 0;
    /**
     * Read-access of a symbol, like reading a variable.
     */
    var Read = 1;
    /**
     * Write-access of a symbol, like writing to a variable.
     */
    var Write = 2;
}

/**
 * A document highlight is a range inside a text document which deserves
 * special attention. Usually a document highlight is visualized by changing
 * the background color of its range.
 */
typedef DocumentHighlight = {
    /**
     * The range this highlight applies to.
     */
    var range:cityscape.common.core.Range.IRange;
    /**
     * The highlight kind, default is {@link DocumentHighlightKind.Text text}.
     */
    @:optional var kind:Null<DocumentHighlightKind>;
}

/**
 * The document highlight provider interface defines the contract between extensions and
 * the word-highlight-feature.
 *
 * Monaco returns a `ProviderResult` (a value or a promise): the result is
 * given to `resolve`, at once or later; null (or nothing) means no answer
 * (the next provider is asked).
 */
interface DocumentHighlightProvider {
    /**
     * Provide a set of document highlights, like all occurrences of a variable or
     * all exit-points of a function.
     */
    function provideDocumentHighlights(model:ITextModel, position:cityscape.common.core.Position, token:CancellationToken, resolve:(highlights:Null<Array<DocumentHighlight>>) -> Void):Void;
}

/**
 * A provider that can provide document highlights across multiple documents.
 * The result maps the uri of each model (`uri.toString()`) to its highlights
 * (Monaco's `ResourceMap<DocumentHighlight[]>`).
 */
interface MultiDocumentHighlightProvider {
    var selector(default, null):cityscape.common.LanguageSelector.LanguageSelector;

    /**
     * Provide a Map of Uri --> document highlights, like all occurrences of a variable or
     * all exit-points of a function.
     *
     * Used in cases such as split view, notebooks, etc. where there can be multiple documents
     * with shared symbols.
     */
    function provideMultiDocumentHighlights(primaryModel:ITextModel, position:cityscape.common.core.Position, otherModels:Array<ITextModel>, token:CancellationToken, resolve:(highlights:Null<Map<String, Array<DocumentHighlight>>>) -> Void):Void;
}

//#endregion

// Smart select (cs4-edit): the selection range providers of smartSelect.ts.

typedef SelectionRange = {
    var range:cityscape.common.core.Range.IRange;
}

/**
 * A provider of the ranges the selection expands to (Monaco's
 * `SelectionRangeProvider`).
 *
 * Monaco's `provideSelectionRanges` returns a `ProviderResult` (the ranges,
 * null, or a promise of them). Here the provider gives its result to
 * `resolve`, once, at once or later: for each position, the ranges that
 * contain it.
 */
interface SelectionRangeProvider {

    /**
     * Provide ranges that should be selected from the given position.
     */
    function provideSelectionRanges(model:ITextModel, positions:Array<cityscape.common.core.Position>, token:CancellationToken, resolve:(ranges:Null<Array<Array<SelectionRange>>>) -> Void):Void;
}

//#region document symbols (contrib/documentSymbols, stickyScroll)

// `SymbolKind` is in its own module (common/SymbolKind.hx): its values
// (`String`, `Array`, `Boolean`...) would shadow the types of the modules
// that import this one.

enum abstract SymbolTag(Int) from Int to Int {
    var Deprecated = 1;
}

typedef DocumentSymbol = {
    var name:std.String;
    var detail:std.String;
    var kind:cityscape.common.SymbolKind;
    var tags:std.Array<SymbolTag>;
    @:optional var containerName:std.String;
    var range:cityscape.common.core.Range.IRange;
    var selectionRange:cityscape.common.core.Range.IRange;
    @:optional var children:std.Array<DocumentSymbol>;
}

/**
 * The document symbol provider interface defines the contract between extensions and
 * the [go to symbol](https://code.visualstudio.com/docs/editor/editingevolved#_go-to-symbol)-feature.
 *
 * Like the other providers here, the result (Monaco's `ProviderResult`) is
 * given to `resolve`, at once or later.
 */
interface DocumentSymbolProvider {

    var displayName(default, null):Null<std.String>;

    /**
     * Provide symbol information for the given document.
     */
    function provideDocumentSymbols(model:ITextModel, token:CancellationToken, resolve:(symbols:Null<std.Array<DocumentSymbol>>) -> Void):Void;
}

//#endregion
