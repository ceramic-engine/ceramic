// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.Uri;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.platform.markers.common.Markers.IMarkerData;
import haxe.extern.EitherType;
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
 * Monaco's providers return a `ProviderResult` (a value, null, or a
 * promise). Cityscape's providers are interfaces whose methods give their
 * result to a callback, once, at once or later (an LSP request): the last
 * argument `resolve` takes the result or null. Optional members of Monaco's
 * provider interfaces are nullable fields here: an optional method is a
 * nullable function field (`resolveCompletionItem`), so that the editor
 * can tell whether the provider has it, like Monaco's `typeof x === 'function'`.
 *
 * The enums whose value names hide Haxe types when imported live in
 * modules of their own: `cityscape.common.languages.CompletionItemKind`,
 * `cityscape.common.SymbolKind`,
 * `cityscape.common.languages.LanguageKinds` (`InlayHintKind`).
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

//#region language features

/**
 * A hover represents additional information for a symbol or word. Hovers are
 * rendered in a tooltip-like widget.
 */
typedef Hover = {
    /**
     * The contents of this hover.
     */
    var contents:Array<IMarkdownString>;

    /**
     * The range to which this hover applies. When missing, the
     * editor will use the range at the current position or the
     * current position itself.
     */
    @:optional var range:Null<IRange>;

    /**
     * Can increase the verbosity of the hover
     */
    @:optional var canIncreaseVerbosity:Bool;

    /**
     * Can decrease the verbosity of the hover
     */
    @:optional var canDecreaseVerbosity:Bool;
}

typedef HoverVerbosityRequest = {
    /**
     * The delta by which to increase/decrease the hover verbosity level
     */
    var verbosityDelta:Int;
    /**
     * The previous hover for the same position
     */
    var previousHover:Hover;
}

typedef HoverContext = {
    /**
     * Hover verbosity request
     */
    @:optional var verbosityRequest:Null<HoverVerbosityRequest>;
}

enum abstract HoverVerbosityAction(Int) from Int to Int {
    /**
     * Increase the verbosity of the hover
     */
    var Increase = 0;
    /**
     * Decrease the verbosity of the hover
     */
    var Decrease = 1;
}

/**
 * The hover provider interface defines the contract between extensions and
 * the hover feature.
 */
interface HoverProvider {
    /**
     * Provide a hover for the given position, context and document. Multiple hovers at the same
     * position will be merged by the editor. A hover can have a range which defaults
     * to the word range at the position when omitted.
     */
    function provideHover(model:ITextModel, position:Position, token:CancellationToken, context:Null<HoverContext>, resolve:(hover:Null<Hover>) -> Void):Void;
}

typedef CompletionItemLabel = {
    var label:String;
    @:optional var detail:String;
    @:optional var description:String;
}

enum abstract CompletionItemTag(Int) from Int to Int {
    var Deprecated = 1;
}

enum abstract CompletionItemInsertTextRule(Int) from Int to Int {
    var None = 0;

    /**
     * Adjust whitespace/indentation of multiline insert texts to
     * match the current line indentation.
     */
    var KeepWhitespace = 1;

    /**
     * `insertText` is a snippet.
     */
    var InsertAsSnippet = 4;
}

typedef CompletionItemRanges = {
    var insert:IRange;
    var replace:IRange;
}

/**
 * A completion item represents a text snippet that is
 * proposed to complete text that is being typed.
 */
typedef CompletionItem = {
    /**
     * The label of this completion item (a string or a
     * `CompletionItemLabel`). By default this is also the text that is
     * inserted when selecting this completion.
     */
    var label:EitherType<String, CompletionItemLabel>;
    /**
     * The kind of this completion item. Based on the kind
     * an icon is chosen by the editor.
     */
    var kind:cityscape.common.languages.CompletionItemKind;
    /**
     * A modifier to the `kind` which affect how the item
     * is rendered, e.g. Deprecated is rendered with a strikeout
     */
    @:optional var tags:Null<Array<CompletionItemTag>>;
    /**
     * A human-readable string with additional information
     * about this item, like type or symbol information.
     */
    @:optional var detail:Null<String>;
    /**
     * A human-readable string that represents a doc-comment (a string or
     * an `IMarkdownString`).
     */
    @:optional var documentation:Null<EitherType<String, IMarkdownString>>;
    /**
     * A string that should be used when comparing this item
     * with other items. When `falsy` the label is used.
     */
    @:optional var sortText:Null<String>;
    /**
     * A string that should be used when filtering a set of
     * completion items. When `falsy` the label is used.
     */
    @:optional var filterText:Null<String>;
    /**
     * Select this item when showing. *Note* that only one completion item can be selected and
     * that the editor decides which item that is. The rule is that the *first* item of those
     * that match best is selected.
     */
    @:optional var preselect:Bool;
    /**
     * A string or snippet that should be inserted in a document when selecting
     * this completion.
     */
    var insertText:String;
    /**
     * Additional rules (as bitmask) that should be applied when inserting
     * this completion.
     */
    @:optional var insertTextRules:Null<CompletionItemInsertTextRule>;
    /**
     * A range of text that should be replaced by this completion item: an
     * `IRange` or `CompletionItemRanges` (insert and replace). Defaults to
     * a range from the start of the current word to the current position.
     *
     * *Note:* The range must be a single line and it must
     * contain the position at which completion has been requested.
     */
    @:optional var range:Null<EitherType<IRange, CompletionItemRanges>>;
    /**
     * An optional set of characters that when pressed while this completion is active will accept it first and
     * then type that character. *Note* that all commit characters should have `length=1` and that superfluous
     * characters will be ignored.
     */
    @:optional var commitCharacters:Null<Array<String>>;
    /**
     * An optional array of additional text edits that are applied when
     * selecting this completion. Edits must not overlap with the main edit
     * nor with themselves.
     */
    @:optional var additionalTextEdits:Null<Array<cityscape.common.core.EditOperation.ISingleEditOperation>>;
    /**
     * A command that should be run upon acceptance of this item.
     */
    @:optional var command:Null<Command>;
}

typedef CompletionList = {
    var suggestions:Array<CompletionItem>;
    @:optional var incomplete:Bool;
    @:optional var dispose:Null<() -> Void>;
    /**
     * @internal
     */
    @:optional var duration:Null<Float>;
}

/**
 * How a suggest provider was triggered.
 */
enum abstract CompletionTriggerKind(Int) from Int to Int {
    var Invoke = 0;
    var TriggerCharacter = 1;
    var TriggerForIncompleteCompletions = 2;
}

/**
 * Contains additional information about the context in which
 * completion provider is triggered.
 */
typedef CompletionContext = {
    /**
     * How the completion was triggered.
     */
    var triggerKind:CompletionTriggerKind;
    /**
     * Character that triggered the completion item provider.
     *
     * Null if provider was not triggered by a character.
     */
    @:optional var triggerCharacter:Null<String>;
}

/**
 * The completion item provider interface defines the contract between extensions and
 * the IntelliSense.
 *
 * When computing *complete* completion items is expensive, providers can optionally implement
 * `resolveCompletionItem`. In that case it is enough to return completion
 * items with a label from `provideCompletionItems`. Subsequently,
 * when a completion item is shown in the UI and gains focus this provider is asked to resolve
 * the item, like adding doc-comment or details.
 */
interface CompletionItemProvider {

    /**
     * Used to identify completions in the (debug) UI and telemetry.
     * @internal
     */
    var _debugDisplayName(default, null):Null<String>;

    var triggerCharacters(default, null):Null<Array<String>>;

    /**
     * Provide completion items for the given position and document.
     */
    function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void;

    /**
     * Given a completion item fill in more data, like doc-comment
     * or details (null when the provider does not resolve items). It gives
     * the fields to add to the item (or null) to `resolve`.
     *
     * The editor will only resolve a completion item once.
     */
    var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void>;
}

typedef Command = {
    var id:String;
    var title:String;
    @:optional var tooltip:Null<String>;
    @:optional var arguments:Null<Array<Any>>;
}

/**
 * Monaco's `Command` namespace.
 */
class Commands {
    public static function is(obj:Any):Bool {
        if (obj == null || !cityscape.base.common.JsValues.isObject(obj)) {
            return false;
        }
        final c:Command = obj;
        return cityscape.base.common.JsValues.isString(c.id) && cityscape.base.common.JsValues.isString(c.title);
    }
}

typedef CodeAction = {
    var title:String;
    @:optional var command:Null<Command>;
    @:optional var edit:Null<WorkspaceEdit>;
    @:optional var diagnostics:Null<Array<IMarkerData>>;
    @:optional var kind:Null<String>;
    @:optional var isPreferred:Null<Bool>;
    @:optional var isAI:Null<Bool>;
    @:optional var disabled:Null<String>;
    @:optional var ranges:Null<Array<IRange>>;
}

enum abstract CodeActionTriggerType(Int) from Int to Int {
    var Invoke = 1;
    var Auto = 2;
}

/**
 * @internal
 */
typedef CodeActionContext = {
    @:optional var only:Null<String>;
    var trigger:CodeActionTriggerType;
    /**
     * The markers of the model that touch the range: Monaco's standalone
     * `CodeActionContext` (`monaco.languages.CodeActionContext`). Filled by
     * `Cityscape.registerCodeActionProvider`, like Monaco's
     * `registerCodeActionProvider`; null for a provider registered in the
     * registry directly.
     */
    @:optional var markers:Null<Array<IMarkerData>>;
}

typedef CodeActionList = {
    var actions:Array<CodeAction>;
    @:optional var dispose:Null<() -> Void>;
}

/**
 * The documentation of a code action kind (`CodeActionProvider.documentation`).
 */
typedef CodeActionProviderDocumentation = {
    var kind:String;
    var command:Command;
}

/**
 * The code action interface defines the contract between extensions and
 * the light bulb feature.
 * @internal
 */
interface CodeActionProvider {

    var displayName(default, null):Null<String>;

    /**
     * Provide commands for the given document and range (a `Range` or a
     * `Selection`).
     */
    function provideCodeActions(model:ITextModel, range:Range, context:CodeActionContext, token:CancellationToken, resolve:(list:Null<CodeActionList>) -> Void):Void;

    /**
     * Given a code action fill in the edit. Will only invoked when missing
     * (null when the provider does not resolve actions).
     */
    var resolveCodeAction(default, null):Null<(codeAction:CodeAction, token:CancellationToken, resolve:(codeAction:Null<CodeAction>) -> Void) -> Void>;

    /**
     * Optional list of CodeActionKinds that this provider returns.
     */
    var providedCodeActionKinds(default, null):Null<Array<String>>;

    var documentation(default, null):Null<Array<CodeActionProviderDocumentation>>;
}

typedef ParameterInformation = {
    /**
     * The label of this signature: a string, or an array of two offsets
     * (inclusive start and exclusive end) into its containing signature
     * label.
     */
    var label:EitherType<String, Array<Int>>;
    /**
     * The human-readable doc-comment of this signature (a string or an
     * `IMarkdownString`).
     */
    @:optional var documentation:Null<EitherType<String, IMarkdownString>>;
}

typedef SignatureInformation = {
    var label:String;
    @:optional var documentation:Null<EitherType<String, IMarkdownString>>;
    var parameters:Array<ParameterInformation>;
    @:optional var activeParameter:Null<Int>;
}

typedef SignatureHelp = {
    var signatures:Array<SignatureInformation>;
    var activeSignature:Int;
    var activeParameter:Int;
}

typedef SignatureHelpResult = {
    var value:SignatureHelp;
    @:optional var dispose:Null<() -> Void>;
}

enum abstract SignatureHelpTriggerKind(Int) from Int to Int {
    var Invoke = 1;
    var TriggerCharacter = 2;
    var ContentChange = 3;
}

typedef SignatureHelpContext = {
    final triggerKind:SignatureHelpTriggerKind;
    @:optional final triggerCharacter:Null<String>;
    final isRetrigger:Bool;
    @:optional final activeSignatureHelp:Null<SignatureHelp>;
}

/**
 * The signature help provider interface defines the contract between extensions and
 * the parameter hints feature.
 */
interface SignatureHelpProvider {

    var signatureHelpTriggerCharacters(default, null):Null<Array<String>>;
    var signatureHelpRetriggerCharacters(default, null):Null<Array<String>>;

    /**
     * Provide help for the signature at the given position and document.
     */
    function provideSignatureHelp(model:ITextModel, position:Position, token:CancellationToken, context:SignatureHelpContext, resolve:(result:Null<SignatureHelpResult>) -> Void):Void;
}

/**
 * Value-object that contains additional information when
 * requesting references.
 */
typedef ReferenceContext = {
    /**
     * Include the declaration of the current symbol.
     */
    var includeDeclaration:Bool;
}

/**
 * The reference provider interface defines the contract between extensions and
 * the find references-feature.
 */
interface ReferenceProvider {
    function provideReferences(model:ITextModel, position:Position, context:ReferenceContext, token:CancellationToken, resolve:(locations:Null<Array<Location>>) -> Void):Void;
}

/**
 * Represents a location inside a resource, such as a line
 * inside a text file.
 */
typedef Location = {
    /**
     * The resource identifier of this location.
     */
    var uri:Uri;
    /**
     * The document range of this locations.
     */
    var range:IRange;
}

/**
 * A location with the range of its origin (Monaco's `LocationLink`), which
 * is also a `Location`.
 */
typedef LocationLink = {
    /**
     * A range to select where this link originates from.
     */
    @:optional var originSelectionRange:Null<IRange>;

    /**
     * The target uri this link points to.
     */
    var uri:Uri;

    /**
     * The full range this link points to.
     */
    var range:IRange;

    /**
     * A range to select this link points to. Must be contained
     * in `LocationLink.range`.
     */
    @:optional var targetSelectionRange:Null<IRange>;
}

/**
 * The definition of a symbol: Monaco's `Definition` (`Location |
 * Location[] | LocationLink[]`) is always an array of `LocationLink`s here
 * (a `Location` is a `LocationLink` without the optional ranges).
 */
typedef Definition = Array<LocationLink>;

/**
 * The definition provider interface defines the contract between extensions and
 * the go to definition and peek definition features.
 */
interface DefinitionProvider {
    /**
     * Provide the definition of the symbol at the given position and document.
     */
    function provideDefinition(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void;
}

/**
 * The definition provider interface defines the contract between extensions and
 * the go to declaration feature.
 */
interface DeclarationProvider {
    function provideDeclaration(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void;
}

/**
 * The implementation provider interface defines the contract between extensions and
 * the go to implementation feature.
 */
interface ImplementationProvider {
    function provideImplementation(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void;
}

/**
 * The type definition provider interface defines the contract between extensions and
 * the go to type definition feature.
 */
interface TypeDefinitionProvider {
    function provideTypeDefinition(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void;
}

/**
 * Module functions of languages.ts about locations.
 */
class LocationUtils {
    /**
     * Monaco's `isLocationLink`.
     */
    public static function isLocationLink(thing:Any):Bool {
        if (thing == null || !cityscape.base.common.JsValues.isObject(thing)) {
            return false;
        }
        final l:LocationLink = thing;
        return Std.isOfType(l.uri, Uri) && Range.isIRange(l.range) && (Range.isIRange(l.originSelectionRange) || Range.isIRange(l.targetSelectionRange));
    }
}

typedef TextEdit = {
    var range:IRange;
    var text:String;
    @:optional var eol:Null<cityscape.common.Model.EndOfLineSequence>;
}

/**
 * Monaco's `TextEdit` class (its static function).
 */
class TextEdits {
    public static function asEditOperation(edit:TextEdit):cityscape.common.core.EditOperation.ISingleEditOperation {
        return cityscape.common.core.EditOperation.replace(Range.lift(edit.range), edit.text);
    }
}

/**
 * The document formatting provider interface defines the contract between extensions and
 * the formatting-feature.
 */
interface DocumentFormattingEditProvider {

    var displayName(default, null):Null<String>;

    /**
     * Provide formatting edits for a whole document.
     */
    function provideDocumentFormattingEdits(model:ITextModel, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void):Void;
}

/**
 * The document formatting provider interface defines the contract between extensions and
 * the formatting-feature.
 */
interface DocumentRangeFormattingEditProvider {

    var displayName(default, null):Null<String>;

    /**
     * Provide formatting edits for a range in a document.
     *
     * The given range is a hint and providers can decide to format a smaller
     * or larger range. Often this is done by adjusting the start and end
     * of the range to full syntax nodes.
     */
    function provideDocumentRangeFormattingEdits(model:ITextModel, range:Range, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void):Void;

    /**
     * Formats several ranges at once (null when the provider does not).
     */
    var provideDocumentRangesFormattingEdits(default, null):Null<(model:ITextModel, ranges:Array<Range>, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void) -> Void>;
}

/**
 * A link inside the editor.
 */
typedef ILink = {
    var range:IRange;
    /**
     * A `Uri` or a string.
     */
    @:optional var url:Null<EitherType<Uri, String>>;
    @:optional var tooltip:Null<String>;
}

typedef ILinksList = {
    var links:Array<ILink>;
    @:optional var dispose:Null<() -> Void>;
}

/**
 * A provider of links.
 */
interface LinkProvider {
    function provideLinks(model:ITextModel, token:CancellationToken, resolve:(links:Null<ILinksList>) -> Void):Void;
    var resolveLink(default, null):Null<(link:ILink, token:CancellationToken, resolve:(link:Null<ILink>) -> Void) -> Void>;
}

/**
 * A color in RGBA format.
 */
typedef IColor = {
    /**
     * The red component in the range [0-1].
     */
    final red:Float;
    /**
     * The green component in the range [0-1].
     */
    final green:Float;
    /**
     * The blue component in the range [0-1].
     */
    final blue:Float;
    /**
     * The alpha component in the range [0-1].
     */
    final alpha:Float;
}

/**
 * String representations for a color
 */
typedef IColorPresentation = {
    /**
     * The label of this color presentation. It will be shown on the color
     * picker header. By default this is also the text that is inserted when selecting
     * this color presentation.
     */
    var label:String;
    /**
     * An edit which is applied to a document when selecting
     * this presentation for the color.
     */
    @:optional var textEdit:Null<TextEdit>;
    /**
     * An optional array of additional text edits that are applied when
     * selecting this color presentation.
     */
    @:optional var additionalTextEdits:Null<Array<TextEdit>>;
}

/**
 * A color range is a range in a text model which represents a color.
 */
typedef IColorInformation = {
    /**
     * The range within the model.
     */
    var range:IRange;
    /**
     * The color represented in this range.
     */
    var color:IColor;
}

/**
 * A provider of colors for editor models.
 */
interface DocumentColorProvider {
    /**
     * Provides the color ranges for a specific model.
     */
    function provideDocumentColors(model:ITextModel, token:CancellationToken, resolve:(colors:Null<Array<IColorInformation>>) -> Void):Void;
    /**
     * Provide the string representations for a color.
     */
    function provideColorPresentations(model:ITextModel, colorInfo:IColorInformation, token:CancellationToken, resolve:(presentations:Null<Array<IColorPresentation>>) -> Void):Void;
}

typedef IWorkspaceTextEditTextEdit = {
    > TextEdit,
    @:optional var insertAsSnippet:Null<Bool>;
}

/**
 * A text edit of a workspace edit (Monaco's `IWorkspaceTextEdit`).
 */
typedef IWorkspaceTextEdit = {
    var resource:Uri;
    var textEdit:IWorkspaceTextEditTextEdit;
    var versionId:Null<Int>;
}

/**
 * A file operation of a workspace edit (Monaco's `IWorkspaceFileEdit`):
 * create, rename or delete. Cityscape has no file service; the host applies
 * them (`Cityscape.applyFileEdit`).
 */
typedef IWorkspaceFileEdit = {
    @:optional var oldResource:Null<Uri>;
    @:optional var newResource:Null<Uri>;
    @:optional var options:Null<Any>;
}

/**
 * A workspace edit: `edits` holds `IWorkspaceTextEdit`s and
 * `IWorkspaceFileEdit`s (told apart by their `resource` field).
 */
typedef WorkspaceEdit = {
    var edits:Array<EitherType<IWorkspaceTextEdit, IWorkspaceFileEdit>>;
}

typedef Rejection = {
    @:optional var rejectReason:Null<String>;
}

typedef WorkspaceEditAndRejection = {
    > WorkspaceEdit,
    @:optional var rejectReason:Null<String>;
}

typedef RenameLocation = {
    var range:IRange;
    var text:String;
    @:optional var rejectReason:Null<String>;
}

interface RenameProvider {
    function provideRenameEdits(model:ITextModel, position:Position, newName:String, token:CancellationToken, resolve:(edit:Null<WorkspaceEditAndRejection>) -> Void):Void;
    var resolveRenameLocation(default, null):Null<(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void) -> Void>;
}

typedef CodeLens = {
    var range:IRange;
    @:optional var id:Null<String>;
    @:optional var command:Null<Command>;
}

typedef CodeLensList = {
    var lenses:Array<CodeLens>;
    @:optional var dispose:Null<() -> Void>;
}

interface CodeLensProvider {
    var onDidChange(default, null):Null<Event<CodeLensProvider>>;
    function provideCodeLenses(model:ITextModel, token:CancellationToken, resolve:(lenses:Null<CodeLensList>) -> Void):Void;
    var resolveCodeLens(default, null):Null<(model:ITextModel, codeLens:CodeLens, token:CancellationToken, resolve:(codeLens:Null<CodeLens>) -> Void) -> Void>;
}

typedef InlayHintLabelPart = {
    var label:String;
    /**
     * A string or an `IMarkdownString`.
     */
    @:optional var tooltip:Null<EitherType<String, IMarkdownString>>;
    @:optional var command:Null<Command>;
    @:optional var location:Null<Location>;
}

typedef InlayHint = {
    /**
     * A string or an array of `InlayHintLabelPart`s.
     */
    var label:EitherType<String, Array<InlayHintLabelPart>>;
    @:optional var tooltip:Null<EitherType<String, IMarkdownString>>;
    @:optional var textEdits:Null<Array<TextEdit>>;
    var position:IPosition;
    @:optional var kind:Null<cityscape.common.languages.LanguageKinds.InlayHintKind>;
    @:optional var paddingLeft:Null<Bool>;
    @:optional var paddingRight:Null<Bool>;
}

typedef InlayHintList = {
    var hints:Array<InlayHint>;
    @:optional var dispose:Null<() -> Void>;
}

interface InlayHintsProvider {
    var displayName(default, null):Null<String>;
    var onDidChangeInlayHints(default, null):Null<VoidEvent>;
    function provideInlayHints(model:ITextModel, range:Range, token:CancellationToken, resolve:(hints:Null<InlayHintList>) -> Void):Void;
    var resolveInlayHint(default, null):Null<(hint:InlayHint, token:CancellationToken, resolve:(hint:Null<InlayHint>) -> Void) -> Void>;
}

typedef SemanticTokensLegend = {
    final tokenTypes:Array<String>;
    final tokenModifiers:Array<String>;
}

typedef SemanticTokens = {
    @:optional final resultId:Null<String>;
    final data:UInt32Array;
}

typedef SemanticTokensEdit = {
    final start:Int;
    final deleteCount:Int;
    @:optional final data:Null<UInt32Array>;
}

typedef SemanticTokensEdits = {
    @:optional final resultId:Null<String>;
    final edits:Array<SemanticTokensEdit>;
}

interface DocumentSemanticTokensProvider {
    var onDidChange(default, null):Null<VoidEvent>;
    function getLegend():SemanticTokensLegend;
    /**
     * Gives `SemanticTokens` or `SemanticTokensEdits` (told apart by their
     * `data` or `edits` field) to `resolve`.
     */
    function provideDocumentSemanticTokens(model:ITextModel, lastResultId:Null<String>, token:CancellationToken, resolve:(result:Null<EitherType<SemanticTokens, SemanticTokensEdits>>) -> Void):Void;
    function releaseDocumentSemanticTokens(resultId:Null<String>):Void;
}

interface DocumentRangeSemanticTokensProvider {
    function getLegend():SemanticTokensLegend;
    function provideDocumentRangeSemanticTokens(model:ITextModel, range:Range, token:CancellationToken, resolve:(result:Null<SemanticTokens>) -> Void):Void;
}

//#endregion

//#region inline completions (step 7, cs7-rest-inline)

/**
 * How an inline completion was triggered.
 */
enum abstract InlineCompletionTriggerKind(Int) from Int to Int {
    /**
     * Completion was triggered automatically while editing.
     * It is sufficient to return a single completion item in this case.
     */
    var Automatic = 0;

    /**
     * Completion was triggered explicitly by a user gesture.
     * Return multiple completion items to enable cycling through them.
     */
    var Explicit = 1;
}

typedef InlineCompletionContext = {
    /**
     * How the completion was triggered.
     */
    final triggerKind:InlineCompletionTriggerKind;
    final selectedSuggestionInfo:Null<SelectedSuggestionInfo>;
    /**
     * @experimental
     * @internal
     */
    @:optional final userPrompt:Null<String>;
}

class SelectedSuggestionInfo {

    public final range:IRange;
    public final text:String;
    public final completionKind:cityscape.common.languages.CompletionItemKind;
    public final isSnippetText:Bool;

    public function new(range:IRange, text:String, completionKind:cityscape.common.languages.CompletionItemKind, isSnippetText:Bool) {
        this.range = range;
        this.text = text;
        this.completionKind = completionKind;
        this.isSnippetText = isSnippetText;
    }

    public function equals(other:SelectedSuggestionInfo):Bool {
        return Range.lift(this.range).equalsRange(other.range)
            && this.text == other.text
            && this.completionKind == other.completionKind
            && this.isSnippetText == other.isSnippetText;
    }

}

/**
 * Monaco's `{ snippet: string }` form of `InlineCompletion.insertText`.
 */
typedef InlineCompletionSnippet = {
    var snippet:String;
}

typedef InlineCompletion = {
    /**
     * The text to insert (a string, or an `InlineCompletionSnippet`).
     * If the text contains a line break, the range must end at the end of a line.
     * If existing text should be replaced, the existing text must be a prefix of the text to insert.
     *
     * The text can also be a snippet. In that case, a preview with default parameters is shown.
     * When accepting the suggestion, the full snippet is inserted.
     */
    final insertText:EitherType<String, InlineCompletionSnippet>;

    /**
     * A text that is used to decide if this inline completion should be shown.
     * An inline completion is shown if the text to replace is a subword of the filter text.
     */
    @:optional final filterText:Null<String>;

    /**
     * An optional array of additional text edits that are applied when
     * selecting this completion. Edits must not overlap with the main edit
     * nor with themselves.
     */
    @:optional final additionalTextEdits:Null<Array<cityscape.common.core.EditOperation.ISingleEditOperation>>;

    /**
     * The range to replace.
     * Must begin and end on the same line.
     */
    @:optional final range:Null<IRange>;

    @:optional final command:Null<Command>;

    /**
     * If set to `true`, unopened closing brackets are removed and unclosed opening brackets are closed.
     * Defaults to `false`.
     */
    @:optional final completeBracketPairs:Null<Bool>;
}

/**
 * A list of inline completions. Monaco's generic `InlineCompletions<TItem>`:
 * a provider can give items with more fields (structural typing) and read
 * them back in its handlers.
 */
typedef InlineCompletions = {
    final items:Array<InlineCompletion>;
    /**
     * A list of commands associated with the inline completions of this list.
     */
    @:optional final commands:Null<Array<Command>>;

    @:optional final suppressSuggestions:Null<Bool>;

    /**
     * When set and the user types a suggestion without derivating from it, the inline suggestion is not updated.
     */
    @:optional final enableForwardStability:Null<Bool>;
}

typedef InlineCompletionProviderGroupId = String;

/**
 * How a partial acceptance was triggered.
 */
enum abstract PartialAcceptTriggerKind(Int) from Int to Int {
    var Word = 0;
    var Line = 1;
    var Suggest = 2;
}

typedef PartialAcceptInfo = {
    var kind:PartialAcceptTriggerKind;
}

/**
 * Monaco's `InlineCompletionsProvider`. `provideInlineCompletions` gives
 * its result to `resolve` (at once or later); the optional members are
 * nullable function fields.
 */
interface InlineCompletionsProvider {

    function provideInlineCompletions(model:ITextModel, position:Position, context:InlineCompletionContext, token:CancellationToken, resolve:(completions:Null<InlineCompletions>) -> Void):Void;

    /**
     * Will be called when an item is shown.
     * `updatedInsertText` is useful to understand bracket completion.
     */
    var handleItemDidShow(default, null):Null<(completions:InlineCompletions, item:InlineCompletion, updatedInsertText:String) -> Void>;

    /**
     * Will be called when an item is partially accepted.
     */
    var handlePartialAccept(default, null):Null<(completions:InlineCompletions, item:InlineCompletion, acceptedCharacters:Int, info:PartialAcceptInfo) -> Void>;

    /**
     * Will be called when a completions list is no longer in use and can be garbage-collected.
     */
    function freeInlineCompletions(completions:InlineCompletions):Void;

    /**
     * Only used for `yieldsToGroupIds`.
     * Multiple providers can have the same group id.
     */
    var groupId(default, null):Null<InlineCompletionProviderGroupId>;

    /**
     * Returns a list of preferred provider `groupId`s.
     * The current provider is only requested for completions if no provider with a preferred group id returned a result.
     */
    var yieldsToGroupIds(default, null):Null<Array<InlineCompletionProviderGroupId>>;

}

//#endregion
