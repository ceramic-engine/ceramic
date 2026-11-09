// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/model/provideInlineCompletions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.model;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.base.common.Strings;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextEdit.SingleTextEdit;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.model.bracketPairsTextModelPart.FixBrackets;
import cityscape.contrib.snippet.view.SnippetParser;

/**
 * Module functions of provideInlineCompletions.ts. The result is a
 * `Promise` (settled at once when the providers answer at once). Monaco's
 * `provideInlineEdits` (a range instead of a position, experimental and
 * internal) is not ported: `provideInlineCompletions` takes a position.
 */
class ProvideInlineCompletions {

    public static function provideInlineCompletions(
        registry:LanguageFeatureRegistry<InlineCompletionsProvider>,
        position:Position,
        model:ITextModel,
        context:InlineCompletionContext,
        ?token:CancellationToken,
        ?languageConfigurationService:ILanguageConfigurationService
    ):Promise<InlineCompletionProviderResult> {
        if (token == null) {
            token = CancellationTokens.None;
        }
        // Important: Don't use position after the await calls, as the model could have been changed in the meantime!
        final defaultReplaceRange = getDefaultRange(position, model);
        final providers = registry.all(model);

        // SetMap<InlineCompletionProviderGroupId, InlineCompletionsProvider>
        final multiMap = new Map<String, Array<InlineCompletionsProvider>>();
        for (provider in providers) {
            if (provider.groupId != null) {
                var set = multiMap.get(provider.groupId);
                if (set == null) {
                    set = [];
                    multiMap.set(provider.groupId, set);
                }
                if (set.indexOf(provider) == -1) {
                    set.push(provider);
                }
            }
        }

        function getPreferredProviders(provider:InlineCompletionsProvider):Array<InlineCompletionsProvider> {
            if (provider.yieldsToGroupIds == null) {
                return [];
            }
            final result:Array<InlineCompletionsProvider> = [];
            for (groupId in provider.yieldsToGroupIds) {
                final providers = multiMap.get(groupId);
                if (providers != null) {
                    for (p in providers) {
                        result.push(p);
                    }
                }
            }
            return result;
        }

        // Map<provider, Promise>: arrays in insertion order
        final stateProviders:Array<InlineCompletionsProvider> = [];
        final statePromises:Array<Promise<Null<InlineCompletions>>> = [];

        final seen:Array<InlineCompletionsProvider> = [];
        function findPreferredProviderCircle(provider:InlineCompletionsProvider, stack:Array<InlineCompletionsProvider>):Null<Array<InlineCompletionsProvider>> {
            stack = stack.concat([provider]);
            if (seen.indexOf(provider) != -1) {
                return stack;
            }

            seen.push(provider);
            var found:Null<Array<InlineCompletionsProvider>> = null;
            final preferred = getPreferredProviders(provider);
            for (p in preferred) {
                final c = findPreferredProviderCircle(p, stack);
                if (c != null) {
                    found = c;
                    break;
                }
            }
            seen.remove(provider);
            return found;
        }

        var processProvider:(provider:InlineCompletionsProvider) -> Promise<Null<InlineCompletions>> = null;
        processProvider = (provider:InlineCompletionsProvider) -> {
            final stateIndex = stateProviders.indexOf(provider);
            if (stateIndex != -1) {
                return statePromises[stateIndex];
            }

            final circle = findPreferredProviderCircle(provider, []);
            if (circle != null) {
                Errors.onUnexpectedExternalError('Inline completions: cyclic yield-to dependency detected. Path: ' + [for (s in circle) Std.string(s)].join(' -> '));
            }

            // DeferredPromise
            var complete:Null<(value:Null<InlineCompletions>) -> Void> = null;
            final deferredPromise = new Promise<Null<InlineCompletions>>((resolve, _) -> complete = resolve);
            stateProviders.push(provider);
            statePromises.push(deferredPromise);

            function callProvider():Void {
                try {
                    provider.provideInlineCompletions(model, position, context, token, completions -> complete(completions));
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedExternalError(e);
                    complete(null);
                }
            }

            if (circle == null) {
                final preferred = getPreferredProviders(provider);
                var step:(i:Int) -> Void = null;
                step = (i:Int) -> {
                    if (i >= preferred.length) {
                        callProvider();
                        return;
                    }
                    processProvider(preferred[i]).done(result -> {
                        if (result != null && result.items.length > 0) {
                            // Skip provider
                            complete(null);
                        }
                        else {
                            step(i + 1);
                        }
                    }, _ -> step(i + 1));
                };
                step(0);
            }
            else {
                callProvider();
            }

            return deferredPromise;
        };

        final promises = [for (provider in providers) processProvider(provider)];

        return Promise.all(promises).then(results -> {
            final itemsByHashKeys:Array<String> = [];
            final itemsByHash = new Map<String, InlineCompletionItem>();
            final lists:Array<InlineCompletionList> = [];
            for (i in 0...providers.length) {
                final completions = results[i];
                if (completions == null) {
                    continue;
                }
                final list = new InlineCompletionList(completions, providers[i]);
                lists.push(list);

                for (item in completions.items) {
                    final inlineCompletionItem = InlineCompletionItem.from(
                        item,
                        list,
                        defaultReplaceRange,
                        model,
                        languageConfigurationService
                    );
                    final hash = inlineCompletionItem.hash();
                    if (!itemsByHash.exists(hash)) {
                        itemsByHashKeys.push(hash);
                    }
                    itemsByHash.set(hash, inlineCompletionItem);
                }
            }

            return new InlineCompletionProviderResult([for (k in itemsByHashKeys) itemsByHash.get(k)], itemsByHashKeys, lists);
        });
    }

    static function getDefaultRange(position:Position, model:ITextModel):Range {
        final word = model.getWordAtPosition(position);
        final maxColumn = model.getLineMaxColumn(position.lineNumber);
        // By default, always replace up until the end of the current line.
        // This default might be subject to change!
        return word != null
            ? new Range(position.lineNumber, word.startColumn, position.lineNumber, maxColumn)
            : Range.fromPositions(position, position.with(null, maxColumn));
    }

    @:allow(cityscape.contrib.inlineCompletions.view.model)
    static function closeBrackets(text:String, position:Position, model:ITextModel, languageConfigurationService:ILanguageConfigurationService):String {
        final lineStart = model.getLineContent(position.lineNumber).substring(0, position.column - 1);
        final newLine = lineStart + text;

        final newTokens = model.tokenization.tokenizeLineWithEdit(position, newLine.length - (position.column - 1), text);
        final slicedTokens = newTokens != null ? newTokens.sliceAndInflate(position.column - 1, newLine.length, 0) : null;
        if (slicedTokens == null) {
            return text;
        }

        final newText = FixBrackets.fixBracketsInLine(slicedTokens, languageConfigurationService);

        return newText;
    }

}

class InlineCompletionProviderResult implements IDisposable {

    /**
     * Free of duplicates.
     */
    public final completions:Array<InlineCompletionItem>;
    final hashs:Array<String>;
    final providerResults:Array<InlineCompletionList>;

    public function new(completions:Array<InlineCompletionItem>, hashs:Array<String>, providerResults:Array<InlineCompletionList>) {
        this.completions = completions;
        this.hashs = hashs;
        this.providerResults = providerResults;
    }

    public function has(item:InlineCompletionItem):Bool {
        return this.hashs.indexOf(item.hash()) != -1;
    }

    public function dispose():Void {
        for (result in this.providerResults) {
            result.removeRef();
        }
    }

}

/**
 * A ref counted pointer to the computed `InlineCompletions` and the `InlineCompletionsProvider` that
 * computed them.
 */
class InlineCompletionList {

    var refCount:Int = 1;

    public final inlineCompletions:InlineCompletions;
    public final provider:InlineCompletionsProvider;

    public function new(inlineCompletions:InlineCompletions, provider:InlineCompletionsProvider) {
        this.inlineCompletions = inlineCompletions;
        this.provider = provider;
    }

    public function addRef():Void {
        this.refCount++;
    }

    public function removeRef():Void {
        this.refCount--;
        if (this.refCount == 0) {
            this.provider.freeInlineCompletions(this.inlineCompletions);
        }
    }

}

typedef SnippetInfo = {
    var snippet:String;
    /* Could be different than the main range */
    var range:Range;
}

class InlineCompletionItem {

    public static function from(
        inlineCompletion:InlineCompletion,
        source:InlineCompletionList,
        defaultReplaceRange:Range,
        textModel:ITextModel,
        languageConfigurationService:Null<ILanguageConfigurationService>
    ):InlineCompletionItem {
        var insertText:String;
        var snippetInfo:Null<SnippetInfo> = null;
        var range = inlineCompletion.range != null ? Range.lift(inlineCompletion.range) : defaultReplaceRange;

        if (Std.isOfType(inlineCompletion.insertText, std.String)) {
            final originalText:String = cast inlineCompletion.insertText;
            insertText = originalText;

            if (languageConfigurationService != null && inlineCompletion.completeBracketPairs == true) {
                insertText = ProvideInlineCompletions.closeBrackets(
                    insertText,
                    range.getStartPosition(),
                    textModel,
                    languageConfigurationService
                );

                // Modify range depending on if brackets are added or removed
                final diff = insertText.length - originalText.length;
                if (diff != 0) {
                    range = new Range(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn + diff);
                }
            }

            snippetInfo = null;
        }
        else {
            final snippetText:InlineCompletionSnippet = cast inlineCompletion.insertText;
            final preBracketCompletionLength = snippetText.snippet.length;

            if (languageConfigurationService != null && inlineCompletion.completeBracketPairs == true) {
                snippetText.snippet = ProvideInlineCompletions.closeBrackets(
                    snippetText.snippet,
                    range.getStartPosition(),
                    textModel,
                    languageConfigurationService
                );

                // Modify range depending on if brackets are added or removed
                final diff = snippetText.snippet.length - preBracketCompletionLength;
                if (diff != 0) {
                    range = new Range(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn + diff);
                }
            }

            final snippet = new SnippetParser().parse(snippetText.snippet);

            if (snippet.children.length == 1 && Std.isOfType(snippet.children[0], Text)) {
                insertText = (cast snippet.children[0] : Text).value;
                snippetInfo = null;
            }
            else {
                insertText = snippet.toString();
                snippetInfo = {
                    snippet: snippetText.snippet,
                    range: range
                };
            }
        }

        return new InlineCompletionItem(
            insertText,
            inlineCompletion.command,
            range,
            insertText,
            snippetInfo,
            inlineCompletion.additionalTextEdits != null ? inlineCompletion.additionalTextEdits : [],
            inlineCompletion,
            source
        );
    }

    public final filterText:String;
    public final command:Null<Command>;
    public final range:Range;
    public final insertText:String;
    public final snippetInfo:Null<SnippetInfo>;
    public final additionalTextEdits:Array<ISingleEditOperation>;

    /**
     * A reference to the original inline completion this inline completion has been constructed from.
     * Used for event data to ensure referential equality.
     */
    public final sourceInlineCompletion:InlineCompletion;

    /**
     * A reference to the original inline completion list this inline completion has been constructed from.
     * Used for event data to ensure referential equality.
     */
    public final source:InlineCompletionList;

    public function new(
        filterText:String,
        command:Null<Command>,
        range:Range,
        insertText:String,
        snippetInfo:Null<SnippetInfo>,
        additionalTextEdits:Array<ISingleEditOperation>,
        sourceInlineCompletion:InlineCompletion,
        source:InlineCompletionList
    ) {
        // Monaco normalizes the line breaks into its constructor parameters
        // only (`filterText = filterText.replace(...)`), which leaves the
        // fields as given: the fields are kept as given here too.
        this.filterText = filterText;
        this.command = command;
        this.range = range;
        this.insertText = insertText;
        this.snippetInfo = snippetInfo;
        this.additionalTextEdits = additionalTextEdits;
        this.sourceInlineCompletion = sourceInlineCompletion;
        this.source = source;
    }

    public function withRange(updatedRange:Range):InlineCompletionItem {
        return new InlineCompletionItem(
            this.filterText,
            this.command,
            updatedRange,
            this.insertText,
            this.snippetInfo,
            this.additionalTextEdits,
            this.sourceInlineCompletion,
            this.source
        );
    }

    /**
     * `JSON.stringify({ insertText, range: range.toString() })`.
     */
    public function hash():String {
        return '{"insertText":' + haxe.Json.stringify(this.insertText) + ',"range":' + haxe.Json.stringify(this.range.toString()) + '}';
    }

    public function toSingleTextEdit():SingleTextEdit {
        return new SingleTextEdit(this.range, this.insertText);
    }

}
