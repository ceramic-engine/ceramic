// Ported from vscode src/vs/editor/browser/services/editorWorkerService.ts
// (WordBasedCompletionItemProvider) and src/vs/editor/common/services/editorSimpleWorker.ts
// ($textualSuggest, words)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.JsValues;
import cityscape.base.common.RegExp;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * Completes with the words of the open documents (Monaco's
 * `WordBasedCompletionItemProvider`), registered for every language by each
 * `Cityscape` context. Monaco computes the words in its editor worker; here
 * they are computed in place. The setting is the context's
 * `wordBasedSuggestions` (Monaco's global `wordBasedSuggestions` option):
 * `'off'`, `'currentDocument'`, `'matchingDocuments'` (the default) or
 * `'allDocuments'`. The documents are the models of the context's model
 * service and the model asking.
 */
class WordBasedCompletionItemProvider implements CompletionItemProvider {

    static inline final _suggestionsLimit = 10000;

    final context:Cityscape;

    public var _debugDisplayName(default, null):Null<String> = 'wordbasedCompletions';
    public var triggerCharacters(default, null):Null<Array<String>> = null;
    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void> = null;

    public function new(context:Cityscape) {
        this.context = context;
    }

    static function canSyncModel(model:ITextModel):Bool {
        return !model.isTooLargeForSyncing();
    }

    public function provideCompletionItems(model:ITextModel, position:Position, completionContext:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        final setting = context.wordBasedSuggestions;
        if (setting == 'off') {
            resolve(null);
            return;
        }

        final models:Array<ITextModel> = [];
        if (setting == 'currentDocument') {
            // only current file and only if not too large
            if (canSyncModel(model)) {
                models.push(model);
            }
        }
        else {
            // either all files or files of same language
            if (canSyncModel(model)) {
                models.push(model);
            }
            for (candidate in context.modelService.getModels()) {
                if (candidate == model || !canSyncModel(candidate)) {
                    continue;
                }
                if (setting == 'allDocuments' || candidate.getLanguageId() == model.getLanguageId()) {
                    models.push(candidate);
                }
            }
        }

        if (models.length == 0) {
            resolve(null); // File too large, no other files
            return;
        }

        final wordDefRegExp = context.languageConfigurationService.getLanguageConfiguration(model.getLanguageId()).getWordDefinition();
        final word = model.getWordAtPosition(position);
        final replace = word == null ? Range.fromPositions(position) : new Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn);
        final insert = replace.setEndPosition(position.lineNumber, position.column);

        final start = haxe.Timer.stamp();
        final words = textualSuggest(models, word != null ? word.word : null, wordDefRegExp);

        resolve({
            duration: (haxe.Timer.stamp() - start) * 1000,
            suggestions: [for (word in words) ({
                kind: cityscape.common.languages.CompletionItemKind.Text,
                label: word,
                insertText: word,
                range: ({insert: insert, replace: replace} : CompletionItemRanges)
            } : CompletionItem)],
        });
    }

    /**
     * Monaco's `$textualSuggest`: the distinct words of the models (not the
     * leading word, not numbers), at most 10000.
     */
    public static function textualSuggest(models:Array<ITextModel>, leadingWord:Null<String>, wordDef:RegExp):Array<String> {
        final seen = new Map<String, Bool>();
        final result:Array<String> = [];
        final regexp = new RegExp(wordDef.source, wordDef.flags.indexOf('g') >= 0 ? wordDef.flags : wordDef.flags + 'g');

        for (model in models) {
            final lineCount = model.getLineCount();
            for (lineNumber in 1...lineCount + 1) {
                final content = model.getLineContent(lineNumber);
                regexp.lastIndex = 0;
                while (true) {
                    final m = regexp.exec(content);
                    if (m == null) {
                        break;
                    }
                    final word:Null<String> = m[0];
                    if (word == null || word.length == 0) {
                        // empty match: move on
                        regexp.lastIndex = m.index + 1;
                        if (regexp.lastIndex > content.length) {
                            break;
                        }
                        continue;
                    }
                    if (word == leadingWord || !Math.isNaN(JsValues.toNumber(word))) {
                        continue;
                    }
                    if (!seen.exists(word)) {
                        seen.set(word, true);
                        result.push(word);
                        if (result.length > _suggestionsLimit) {
                            return result;
                        }
                    }
                }
            }
        }

        return result;
    }

}
