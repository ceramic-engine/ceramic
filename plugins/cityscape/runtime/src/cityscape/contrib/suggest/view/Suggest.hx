// Ported from vscode src/vs/editor/contrib/suggest/browser/suggest.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Filters;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.CompletionContext;
import cityscape.common.Languages.CompletionItemInsertTextRule;
import cityscape.common.Languages.CompletionItemLabel;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.Languages.CompletionItemRanges;
import cityscape.common.Languages.CompletionItemTag;
import cityscape.common.Languages.CompletionList;
import cityscape.common.Languages.CompletionTriggerKind;
import cityscape.common.Model.ITextModel;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.config.EditorOptions.InternalQuickSuggestionsOptions;
import cityscape.common.config.EditorOptions.QuickSuggestionsValue;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.snippet.view.SnippetParser;
import cityscape.platform.contextkey.common.ContextKey.RawContextKey;

typedef CompletionItemKind = cityscape.common.languages.CompletionItemKind;

/**
 * The context keys of the suggest widget (Monaco's `Context` of suggest.ts).
 */
class SuggestContext {
    public static final Visible = new RawContextKey<Bool>('suggestWidgetVisible', false, 'Whether suggestion are visible');
    public static final HasFocusedSuggestion = new RawContextKey<Bool>('suggestWidgetHasFocusedSuggestion', false, 'Whether any suggestion is focused');
    public static final DetailsVisible = new RawContextKey<Bool>('suggestWidgetDetailsVisible', false, 'Whether suggestion details are visible');
    public static final MultipleSuggestions = new RawContextKey<Bool>('suggestWidgetMultipleSuggestions', false, 'Whether there are multiple suggestions to pick from');
    public static final MakesTextEdit = new RawContextKey<Bool>('suggestionMakesTextEdit', true, 'Whether inserting the current suggestion yields in a change or has everything already been typed');
    public static final AcceptSuggestionsOnEnter = new RawContextKey<Bool>('acceptSuggestionOnEnter', true, 'Whether suggestions are inserted when pressing Enter');
    public static final HasInsertAndReplaceRange = new RawContextKey<Bool>('suggestionHasInsertAndReplaceRange', false, 'Whether the current suggestion has insert and replace behaviour');
    public static final InsertMode = new RawContextKey<String>('suggestionInsertMode', null, {type: 'string', description: 'Whether the default behaviour is to insert or replace'});
    public static final CanResolve = new RawContextKey<Bool>('suggestionCanResolve', false, 'Whether the current suggestion supports to resolve further details');
}

/**
 * A completion item of a provider with what the suggest widget computes
 * about it (Monaco's `CompletionItem` of suggest.ts; the provider's item is
 * `completion`).
 */
class CompletionItem {

    public final position:Position;
    public final completion:cityscape.common.Languages.CompletionItem;
    public final container:CompletionList;
    public final provider:CompletionItemProvider;

    //
    public final editStart:Position;
    public final editInsertEnd:Position;
    public final editReplaceEnd:Position;

    //
    public final textLabel:String;

    // perf
    public final labelLow:String;
    public final sortTextLow:Null<String>;
    public final filterTextLow:Null<String>;

    // validation
    public final isInvalid:Bool;

    // sorting, filtering
    public var score:FuzzyScore = FuzzyScore.Default;
    public var distance:Int = 0;
    public var idx:Int = 0;
    public var word:Null<String> = null;

    // resolving
    var _resolveDuration:Null<Float> = null;
    var _resolveCache:Null<Promise<Any>> = null;

    public function new(position:Position, completion:cityscape.common.Languages.CompletionItem, container:CompletionList, provider:CompletionItemProvider) {
        this.position = position;
        this.completion = completion;
        this.container = container;
        this.provider = provider;

        final label:Any = completion.label;
        this.textLabel = JsValues.isString(label)
            ? (label : String)
            : (label != null ? (label : CompletionItemLabel).label : null);

        // ensure lower-variants (perf)
        this.labelLow = this.textLabel != null ? this.textLabel.toLowerCase() : '';

        // validate label
        var isInvalid = this.textLabel == null || this.textLabel.length == 0;

        this.sortTextLow = completion.sortText != null && completion.sortText.length > 0 ? completion.sortText.toLowerCase() : completion.sortText;
        this.filterTextLow = completion.filterText != null && completion.filterText.length > 0 ? completion.filterText.toLowerCase() : completion.filterText;

        // normalize ranges
        final range:Any = completion.range;
        if (Range.isIRange(range)) {
            final r:IRange = range;
            this.editStart = new Position(r.startLineNumber, r.startColumn);
            this.editInsertEnd = new Position(r.endLineNumber, r.endColumn);
            this.editReplaceEnd = new Position(r.endLineNumber, r.endColumn);

            // validate range
            isInvalid = isInvalid
                || Range.spansMultipleLines(r) || r.startLineNumber != position.lineNumber;

        }
        else {
            final ranges:CompletionItemRanges = range;
            this.editStart = new Position(ranges.insert.startLineNumber, ranges.insert.startColumn);
            this.editInsertEnd = new Position(ranges.insert.endLineNumber, ranges.insert.endColumn);
            this.editReplaceEnd = new Position(ranges.replace.endLineNumber, ranges.replace.endColumn);

            // validate ranges
            isInvalid = isInvalid
                || Range.spansMultipleLines(ranges.insert) || Range.spansMultipleLines(ranges.replace)
                || ranges.insert.startLineNumber != position.lineNumber || ranges.replace.startLineNumber != position.lineNumber
                || ranges.insert.startColumn != ranges.replace.startColumn;
        }
        this.isInvalid = isInvalid;

        // create the suggestion resolver
        if (provider.resolveCompletionItem == null) {
            this._resolveCache = Promise.resolve(null);
            this._resolveDuration = 0;
        }
    }

    // ---- resolving

    public var isResolved(get, never):Bool;
    function get_isResolved():Bool {
        return this._resolveDuration != null;
    }

    public var resolveDuration(get, never):Float;
    function get_resolveDuration():Float {
        return this._resolveDuration != null ? this._resolveDuration : -1;
    }

    /**
     * Resolves the item once with its provider (`resolveCompletionItem`):
     * the fields of the result are copied into `completion`.
     */
    public function resolve(token:CancellationToken):Promise<Any> {
        if (this._resolveCache == null) {
            final sub = token.onCancellationRequested(() -> {
                this._resolveCache = null;
                this._resolveDuration = null;
            });
            final start = haxe.Timer.stamp();
            final resolveFn = this.provider.resolveCompletionItem;
            this._resolveCache = Promise.fromCallback(done -> resolveFn(this.completion, token, done)).then(value -> {
                if (value != null) {
                    for (field in Reflect.fields(value)) {
                        Reflect.setField(this.completion, field, Reflect.field(value, field));
                    }
                }
                this._resolveDuration = (haxe.Timer.stamp() - start) * 1000;
                return null;
            }, err -> {
                if (CancellationError.isCancellationError(err)) {
                    // the IPC queue will reject the request with the
                    // cancellation error -> reset cached
                    this._resolveCache = null;
                    this._resolveDuration = null;
                }
                return null;
            }).finally(() -> {
                sub.dispose();
            });
        }
        return this._resolveCache;
    }

}

enum abstract SnippetSortOrder(Int) from Int to Int {
    var Top = 0;
    var Inline = 1;
    var Bottom = 2;
}

class CompletionOptions {

    public static final default_ = new CompletionOptions();

    public final snippetSortOrder:SnippetSortOrder;
    public final kindFilter:Array<CompletionItemKind>;
    public final providerFilter:Array<CompletionItemProvider>;
    public final providerItemsToReuse:Map<CompletionItemProvider, Array<CompletionItem>>;
    public final showDeprecated:Bool;

    public function new(snippetSortOrder:SnippetSortOrder = SnippetSortOrder.Bottom, ?kindFilter:Array<CompletionItemKind>, ?providerFilter:Array<CompletionItemProvider>, ?providerItemsToReuse:Map<CompletionItemProvider, Array<CompletionItem>>, showDeprecated:Bool = true) {
        this.snippetSortOrder = snippetSortOrder;
        this.kindFilter = kindFilter != null ? kindFilter : [];
        this.providerFilter = providerFilter != null ? providerFilter : [];
        this.providerItemsToReuse = providerItemsToReuse != null ? providerItemsToReuse : new Map();
        this.showDeprecated = showDeprecated;
    }
}

typedef CompletionDurationEntry = {
    final providerName:String;
    final elapsedProvider:Float;
    final elapsedOverall:Float;
}

typedef CompletionDurations = {
    final entries:Array<CompletionDurationEntry>;
    final elapsed:Float;
}

class CompletionItemModel {
    public final items:Array<CompletionItem>;
    public final needsClipboard:Bool;
    public final durations:CompletionDurations;
    public final disposable:IDisposable;

    public function new(items:Array<CompletionItem>, needsClipboard:Bool, durations:CompletionDurations, disposable:IDisposable) {
        this.items = items;
        this.needsClipboard = needsClipboard;
        this.durations = durations;
        this.disposable = disposable;
    }
}

/**
 * An item preselector (Monaco's `ISuggestItemPreselector`).
 */
interface ISuggestItemPreselector {
    /**
     * The preselector with highest priority is asked first.
     */
    var priority(default, null):Int;

    /**
     * Is called to preselect a suggest item.
     * When -1 is returned, item preselectors with lower priority are asked.
     */
    function select(model:ITextModel, pos:IPosition, items:Array<CompletionItem>):Int;
}

/**
 * Module functions of suggest.ts.
 */
class SuggestUtils {

    /**
     * Asks the providers of `registry` for completion items (Monaco's
     * `provideSuggestionItems`). `snippetSuggestSupport` is Monaco's global
     * snippet provider (`getSnippetSuggestSupport`), per context here.
     */
    public static function provideSuggestionItems(registry:LanguageFeatureRegistry<CompletionItemProvider>, model:ITextModel, position:Position, ?options:CompletionOptions, ?context:CompletionContext, ?token:CancellationToken, ?snippetSuggestSupport:CompletionItemProvider):Promise<CompletionItemModel> {

        if (options == null) {
            options = CompletionOptions.default_;
        }
        if (context == null) {
            context = {triggerKind: CompletionTriggerKind.Invoke};
        }
        if (token == null) {
            token = CancellationTokens.None;
        }
        final opts = options;
        final ctx = context;
        final tok = token;

        final sw = haxe.Timer.stamp();
        position = position.clone();
        final pos = position;

        final word = model.getWordAtPosition(position);
        final defaultReplaceRange = word != null ? new Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn) : Range.fromPositions(position);
        final defaultRange:CompletionItemRanges = {replace: defaultReplaceRange, insert: defaultReplaceRange.setEndPosition(position.lineNumber, position.column)};

        final result:Array<CompletionItem> = [];
        final disposables = new DisposableStore();
        final durations:Array<CompletionDurationEntry> = [];
        var needsClipboard = false;

        final onCompletionList = (provider:CompletionItemProvider, container:Null<CompletionList>, sw:Float) -> {
            var didAddResult = false;
            if (container == null) {
                return didAddResult;
            }
            for (suggestion in container.suggestions) {
                if (opts.kindFilter.indexOf(suggestion.kind) < 0) {
                    // skip if not showing deprecated suggestions
                    if (!opts.showDeprecated && suggestion.tags != null && suggestion.tags.indexOf(CompletionItemTag.Deprecated) >= 0) {
                        continue;
                    }
                    // fill in default range when missing
                    if (suggestion.range == null) {
                        suggestion.range = defaultRange;
                    }
                    // fill in default sortText when missing
                    if (suggestion.sortText == null || suggestion.sortText.length == 0) {
                        final label:Any = suggestion.label;
                        suggestion.sortText = JsValues.isString(label) ? (label : String) : (label : CompletionItemLabel).label;
                    }
                    if (!needsClipboard && suggestion.insertTextRules != null && ((suggestion.insertTextRules : Int) & (CompletionItemInsertTextRule.InsertAsSnippet : Int)) != 0) {
                        needsClipboard = SnippetParser.guessNeedsClipboard(suggestion.insertText);
                    }
                    result.push(new CompletionItem(pos, suggestion, container, provider));
                    didAddResult = true;
                }
            }
            if (container.dispose != null) {
                final d = container.dispose;
                disposables.add(Lifecycle.toDisposable(d));
            }
            durations.push({
                providerName: provider._debugDisplayName != null ? provider._debugDisplayName : 'unknown_provider',
                elapsedProvider: container.duration != null ? container.duration : -1,
                elapsedOverall: (haxe.Timer.stamp() - sw) * 1000
            });
            return didAddResult;
        };

        // ask for snippets in parallel to asking "real" providers. Only do something if configured to
        // do so - no snippet filter, no special-providers-only request
        final snippetCompletions:Promise<Any> = (() -> {
            if (snippetSuggestSupport == null || opts.kindFilter.indexOf(cityscape.common.languages.CompletionItemKind.Snippet) >= 0) {
                return Promise.resolve(null);
            }
            // we have items from a previous session that we can reuse
            final reuseItems = opts.providerItemsToReuse.get(snippetSuggestSupport);
            if (reuseItems != null) {
                for (item in reuseItems) {
                    result.push(item);
                }
                return Promise.resolve(null);
            }
            if (opts.providerFilter.length > 0 && opts.providerFilter.indexOf(snippetSuggestSupport) < 0) {
                return Promise.resolve(null);
            }
            final sw = haxe.Timer.stamp();
            return Promise.fromCallback(done -> snippetSuggestSupport.provideCompletionItems(model, pos, ctx, tok, done)).then(list -> {
                onCompletionList(snippetSuggestSupport, list, sw);
                return null;
            });
        })();

        // add suggestions from contributed providers - providers are ordered in groups of
        // equal score and once a group produces a result the process stops
        // get provider groups, always add snippet suggestion provider
        final groups = registry.orderedGroups(model);

        return new Promise<CompletionItemModel>((resolve, reject) -> {

            function finish():Void {
                snippetCompletions.done(_ -> {
                    if (tok.isCancellationRequested) {
                        disposables.dispose();
                        reject(new CancellationError());
                        return;
                    }
                    haxe.ds.ArraySort.sort(result, getSuggestionComparator(opts.snippetSortOrder));
                    resolve(new CompletionItemModel(
                        result,
                        needsClipboard,
                        {entries: durations, elapsed: (haxe.Timer.stamp() - sw) * 1000},
                        disposables
                    ));
                }, reject);
            }

            function nextGroup(groupIndex:Int):Void {
                if (groupIndex >= groups.length) {
                    finish();
                    return;
                }
                final providerGroup = groups[groupIndex];

                // for each support in the group ask for suggestions
                var didAddResult = false;
                Promise.all([for (provider in providerGroup) (() -> {
                    // we have items from a previous session that we can reuse
                    if (opts.providerItemsToReuse.exists(provider)) {
                        final items = opts.providerItemsToReuse.get(provider);
                        for (item in items) {
                            result.push(item);
                        }
                        didAddResult = didAddResult || items.length > 0;
                        return Promise.resolve(null);
                    }
                    // check if this provider is filtered out
                    if (opts.providerFilter.length > 0 && opts.providerFilter.indexOf(provider) < 0) {
                        return Promise.resolve(null);
                    }
                    final sw = haxe.Timer.stamp();
                    return Promise.fromCallback(done -> {
                        try {
                            provider.provideCompletionItems(model, pos, ctx, tok, done);
                        }
                        catch (err:Any) {
                            Errors.onUnexpectedExternalError(err);
                            done(null);
                        }
                    }).then(list -> {
                        didAddResult = onCompletionList(provider, list, sw) || didAddResult;
                        return (null : Any);
                    });
                })()]).done(_ -> {
                    if (didAddResult || tok.isCancellationRequested) {
                        finish();
                    }
                    else {
                        nextGroup(groupIndex + 1);
                    }
                }, reject);
            }

            nextGroup(0);
        });
    }

    static function defaultComparator(a:CompletionItem, b:CompletionItem):Int {
        // check with 'sortText'
        if (a.sortTextLow != null && a.sortTextLow.length > 0 && b.sortTextLow != null && b.sortTextLow.length > 0) {
            if (a.sortTextLow < b.sortTextLow) {
                return -1;
            }
            else if (a.sortTextLow > b.sortTextLow) {
                return 1;
            }
        }
        // check with 'label'
        if (a.textLabel < b.textLabel) {
            return -1;
        }
        else if (a.textLabel > b.textLabel) {
            return 1;
        }
        // check with 'type'
        return (a.completion.kind : Int) - (b.completion.kind : Int);
    }

    static function snippetUpComparator(a:CompletionItem, b:CompletionItem):Int {
        if (a.completion.kind != b.completion.kind) {
            if (a.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return -1;
            }
            else if (b.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return 1;
            }
        }
        return defaultComparator(a, b);
    }

    static function snippetDownComparator(a:CompletionItem, b:CompletionItem):Int {
        if (a.completion.kind != b.completion.kind) {
            if (a.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return 1;
            }
            else if (b.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return -1;
            }
        }
        return defaultComparator(a, b);
    }

    public static function getSuggestionComparator(snippetConfig:SnippetSortOrder):(a:CompletionItem, b:CompletionItem) -> Int {
        return switch snippetConfig {
            case SnippetSortOrder.Top: snippetUpComparator;
            case SnippetSortOrder.Bottom: snippetDownComparator;
            case _: defaultComparator;
        };
    }

}

/**
 * Monaco's `QuickSuggestionsOptions`.
 */
class QuickSuggestionsOptions {

    public static function isAllOff(config:InternalQuickSuggestionsOptions):Bool {
        return config.other == 'off' && config.comments == 'off' && config.strings == 'off';
    }

    public static function isAllOn(config:InternalQuickSuggestionsOptions):Bool {
        return config.other == 'on' && config.comments == 'on' && config.strings == 'on';
    }

    public static function valueFor(config:InternalQuickSuggestionsOptions, tokenType:StandardTokenType):QuickSuggestionsValue {
        return switch tokenType {
            case StandardTokenType.Comment: config.comments;
            case StandardTokenType.String: config.strings;
            default: config.other;
        };
    }

}
