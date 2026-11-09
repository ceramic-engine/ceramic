// Ported from vscode src/vs/editor/contrib/inlineCompletions/test/browser/suggestWidgetModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.inlineCompletions;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.CompletionItemKind;
import cityscape.contrib.inlineCompletions.view.controller.InlineCompletionsController;
import cityscape.contrib.inlineCompletions.view.model.InlineCompletionsModel;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.contrib.suggest.view.SuggestController;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.CeramicTimeTravel;
import tests.contrib.inlineCompletions.InlineCompletionsTestUtils;

/**
 * suite('Suggest Widget Model'). Not ported: 'Active' (skipped in vscode,
 * its fix causes https://github.com/microsoft/vscode/issues/166023).
 * The word based completions are off (vscode's test editor worker gives
 * no words).
 */
class SuggestWidgetModelTest extends TestCase {

    static inline function timeout(ms:Float):Void {
        CeramicTimeTravel.advance(ms);
    }

    function testGhostText() {
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {suggest: {preview: true}}, (editor, model, context) -> {
            context.keyboardType('h');
            final suggestController:SuggestController = editor.getContribution(SuggestController.ID);
            suggestController.triggerSuggest();
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['', 'h[ello]']);

            context.keyboardType('.');
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['h', 'hello.[hello]']);

            suggestController.cancelSuggestWidget();

            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['hello.']);
        });
    }

    static function withAsyncTestCodeEditorAndInlineCompletionsModel(
        text:String,
        options:IEditorOptions,
        callback:(editor:TestCodeEditor, model:InlineCompletionsModel, context:GhostTextContext) -> Void
    ):Void {
        final cityscape = new Cityscape();
        cityscape.wordBasedSuggestions = 'off';
        cityscape.languageFeaturesService.completionProvider.register('*', new HelloCompletionProvider());
        TestCodeEditor.withTestCodeEditor(text, options, (editor, viewModel) -> {
            editor.registerAndInstantiateContribution(SnippetController2.ID, e -> new SnippetController2(e));
            editor.registerAndInstantiateContribution(SuggestController.ID, e -> new SuggestController(e));
            editor.registerAndInstantiateContribution(InlineCompletionsController.ID, e -> new InlineCompletionsController(e));
            final model = InlineCompletionsController.get(editor).model.get();

            final context = new GhostTextContext(model, editor);
            var error:Null<haxe.Exception> = null;
            try {
                callback(editor, model, context);
            }
            catch (e:haxe.Exception) {
                error = e;
            }
            context.dispose();
            if (error != null) {
                throw error;
            }
        }, cityscape);
    }

}

private class HelloCompletionProvider implements CompletionItemProvider {
    public var _debugDisplayName(default, null):Null<String> = 'test';
    public var triggerCharacters(default, null):Null<Array<String>> = ['.'];
    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void> = null;

    public function new() {}

    public function provideCompletionItems(model:ITextModel, pos:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        final word = model.getWordAtPosition(pos);
        final range:IRange = word != null
            ? {startLineNumber: 1, startColumn: word.startColumn, endLineNumber: 1, endColumn: word.endColumn}
            : Range.fromPositions(pos);

        resolve({
            suggestions: [{
                insertText: 'hello',
                kind: CompletionItemKind.Text,
                label: 'hello',
                range: range,
                commitCharacters: ['.'],
            }]
        });
    }
}
