// Ported from vscode src/vs/editor/contrib/suggest/browser/completionModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.base.common.Arrays;
import cityscape.base.common.CharCode;
import cityscape.base.common.Filters;
import cityscape.base.common.Strings;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.config.EditorOptions.InternalSuggestOptions;
import cityscape.contrib.suggest.view.Suggest.CompletionItem;
import cityscape.contrib.suggest.view.WordDistance;

typedef ICompletionStats = {
    var pLabelLen:Float;
}

/**
 * The text before the cursor and how many characters were typed since the
 * completion request (Monaco's `LineContext` of completionModel.ts).
 */
typedef CompletionLineContext = {
    final leadingLineContent:String;
    final characterCountDelta:Int;
}

private enum abstract Refilter(Int) {
    var Nothing = 0;
    var All = 1;
    var Incr = 2;
}

/**
 * Sorted, filtered completion view model
 */
class CompletionModel {

    final _items:Array<CompletionItem>;
    final _column:Int;
    final _wordDistance:WordDistance;
    final _options:InternalSuggestOptions;
    final _snippetCompareFn:(a:CompletionItem, b:CompletionItem) -> Int;
    final _fuzzyScoreOptions:FuzzyScoreOptions;

    var _lineContext:CompletionLineContext;
    var _refilterKind:Refilter;
    var _filteredItems:Null<Array<CompletionItem>> = null;

    var _itemsByProvider:Null<Map<CompletionItemProvider, Array<CompletionItem>>> = null;
    var _providers:Null<Array<CompletionItemProvider>> = null;
    var _stats:Null<ICompletionStats> = null;

    public final clipboardText:Null<String>;

    /**
     * @param snippetSuggestions `'top'`, `'bottom'`, `'inline'` or `'none'`
     */
    public function new(items:Array<CompletionItem>, column:Int, lineContext:CompletionLineContext, wordDistance:WordDistance, options:InternalSuggestOptions, snippetSuggestions:String, ?fuzzyScoreOptions:FuzzyScoreOptions, ?clipboardText:String) {
        this._items = items;
        this._column = column;
        this._wordDistance = wordDistance;
        this._options = options;
        this._refilterKind = Refilter.All;
        this._lineContext = lineContext;
        this._fuzzyScoreOptions = fuzzyScoreOptions != null ? fuzzyScoreOptions : FuzzyScoreOptions.defaultOptions;
        this.clipboardText = clipboardText;

        if (snippetSuggestions == 'top') {
            this._snippetCompareFn = CompletionModel._compareCompletionItemsSnippetsUp;
        }
        else if (snippetSuggestions == 'bottom') {
            this._snippetCompareFn = CompletionModel._compareCompletionItemsSnippetsDown;
        }
        else {
            this._snippetCompareFn = CompletionModel._compareCompletionItems;
        }
    }

    public var lineContext(get, set):CompletionLineContext;

    function get_lineContext():CompletionLineContext {
        return this._lineContext;
    }

    function set_lineContext(value:CompletionLineContext):CompletionLineContext {
        if (this._lineContext.leadingLineContent != value.leadingLineContent
            || this._lineContext.characterCountDelta != value.characterCountDelta
        ) {
            this._refilterKind = this._lineContext.characterCountDelta < value.characterCountDelta && this._filteredItems != null ? Refilter.Incr : Refilter.All;
            this._lineContext = value;
        }
        return value;
    }

    public var items(get, never):Array<CompletionItem>;
    function get_items():Array<CompletionItem> {
        this._ensureCachedState();
        return this._filteredItems;
    }

    /**
     * The items by provider (in the order the providers were first met).
     */
    public function getItemsByProvider():Map<CompletionItemProvider, Array<CompletionItem>> {
        this._ensureCachedState();
        return this._itemsByProvider;
    }

    /**
     * The providers of `getItemsByProvider`, in the order they were first
     * met (a JavaScript `Map` keeps that order, a Haxe `Map` does not).
     */
    public function getProviders():Array<CompletionItemProvider> {
        this._ensureCachedState();
        return this._providers;
    }

    public function getIncompleteProvider():Array<CompletionItemProvider> {
        this._ensureCachedState();
        final result:Array<CompletionItemProvider> = [];
        for (provider in this._providers) {
            final items = this._itemsByProvider.get(provider);
            if (items.length > 0 && items[0].container.incomplete == true) {
                result.push(provider);
            }
        }
        return result;
    }

    public var stats(get, never):ICompletionStats;
    function get_stats():ICompletionStats {
        this._ensureCachedState();
        return this._stats;
    }

    function _ensureCachedState():Void {
        if (this._refilterKind != Refilter.Nothing) {
            this._createCachedState();
        }
    }

    function _createCachedState():Void {

        this._itemsByProvider = new Map();
        this._providers = [];

        final labelLengths:Array<Int> = [];

        final leadingLineContent = this._lineContext.leadingLineContent;
        final characterCountDelta = this._lineContext.characterCountDelta;
        var word = '';
        var wordLow = '';

        // incrementally filter less
        final source = this._refilterKind == Refilter.All ? this._items : this._filteredItems;
        final target:Array<CompletionItem> = [];

        // picks a score function based on the number of
        // items that we have to score/filter and based on the
        // user-configuration
        final scoreFn:FuzzyScorer = (!this._options.filterGraceful || source.length > 2000) ? Filters.fuzzyScore : Filters.fuzzyScoreGracefulAggressive;

        for (i in 0...source.length) {

            final item = source[i];

            if (item.isInvalid) {
                continue; // SKIP invalid items
            }

            // keep all items by their provider
            final arr = this._itemsByProvider.get(item.provider);
            if (arr != null) {
                arr.push(item);
            }
            else {
                this._itemsByProvider.set(item.provider, [item]);
                this._providers.push(item.provider);
            }

            // 'word' is that remainder of the current line that we
            // filter and score against. In theory each suggestion uses a
            // different word, but in practice not - that's why we cache
            final overwriteBefore = item.position.column - item.editStart.column;
            final wordLen = overwriteBefore + characterCountDelta - (item.position.column - this._column);
            if (word.length != wordLen) {
                word = wordLen == 0 ? '' : sliceFromEnd(leadingLineContent, wordLen);
                wordLow = word.toLowerCase();
            }

            // remember the word against which this item was
            // scored
            item.word = word;

            if (wordLen == 0) {
                // when there is nothing to score against, don't
                // event try to do. Use a const rank and rely on
                // the fallback-sort using the initial sort order.
                // use a score of `-100` because that is out of the
                // bound of values `fuzzyScore` will return
                item.score = FuzzyScore.Default;

            }
            else {
                // skip word characters that are whitespace until
                // we have hit the replace range (overwriteBefore)
                var wordPos = 0;
                while (wordPos < overwriteBefore) {
                    final ch = wordPos < word.length ? StringTools.fastCodeAt(word, wordPos) : -1;
                    if (ch == CharCode.Space || ch == CharCode.Tab) {
                        wordPos += 1;
                    }
                    else {
                        break;
                    }
                }

                if (wordPos >= wordLen) {
                    // the wordPos at which scoring starts is the whole word
                    // and therefore the same rules as not having a word apply
                    item.score = FuzzyScore.Default;

                }
                else if (item.completion.filterText != null) {
                    // when there is a `filterText` it must match the `word`.
                    // if it matches we check with the label to compute highlights
                    // and if that doesn't yield a result we have no highlights,
                    // despite having the match
                    final filterText:String = item.completion.filterText;
                    final match = scoreFn(word, wordLow, wordPos, filterText, item.filterTextLow, 0, this._fuzzyScoreOptions);
                    if (match == null) {
                        continue; // NO match
                    }
                    if (Strings.compareIgnoreCase(filterText, item.textLabel) == 0) {
                        // filterText and label are actually the same -> use good highlights
                        item.score = match;
                    }
                    else {
                        // re-run the scorer on the label in the hope of a result BUT use the rank
                        // of the filterText-match
                        item.score = Filters.anyScore(word, wordLow, wordPos, item.textLabel, item.labelLow, 0);
                        item.score[0] = match[0]; // use score from filterText
                    }

                }
                else {
                    // by default match `word` against the `label`
                    final match = scoreFn(word, wordLow, wordPos, item.textLabel, item.labelLow, 0, this._fuzzyScoreOptions);
                    if (match == null) {
                        continue; // NO match
                    }
                    item.score = match;
                }
            }

            item.idx = i;
            item.distance = this._wordDistance.distance(item.position, item.completion);
            target.push(item);

            // update stats
            labelLengths.push(item.textLabel.length);
        }

        haxe.ds.ArraySort.sort(target, this._snippetCompareFn);
        this._filteredItems = target;
        this._refilterKind = Refilter.Nothing;
        this._stats = {
            pLabelLen: labelLengths.length > 0
                ? Arrays.quickSelect(labelLengths.length - .85, labelLengths, (a, b) -> a - b)
                : 0
        };
    }

    /**
     * JavaScript's `s.slice(-n)`.
     */
    static function sliceFromEnd(s:String, n:Int):String {
        return n >= s.length ? s : s.substr(s.length - n);
    }

    static function _compareCompletionItems(a:CompletionItem, b:CompletionItem):Int {
        if (a.score[0] > b.score[0]) {
            return -1;
        }
        else if (a.score[0] < b.score[0]) {
            return 1;
        }
        else if (a.distance < b.distance) {
            return -1;
        }
        else if (a.distance > b.distance) {
            return 1;
        }
        else if (a.idx < b.idx) {
            return -1;
        }
        else if (a.idx > b.idx) {
            return 1;
        }
        else {
            return 0;
        }
    }

    static function _compareCompletionItemsSnippetsDown(a:CompletionItem, b:CompletionItem):Int {
        if (a.completion.kind != b.completion.kind) {
            if (a.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return 1;
            }
            else if (b.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return -1;
            }
        }
        return CompletionModel._compareCompletionItems(a, b);
    }

    static function _compareCompletionItemsSnippetsUp(a:CompletionItem, b:CompletionItem):Int {
        if (a.completion.kind != b.completion.kind) {
            if (a.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return -1;
            }
            else if (b.completion.kind == cityscape.common.languages.CompletionItemKind.Snippet) {
                return 1;
            }
        }
        return CompletionModel._compareCompletionItems(a, b);
    }

}
