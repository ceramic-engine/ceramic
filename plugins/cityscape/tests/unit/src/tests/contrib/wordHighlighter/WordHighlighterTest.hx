// New code for Cityscape (not a port): tests of the word highlighter
// (contrib/wordHighlighter). vscode has no test suite for it; the expected
// ranges follow from Monaco's code (textual matches of the word under the
// cursor, whole word and case sensitive, `USUAL_WORD_SEPARATORS`).
package tests.contrib.wordHighlighter;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.wordHighlighter.view.WordHighlighter;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

private class KindProvider implements DocumentHighlightProvider {

    public var calls:Int = 0;

    public function new() {}

    public function provideDocumentHighlights(model:ITextModel, position:Position, token:CancellationToken, resolve:(highlights:Null<Array<DocumentHighlight>>) -> Void):Void {
        calls++;
        // a write on line 1 and a read on line 2, whatever the word
        resolve([
            {range: new Range(1, 1, 1, 4), kind: DocumentHighlightKind.Write},
            {range: new Range(2, 1, 2, 4), kind: DocumentHighlightKind.Read}
        ]);
    }

}

/**
 * The textual highlights (`TextualDocumentHighlightProvider`), the
 * `occurrencesHighlight` option, a documentHighlight provider taking over,
 * navigation between highlights, and several editors of one context.
 */
class WordHighlighterTest extends TestCase {

    static final TEXT = [
        'foo bar foo',
        'foo.bar = Foo;',
        'foobar foo_'
    ];

    function withEditor(context:Cityscape, text:Array<String>, ?options:cityscape.common.config.EditorOptions.IEditorOptions, callback:(editor:TestCodeEditor) -> Void, ?languageId:String):Void {
        final model = TestTextModel.instantiateTextModel(context, text.join('\n'), languageId);
        final editor = new TestCodeEditor(context, model, options != null ? options : {}, context.editorExtensions.getSomeEditorContributions([WordHighlighterContribution.ID]));
        editor.getViewModel().setHasFocus(true);
        try {
            callback(editor);
        }
        catch (e:Dynamic) {
            editor.dispose();
            model.dispose();
            throw e;
        }
        editor.dispose();
        model.dispose();
    }

    static function moveTo(editor:TestCodeEditor, lineNumber:Int, column:Int):Void {
        editor.setSelections([new Selection(lineNumber, column, lineNumber, column)], 'test', CursorChangeReason.Explicit);
        WordHighlighterContribution.get(editor)._flushPendingUpdate();
    }

    /**
     * The highlights of the model, each listed once: Monaco's
     * `renderDecorations` adds every highlight twice, through
     * `changeDecorations` (the ids kept per model) and through the
     * decorations collection of the editor (`testHighlightsAreSetTwiceLikeMonaco`).
     */
    static function highlights(editor:TestCodeEditor):String {
        final result:Array<String> = [];
        for (d in editor.getModel().getAllDecorations()) {
            final className = d.options.className;
            if (className == 'wordHighlight' || className == 'wordHighlightStrong' || className == 'wordHighlightText') {
                final entry = Range.lift(d.range).toString() + ':' + className;
                if (result.indexOf(entry) == -1) {
                    result.push(entry);
                }
            }
        }
        result.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return result.join(' ');
    }

    function testTextualOccurrencesOfTheWordUnderTheCursor() {
        withEditor(new Cityscape(), TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            // `foo`, whole word and case sensitive: not `Foo`, `foobar`, `foo_`
            assertEquals('[1,1 -> 1,4]:wordHighlightText [1,9 -> 1,12]:wordHighlightText [2,1 -> 2,4]:wordHighlightText', highlights(editor));
            assertEquals(true, editor.contextKeyService.getContextKeyValue('hasWordHighlights'));
        });
    }

    function testHighlightsAreSetTwiceLikeMonaco() {
        withEditor(new Cityscape(), TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 6);
            assertEquals(4, [for (d in editor.getModel().getAllDecorations()) if (d.options.className == 'wordHighlightText') d].length);
            assertEquals(2, WordHighlighterContribution.get(editor).wordHighlighter.decorations.length);
        });
    }

    function testMovingInsideAHighlightKeepsIt() {
        withEditor(new Cityscape(), TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            moveTo(editor, 1, 10);
            assertEquals('[1,1 -> 1,4]:wordHighlightText [1,9 -> 1,12]:wordHighlightText [2,1 -> 2,4]:wordHighlightText', highlights(editor));
            // another word
            moveTo(editor, 1, 6);
            assertEquals('[1,5 -> 1,8]:wordHighlightText [2,5 -> 2,8]:wordHighlightText', highlights(editor));
        });
    }

    function testNoHighlightOutsideAWordOrWithAMultiLineSelection() {
        withEditor(new Cityscape(), TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            // between `=` and ` `: no word
            moveTo(editor, 2, 10);
            assertEquals('', highlights(editor));
            moveTo(editor, 1, 2);
            editor.setSelections([new Selection(1, 2, 2, 2)], 'test', CursorChangeReason.Explicit);
            WordHighlighterContribution.get(editor)._flushPendingUpdate();
            assertEquals('', highlights(editor));
            assertEquals(false, editor.contextKeyService.getContextKeyValue('hasWordHighlights'));
        });
    }

    function testTypingStopsTheHighlights() {
        withEditor(new Cityscape(), TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            editor.setSelections([new Selection(1, 3, 1, 3)], 'test', CursorChangeReason.NotSet);
            WordHighlighterContribution.get(editor)._flushPendingUpdate();
            assertEquals('', highlights(editor));
        });
    }

    function testOccurrencesHighlightOff() {
        withEditor(new Cityscape(), TEXT, {occurrencesHighlight: 'off'}, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            assertEquals('', highlights(editor));
            editor.updateOptions({occurrencesHighlight: 'singleFile'});
            moveTo(editor, 1, 6);
            assertEquals('[1,5 -> 1,8]:wordHighlightText [2,5 -> 2,8]:wordHighlightText', highlights(editor));
            editor.updateOptions({occurrencesHighlight: 'off'});
            assertEquals('', highlights(editor));
        });
    }

    function testMoveNextAndBack() {
        withEditor(new Cityscape(), TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            final contribution = WordHighlighterContribution.get(editor);
            contribution.moveNext();
            assertEquals('(1,9)', editor.getPosition().toString());
            contribution.moveNext();
            assertEquals('(2,1)', editor.getPosition().toString());
            contribution.moveNext();
            assertEquals('(1,1)', editor.getPosition().toString());
            contribution.moveBack();
            assertEquals('(2,1)', editor.getPosition().toString());
            // the highlights stay
            assertEquals('[1,1 -> 1,4]:wordHighlightText [1,9 -> 1,12]:wordHighlightText [2,1 -> 2,4]:wordHighlightText', highlights(editor));
        });
    }

    function testNavigationActionsNeedHighlights() {
        withEditor(new Cityscape(), TEXT, (editor:TestCodeEditor) -> {
            editor.setPosition(new Position(1, 2));
            // `hasWordHighlights` is false: the keybinding of F7 does not apply
            assertEquals(false, editor.contextKeyService.getContextKeyValue('hasWordHighlights'));
            assertFalse(editor.getAction('editor.action.wordHighlight.next').isSupported());
            // (an explicit move to the same position fires no cursor event)
            moveTo(editor, 1, 3);
            assertEquals(true, editor.contextKeyService.getContextKeyValue('hasWordHighlights'));
            assertTrue(editor.getAction('editor.action.wordHighlight.next').isSupported());
            editor.trigger('test', 'editor.action.wordHighlight.next', null);
            assertEquals('(1,9)', editor.getPosition().toString());
            editor.trigger('test', 'editor.action.wordHighlight.prev', null);
            assertEquals('(1,1)', editor.getPosition().toString());
        });
    }

    function testDocumentHighlightProviderTakesOver() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'kinds'});
        final provider = new KindProvider();
        context.languageFeaturesService.documentHighlightProvider.register('kinds', provider);
        withEditor(context, TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            assertEquals(1, provider.calls);
            assertEquals('[1,1 -> 1,4]:wordHighlightStrong [2,1 -> 2,4]:wordHighlight', highlights(editor));
        }, 'kinds');
        // other languages keep the textual highlights
        withEditor(context, TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 6);
            assertEquals('[1,5 -> 1,8]:wordHighlightText [2,5 -> 2,8]:wordHighlightText', highlights(editor));
        });
    }

    function testMultiFileHighlightsInEveryEditorOfTheContext() {
        final context = new Cityscape();
        final other = TestTextModel.instantiateTextModel(context, 'let foo = 1;\nfoo++;');
        final otherEditor = new TestCodeEditor(context, other, {}, context.editorExtensions.getSomeEditorContributions([WordHighlighterContribution.ID]));
        withEditor(context, TEXT, {occurrencesHighlight: 'multiFile'}, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            assertEquals('[1,1 -> 1,4]:wordHighlightText [1,9 -> 1,12]:wordHighlightText [2,1 -> 2,4]:wordHighlightText', highlights(editor));
            assertEquals('[1,5 -> 1,8]:wordHighlightText [2,1 -> 2,4]:wordHighlightText', highlights(otherEditor));
            // a new word clears the other model too
            moveTo(editor, 1, 6);
            assertEquals('', highlights(otherEditor));
        });
        otherEditor.dispose();
        other.dispose();
    }

    function testSingleFileLeavesOtherEditorsAlone() {
        final context = new Cityscape();
        final other = TestTextModel.instantiateTextModel(context, 'let foo = 1;');
        final otherEditor = new TestCodeEditor(context, other, {}, context.editorExtensions.getSomeEditorContributions([WordHighlighterContribution.ID]));
        withEditor(context, TEXT, (editor:TestCodeEditor) -> {
            moveTo(editor, 1, 2);
            assertEquals('', highlights(otherEditor));
        });
        otherEditor.dispose();
        other.dispose();
    }

    function testTwoContextsDoNotShareTheirQuery() {
        final a = new Cityscape();
        final b = new Cityscape();
        withEditor(a, TEXT, (editorA:TestCodeEditor) -> {
            moveTo(editorA, 1, 2);
            withEditor(b, TEXT, (editorB:TestCodeEditor) -> {
                // a new editor of a context with a query highlights from it (Monaco's static query): not across contexts
                assertEquals('', highlights(editorB));
            });
            assertEquals('[1,1 -> 1,4]:wordHighlightText [1,9 -> 1,12]:wordHighlightText [2,1 -> 2,4]:wordHighlightText', highlights(editorA));
        });
    }

}
