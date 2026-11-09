// Ported from vscode src/vs/editor/contrib/wordHighlighter/browser/textualHighlightProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.wordHighlighter.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Lifecycle;
import cityscape.common.LanguageSelector;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.WordHelper;

class TextualDocumentHighlightProvider implements DocumentHighlightProvider implements MultiDocumentHighlightProvider {

    public var selector(default, null):LanguageSelector = ({language: '*'} : LanguageFilter);

    public function new() {}

    public function provideDocumentHighlights(model:ITextModel, position:Position, token:CancellationToken, resolve:(highlights:Null<Array<DocumentHighlight>>) -> Void):Void {
        final result:Array<DocumentHighlight> = [];

        final word = model.getWordAtPosition({
            lineNumber: position.lineNumber,
            column: position.column
        });

        if (word == null) {
            resolve(result);
            return;
        }

        if (model.isDisposed()) {
            resolve(null);
            return;
        }

        final matches = model.findMatches(word.word, true, false, true, WordHelper.USUAL_WORD_SEPARATORS, false);
        resolve([for (m in matches) ({
            range: m.range,
            kind: DocumentHighlightKind.Text
        } : DocumentHighlight)]);
    }

    public function provideMultiDocumentHighlights(primaryModel:ITextModel, position:Position, otherModels:Array<ITextModel>, token:CancellationToken, resolve:(highlights:Null<Map<String, Array<DocumentHighlight>>>) -> Void):Void {

        final result = new Map<String, Array<DocumentHighlight>>();

        final word = primaryModel.getWordAtPosition({
            lineNumber: position.lineNumber,
            column: position.column
        });
        if (word == null) {
            resolve(result);
            return;
        }

        for (model in [primaryModel].concat(otherModels)) {
            if (model.isDisposed()) {
                continue;
            }

            final matches = model.findMatches(word.word, true, false, true, WordHelper.USUAL_WORD_SEPARATORS, false);
            final highlights = [for (m in matches) ({
                range: m.range,
                kind: DocumentHighlightKind.Text
            } : DocumentHighlight)];

            result.set(model.uri.toString(), highlights);
        }

        resolve(result);
    }

}

/**
 * Monaco's `TextualMultiDocumentHighlightFeature` (an editor feature):
 * registers the textual provider in the context's registries.
 */
class TextualMultiDocumentHighlightFeature extends Disposable {

    public function new(context:Cityscape) {
        super();
        this._register(context.languageFeaturesService.documentHighlightProvider.register('*', new TextualDocumentHighlightProvider()));
        this._register(context.languageFeaturesService.multiDocumentHighlightProvider.register('*', new TextualDocumentHighlightProvider()));
    }

}
