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
import cityscape.common.core.EolCounter;
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.base.common.Lifecycle.IDisposable;

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
        final words = textualSuggestCached(models, word != null ? word.word : null, wordDefRegExp);

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
        final regexp = globalRegExp(wordDef);

        for (model in models) {
            final lineCount = model.getLineCount();
            for (lineNumber in 1...lineCount + 1) {
                final words = wordsOfLine(model.getLineContent(lineNumber), regexp);
                if (collectWords(words, leadingWord, seen, result)) {
                    return result;
                }
            }
        }

        return result;
    }

    /**
     * `textualSuggest` with the words of each line kept between calls, like
     * the mirror models of Monaco's editor worker: only the lines changed
     * since the last call are scanned with the word definition again. Same
     * result as `textualSuggest`.
     */
    public function textualSuggestCached(models:Array<ITextModel>, leadingWord:Null<String>, wordDef:RegExp):Array<String> {
        final seen = new Map<String, Bool>();
        final result:Array<String> = [];

        for (model in models) {
            final cache = cacheOf(model, wordDef);
            final lines = cache.lines;
            final lineCount = lines.length;
            for (i in 0...lineCount) {
                var words = lines[i];
                if (words == null) {
                    words = wordsOfLine(model.getLineContent(i + 1), cache.regexp);
                    lines[i] = words;
                }
                if (collectWords(words, leadingWord, seen, result)) {
                    return result;
                }
            }
        }

        return result;
    }

    /**
     * Adds the words of a line not seen yet to `result`; true when the
     * limit is passed.
     */
    static function collectWords(words:Array<String>, leadingWord:Null<String>, seen:Map<String, Bool>, result:Array<String>):Bool {
        for (j in 0...words.length) {
            final word = words[j];
            if (word == leadingWord) {
                continue;
            }
            if (!seen.exists(word)) {
                seen.set(word, true);
                result.push(word);
                if (result.length > _suggestionsLimit) {
                    return true;
                }
            }
        }
        return false;
    }

    static function globalRegExp(wordDef:RegExp):RegExp {
        return new RegExp(wordDef.source, wordDef.flags.indexOf('g') >= 0 ? wordDef.flags : wordDef.flags + 'g');
    }

    static final noWords:Array<String> = [];

    /**
     * The words of a line, in order, without the numbers (`!isNaN(Number(word))`).
     */
    static function wordsOfLine(content:String, regexp:RegExp):Array<String> {
        var words:Null<Array<String>> = null;
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
            if (isNumber(word)) {
                continue;
            }
            if (words == null) {
                words = [];
            }
            words.push(word);
        }
        return words != null ? words : noWords;
    }

    /**
     * `!isNaN(Number(word))`. A word starting with an ASCII letter is never
     * a number, except `Infinity`: those skip the conversion.
     */
    static inline function isNumber(word:String):Bool {
        final c = StringTools.fastCodeAt(word, 0);
        if ((c >= 'a'.code && c <= 'z'.code) || ((c >= 'A'.code && c <= 'Z'.code) && c != 'I'.code)) {
            return false;
        }
        return !Math.isNaN(JsValues.toNumber(word));
    }

    final caches:Map<String, ModelWords> = new Map();

    function cacheOf(model:ITextModel, wordDef:RegExp):ModelWords {
        var cache = caches.get(model.id);
        if (cache != null && (cache.model != model || cache.versionId != model.getVersionId() || cache.source != wordDef.source || cache.flags != wordDef.flags)) {
            cache.dispose();
            caches.remove(model.id);
            cache = null;
        }
        if (cache == null) {
            cache = new ModelWords(this, model, wordDef, globalRegExp(wordDef));
            caches.set(model.id, cache);
        }
        return cache;
    }

    @:allow(cityscape.common.services)
    function dropCache(cache:ModelWords):Void {
        if (caches.get(cache.model.id) == cache) {
            caches.remove(cache.model.id);
        }
        cache.dispose();
    }

    /**
     * The number of models whose words are kept (tests).
     */
    public function cachedModelCount():Int {
        var count = 0;
        for (_ in caches) {
            count++;
        }
        return count;
    }

}

/**
 * The words of each line of a model (`null` for a line to scan again),
 * kept in step with the model's content changes like the lines of a
 * mirror model of Monaco's editor worker.
 */
@:allow(cityscape.common.services)
private class ModelWords {

    final provider:WordBasedCompletionItemProvider;

    final model:ITextModel;

    final source:String;

    final flags:String;

    final regexp:RegExp;

    var lines:Array<Null<Array<String>>> = [];

    var versionId:Int;

    var listeners:Array<IDisposable>;

    final eolCount = new EolCount();

    public function new(provider:WordBasedCompletionItemProvider, model:ITextModel, wordDef:RegExp, regexp:RegExp) {
        this.provider = provider;
        this.model = model;
        this.source = wordDef.source;
        this.flags = wordDef.flags;
        this.regexp = regexp;
        this.versionId = model.getVersionId();
        resetLines();
        listeners = [
            model.onDidChangeContent(onContentChanged),
            model.onWillDispose(() -> provider.dropCache(this))
        ];
    }

    function resetLines():Void {
        final lineCount = model.getLineCount();
        lines.resize(lineCount);
        for (i in 0...lineCount) {
            lines[i] = null;
        }
    }

    function onContentChanged(e:IModelContentChangedEvent):Void {
        if (e.isFlush) {
            resetLines();
        }
        else {
            // In sequence, like MirrorTextModel.onEvents
            for (change in e.changes) {
                final range = change.range;
                final start = range.startLineNumber - 1;
                final removed = range.endLineNumber - range.startLineNumber;
                final added = EolCounter.countEOL(change.text, eolCount).eolCount;
                lines[start] = null;
                if (removed != added) {
                    if (removed > 0) {
                        lines.splice(start + 1, removed);
                    }
                    if (added > 8) {
                        final inserted:Array<Null<Array<String>>> = [];
                        inserted.resize(added);
                        lines = lines.slice(0, start + 1).concat(inserted).concat(lines.slice(start + 1));
                    }
                    else {
                        for (_ in 0...added) {
                            lines.insert(start + 1, null);
                        }
                    }
                }
                else {
                    for (i in 1...added + 1) {
                        lines[start + i] = null;
                    }
                }
            }
        }
        versionId = e.versionId;
        if (lines.length != model.getLineCount()) {
            // Out of step (should not happen): scan everything again
            resetLines();
        }
    }

    public function dispose():Void {
        if (listeners != null) {
            for (listener in listeners) {
                listener.dispose();
            }
            listeners = null;
        }
    }

}
