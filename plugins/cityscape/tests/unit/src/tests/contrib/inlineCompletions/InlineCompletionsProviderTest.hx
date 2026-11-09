// Ported from vscode src/vs/editor/contrib/inlineCompletions/test/browser/inlineCompletionsProvider.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.inlineCompletions;

import cityscape.Cityscape;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.TextEdit.SingleTextEdit;
import cityscape.contrib.inlineCompletions.view.controller.InlineCompletionsController;
import cityscape.contrib.inlineCompletions.view.model.InlineCompletionsModel;
import cityscape.contrib.inlineCompletions.view.model.SingleTextEdit.SingleTextEditUtils;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.CeramicTimeTravel;
import tests.TestTextModel;
import tests.contrib.inlineCompletions.InlineCompletionsTestUtils;

/**
 * suite('Inline Completions'), with its suites 'inlineCompletionToGhostText'
 * and 'inlineCompletionMultiCursor'. vscode's fake timers are
 * `CeramicTimeTravel` (`await timeout(n)` is `timeout(n)`, which runs the
 * timers due in the next n virtual milliseconds); the mock provider answers
 * at once, or after its delay on the virtual clock.
 */
class InlineCompletionsProviderTest extends TestCase {

    static inline function timeout(ms:Float):Void {
        CeramicTimeTravel.advance(ms);
    }

    // suite('inlineCompletionToGhostText')

    function getOutput(text:String, suggestion:String):Any {
        final rangeStartOffset = text.indexOf('[');
        final rangeEndOffset = text.indexOf(']') - 1;
        final cleanedText = StringTools.replace(StringTools.replace(text, '[', ''), ']', '');
        final tempModel = TestTextModel.createTextModel(cleanedText);
        final range = Range.fromPositions(tempModel.getPositionAt(rangeStartOffset), tempModel.getPositionAt(rangeEndOffset));
        final results:Array<Null<String>> = [];
        for (option in ['prefix', 'subword']) {
            final g = SingleTextEditUtils.computeGhostText(new SingleTextEdit(range, suggestion), tempModel, option);
            results.push(g != null ? g.render(cleanedText, true) : null);
        }

        tempModel.dispose();

        if (results[0] == results[1]) {
            return results[0];
        }

        return {prefix: results[0], subword: results[1]};
    }

    function testInlineCompletionToGhostTextBasic() {
        assertDeepEquals(getOutput('[foo]baz', 'foobar'), 'foo[bar]baz');
        assertDeepEquals(getOutput('[aaa]aaa', 'aaaaaa'), 'aaa[aaa]aaa');
        assertDeepEquals(getOutput('[foo]baz', 'boobar'), null);
        assertDeepEquals(getOutput('[foo]foo', 'foofoo'), 'foo[foo]foo');
        assertDeepEquals(getOutput('foo[]', 'bar\nhello'), 'foo[bar\nhello]');
    }

    function testInlineCompletionToGhostTextEmptyGhostText() {
        assertDeepEquals(getOutput('[foo]', 'foo'), 'foo');
    }

    function testInlineCompletionToGhostTextWhitespaceIndentation() {
        assertDeepEquals(getOutput('[ foo]', 'foobar'), ' foo[bar]');
        assertDeepEquals(getOutput('[\tfoo]', 'foobar'), '\tfoo[bar]');
        assertDeepEquals(getOutput('[\t foo]', '\tfoobar'), '	 foo[bar]');
        assertDeepEquals(getOutput('[\tfoo]', '\t\tfoobar'), {prefix: null, subword: '\t[\t]foo[bar]'});
        assertDeepEquals(getOutput('[\t]', '\t\tfoobar'), '\t[\tfoobar]');
        assertDeepEquals(getOutput('\t[]', '\t'), '\t[\t]');
        assertDeepEquals(getOutput('\t[\t]', ''), '\t\t');

        assertDeepEquals(getOutput('[ ]', 'return 1'), ' [return 1]');
    }

    function testInlineCompletionToGhostTextWhitespaceOutsideOfIndentation() {
        assertDeepEquals(getOutput('bar[ foo]', 'foobar'), null);
        assertDeepEquals(getOutput('bar[\tfoo]', 'foobar'), null);
    }

    function testInlineCompletionToGhostTextUnsupportedCase() {
        assertDeepEquals(getOutput('fo[o\n]', 'x\nbar'), null);
    }

    function testInlineCompletionToGhostTextNewLine() {
        assertDeepEquals(getOutput('fo[o\n]', 'o\nbar'), 'foo\n[bar]');
    }

    function testInlineCompletionToGhostTextMultiPartDiffing() {
        assertDeepEquals(getOutput('foo[()]', '(x);'), {prefix: null, subword: 'foo([x])[;]'});
        assertDeepEquals(getOutput('[\tfoo]', '\t\tfoobar'), {prefix: null, subword: '\t[\t]foo[bar]'});
        assertDeepEquals(getOutput('[(y ===)]', '(y === 1) { f(); }'), {prefix: null, subword: '(y ===[ 1])[ { f(); }]'});
        assertDeepEquals(getOutput('[(y ==)]', '(y === 1) { f(); }'), {prefix: null, subword: '(y ==[= 1])[ { f(); }]'});

        assertDeepEquals(getOutput('[(y ==)]', '(y === 1) { f(); }'), {prefix: null, subword: '(y ==[= 1])[ { f(); }]'});
    }

    function testInlineCompletionToGhostTextMultiPartDiffing1() {
        assertDeepEquals(getOutput('[if () ()]', 'if (1 == f()) ()'), {prefix: null, subword: 'if ([1 == f()]) ()'});
    }

    function testInlineCompletionToGhostTextMultiPartDiffing2() {
        assertDeepEquals(getOutput('[)]', '())'), {prefix: null, subword: "[(])[)]"});
        assertDeepEquals(getOutput('[))]', '(())'), {prefix: null, subword: "[((]))"});
    }

    function testInlineCompletionToGhostTextParenthesisMatching() {
        assertDeepEquals(getOutput('[console.log()]', 'console.log({ label: "(" })'), {
            prefix: null,
            subword: 'console.log([{ label: "(" }])'
        });
    }

    // suite('Inline Completions')

    function testDoesNotTriggerAutomaticallyIfDisabled() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {inlineSuggest: {enabled: false}}, provider, (editor, model, context) -> {
            context.keyboardType('foo');
            timeout(1000);

            // Provider is not called, no ghost text is shown.
            assertDeepEquals(provider.getAndClearCallHistory(), []);
            assertDeepEquals(context.getAndClearViewStates(), ['']);
        });
    }

    function testGhostTextIsShownAfterTrigger() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('foo');
            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 4)});
            model.triggerExplicitly();
            timeout(1000);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,4)', text: 'foo', triggerKind: 1}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['', 'foo[bar]']);
        });
    }

    function testGhostTextIsShownAutomaticallyWhenConfigured() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {inlineSuggest: {enabled: true}}, provider, (editor, model, context) -> {
            context.keyboardType('foo');

            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 4)});
            timeout(1000);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,4)', text: 'foo', triggerKind: 0}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['', 'foo[bar]']);
        });
    }

    function testGhostTextIsUpdatedAutomatically() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 4)});
            context.keyboardType('foo');
            model.triggerExplicitly();
            timeout(1000);

            provider.setReturnValue({insertText: 'foobizz', range: new Range(1, 1, 1, 6)});
            context.keyboardType('b');
            context.keyboardType('i');
            timeout(1000);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,4)', text: 'foo', triggerKind: 1},
                {position: '(1,6)', text: 'foobi', triggerKind: 0}
            ]);
            assertDeepEquals(
                context.getAndClearViewStates(),
                ['', 'foo[bar]', 'foob[ar]', 'foobi', 'foobi[zz]']
            );
        });
    }

    function testUnindentWhitespace() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('  ');
            provider.setReturnValue({insertText: 'foo', range: new Range(1, 2, 1, 3)});
            model.triggerExplicitly();
            timeout(1000);

            assertDeepEquals(context.getAndClearViewStates(), ['', '  [foo]']);

            model.accept(editor);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,3)', text: '  ', triggerKind: 1},
            ]);

            assertDeepEquals(context.getAndClearViewStates(), [' foo']);
        });
    }

    function testUnindentTab() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('\t\t');
            provider.setReturnValue({insertText: 'foo', range: new Range(1, 2, 1, 3)});
            model.triggerExplicitly();
            timeout(1000);

            assertDeepEquals(context.getAndClearViewStates(), ['', '\t\t[foo]']);

            model.accept(editor);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,3)', text: '\t\t', triggerKind: 1},
            ]);

            assertDeepEquals(context.getAndClearViewStates(), ['\tfoo']);
        });
    }

    function testNoUnindentAfterIndentation() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('buzz  ');
            provider.setReturnValue({insertText: 'foo', range: new Range(1, 6, 1, 7)});
            model.triggerExplicitly();
            timeout(1000);

            assertDeepEquals(context.getAndClearViewStates(), ['']);

            model.accept(editor);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,7)', text: 'buzz  ', triggerKind: 1},
            ]);

            assertDeepEquals(context.getAndClearViewStates(), []);
        });
    }

    function testNextPrevious() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('foo');
            provider.setReturnValue({insertText: 'foobar1', range: new Range(1, 1, 1, 4)});
            model.trigger();
            timeout(1000);

            assertDeepEquals(
                context.getAndClearViewStates(),
                ['', 'foo[bar1]']
            );

            provider.setReturnValues([
                {insertText: 'foobar1', range: new Range(1, 1, 1, 4)},
                {insertText: 'foobizz2', range: new Range(1, 1, 1, 4)},
                {insertText: 'foobuzz3', range: new Range(1, 1, 1, 4)}
            ]);

            model.next();
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['foo[bizz2]']);

            model.next();
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['foo[buzz3]']);

            model.next();
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['foo[bar1]']);

            model.previous();
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['foo[buzz3]']);

            model.previous();
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['foo[bizz2]']);

            model.previous();
            timeout(1000);
            assertDeepEquals(context.getAndClearViewStates(), ['foo[bar1]']);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,4)', text: 'foo', triggerKind: 0},
                {position: '(1,4)', text: 'foo', triggerKind: 1},
            ]);
        });
    }

    function testCallingTheProviderIsDebounced() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            model.trigger();

            context.keyboardType('f');
            timeout(40);
            context.keyboardType('o');
            timeout(40);
            context.keyboardType('o');
            timeout(40);

            // The provider is not called
            assertDeepEquals(provider.getAndClearCallHistory(), []);

            timeout(400);
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,4)', text: 'foo', triggerKind: 0}
            ]);

            provider.assertNotCalledTwiceWithin50ms();
        });
    }

    function testBackspaceIsDebounced() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {inlineSuggest: {enabled: true}}, provider, (editor, model, context) -> {
            context.keyboardType('foo');

            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 4)});
            timeout(1000);

            for (j in 0...2) {
                for (i in 0...3) {
                    context.leftDelete();
                    timeout(5);
                }

                context.keyboardType('bar');
            }

            timeout(400);

            provider.assertNotCalledTwiceWithin50ms();
        });
    }

    function testForwardStability() {
        // The user types the text as suggested and the provider is forward-stable
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 4)});
            context.keyboardType('foo');
            model.trigger();
            timeout(1000);
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,4)', text: 'foo', triggerKind: 0}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['', 'foo[bar]']);

            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 5)});
            context.keyboardType('b');
            assertEquals(context.currentPrettyViewState, 'foob[ar]');
            timeout(1000);
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,5)', text: 'foob', triggerKind: 0}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['foob[ar]']);

            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 6)});
            context.keyboardType('a');
            assertEquals(context.currentPrettyViewState, 'fooba[r]');
            timeout(1000);
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,6)', text: 'fooba', triggerKind: 0}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['fooba[r]']);
        });
    }

    function testSupportForwardInstability() {
        // The user types the text as suggested and the provider reports a different suggestion.
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 4)});
            context.keyboardType('foo');
            model.triggerExplicitly();
            timeout(100);
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,4)', text: 'foo', triggerKind: 1}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['', 'foo[bar]']);

            provider.setReturnValue({insertText: 'foobaz', range: new Range(1, 1, 1, 5)});
            context.keyboardType('b');
            assertEquals(context.currentPrettyViewState, 'foob[ar]');
            timeout(100);
            // This behavior might change!
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,5)', text: 'foob', triggerKind: 0}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['foob[ar]', 'foob[az]']);
        });
    }

    function testSupportBackwardInstability() {
        // The user deletes text and the suggestion changes
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('fooba');

            provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 6)});

            model.triggerExplicitly();
            timeout(1000);
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,6)', text: 'fooba', triggerKind: 1}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), ['', 'fooba[r]']);

            provider.setReturnValue({insertText: 'foobaz', range: new Range(1, 1, 1, 5)});
            context.leftDelete();
            timeout(1000);
            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(1,5)', text: 'foob', triggerKind: 0}
            ]);
            assertDeepEquals(context.getAndClearViewStates(), [
                'foob[ar]',
                'foob[az]'
            ]);
        });
    }

    function testNoRaceConditions() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('h');
            provider.setReturnValue({insertText: 'helloworld', range: new Range(1, 1, 1, 2)}, 1000);

            model.triggerExplicitly();

            timeout(1030);
            context.keyboardType('ello');
            provider.setReturnValue({insertText: 'helloworld', range: new Range(1, 1, 1, 6)}, 1000);

            // after 20ms: Inline completion provider answers back
            // after 50ms: Debounce is triggered
            timeout(2000);

            assertDeepEquals(context.getAndClearViewStates(), [
                '',
                'hello[world]',
            ]);
        });
    }

    function testDoNotReuseCacheFromPreviousSession132516() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {inlineSuggest: {enabled: true}}, provider, (editor, model, context) -> {
            context.keyboardType('hello\n');
            context.cursorLeft();
            context.keyboardType('x');
            context.leftDelete();
            provider.setReturnValue({insertText: 'helloworld', range: new Range(1, 1, 1, 6)}, 1000);
            timeout(2000);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {
                    position: '(1,6)',
                    text: 'hello\n',
                    triggerKind: 0,
                }
            ]);

            provider.setReturnValue({insertText: 'helloworld', range: new Range(2, 1, 2, 6)}, 1000);

            context.cursorDown();
            context.keyboardType('hello');
            timeout(40);

            assertDeepEquals(provider.getAndClearCallHistory(), []);

            // Update ghost text
            context.keyboardType('w');
            context.leftDelete();

            timeout(2000);

            assertDeepEquals(provider.getAndClearCallHistory(), [
                {position: '(2,6)', triggerKind: 0, text: 'hello\nhello'},
            ]);

            assertDeepEquals(context.getAndClearViewStates(), [
                '',
                'hello[world]\n',
                'hello\n',
                'hello\nhello[world]',
            ]);
        });
    }

    function testAdditionalTextEdits() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('buzz\nbaz');
            provider.setReturnValue({
                insertText: 'bazz',
                range: new Range(2, 1, 2, 4),
                additionalTextEdits: [{
                    range: new Range(1, 1, 1, 5),
                    text: 'bla'
                }],
            });
            model.triggerExplicitly();
            timeout(1000);

            model.accept(editor);

            assertDeepEquals(provider.getAndClearCallHistory(), [{position: "(2,4)", triggerKind: 1, text: "buzz\nbaz"}]);

            assertDeepEquals(context.getAndClearViewStates(), [
                '',
                'buzz\nbaz[z]',
                'bla\nbazz',
            ]);
        });
    }

    // suite('inlineCompletionMultiCursor')

    function testInlineCompletionMultiCursorBasic() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('console\nconsole\n');
            editor.setSelections([
                new Selection(1, 1000, 1, 1000),
                new Selection(2, 1000, 2, 1000),
            ]);
            provider.setReturnValue({
                insertText: 'console.log("hello");',
                range: new Range(1, 1, 1, 1000),
            });
            model.triggerExplicitly();
            timeout(1000);
            model.accept(editor);
            assertEquals(
                editor.getValue(),
                [
                    'console.log("hello");',
                    'console.log("hello");',
                    ''
                ].join('\n')
            );
        });
    }

    function testInlineCompletionMultiCursorMultiPart() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('console.log()\nconsole.log\n');
            editor.setSelections([
                new Selection(1, 12, 1, 12),
                new Selection(2, 1000, 2, 1000),
            ]);
            provider.setReturnValue({
                insertText: 'console.log("hello");',
                range: new Range(1, 1, 1, 1000),
            });
            model.triggerExplicitly();
            timeout(1000);
            model.accept(editor);
            assertEquals(
                editor.getValue(),
                [
                    'console.log("hello");',
                    'console.log("hello");',
                    ''
                ].join('\n')
            );
        });
    }

    function testInlineCompletionMultiCursorMultiPartAndDifferentCursorColumns() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('console.log()\nconsole.warn\n');
            editor.setSelections([
                new Selection(1, 12, 1, 12),
                new Selection(2, 14, 2, 14),
            ]);
            provider.setReturnValue({
                insertText: 'console.log("hello");',
                range: new Range(1, 1, 1, 1000),
            });
            model.triggerExplicitly();
            timeout(1000);
            model.accept(editor);
            assertEquals(
                editor.getValue(),
                [
                    'console.log("hello");',
                    'console.warn("hello");',
                    ''
                ].join('\n')
            );
        });
    }

    function acceptNextWord(model:InlineCompletionsModel, editor:TestCodeEditor, timesToAccept:Int = 1):Void {
        for (i in 0...timesToAccept) {
            model.triggerExplicitly();
            timeout(1000);
            model.acceptNextWord(editor);
        }
    }

    function testInlineCompletionMultiCursorBasicPartialCompletion() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('let\nlet\n');
            editor.setSelections([
                new Selection(1, 1000, 1, 1000),
                new Selection(2, 1000, 2, 1000),
            ]);

            provider.setReturnValue({
                insertText: "let a = 'some word'; ",
                range: new Range(1, 1, 1, 1000),
            });

            acceptNextWord(model, editor, 2);

            assertEquals(
                editor.getValue(),
                [
                    'let a',
                    'let a',
                    ''
                ].join('\n')
            );
        });
    }

    function testInlineCompletionMultiCursorPartialMultiPartCompletion() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('for ()\nfor \n');
            editor.setSelections([
                new Selection(1, 5, 1, 5),
                new Selection(2, 1000, 2, 1000),
            ]);

            provider.setReturnValue({
                insertText: 'for (let i = 0; i < 10; i++) {',
                range: new Range(1, 1, 1, 1000),
            });

            model.triggerExplicitly();
            timeout(1000);

            acceptNextWord(model, editor, 3);

            assertEquals(
                editor.getValue(),
                [
                    'for (let i)',
                    'for (let i',
                    ''
                ].join('\n')
            );
        });
    }

    function testInlineCompletionMultiCursorPartialMutliPartAndDifferentCursorColumnsCompletion() {
        final provider = new MockInlineCompletionsProvider();
        withAsyncTestCodeEditorAndInlineCompletionsModel('', {}, provider, (editor, model, context) -> {
            context.keyboardType('console.log()\nconsole.warnnnn\n');
            editor.setSelections([
                new Selection(1, 12, 1, 12),
                new Selection(2, 16, 2, 16),
            ]);

            provider.setReturnValue({
                insertText: 'console.log("hello" + " " + "world");',
                range: new Range(1, 1, 1, 1000),
            });

            model.triggerExplicitly();
            timeout(1000);

            acceptNextWord(model, editor, 4);

            assertEquals(
                editor.getValue(),
                [
                    'console.log("hello" + )',
                    'console.warnnnn("hello" + ',
                    ''
                ].join('\n')
            );
        });
    }

    /**
     * vscode's `withAsyncTestCodeEditorAndInlineCompletionsModel`: a test
     * editor (with the focus) and its controller, the provider registered
     * for every language in the context of the test.
     */
    public static function withAsyncTestCodeEditorAndInlineCompletionsModel(
        text:String,
        options:IEditorOptions,
        provider:Null<MockInlineCompletionsProvider>,
        callback:(editor:TestCodeEditor, model:InlineCompletionsModel, context:GhostTextContext) -> Void
    ):Void {
        final cityscape = new Cityscape();
        if (provider != null) {
            cityscape.languageFeaturesService.inlineCompletionsProvider.register('*', provider);
        }
        TestCodeEditor.withTestCodeEditor(text, options, (editor, viewModel) -> {
            final controller = new InlineCompletionsController(editor);
            final model = controller.model.get();
            final context = new GhostTextContext(model, editor);
            var error:Null<haxe.Exception> = null;
            try {
                callback(editor, model, context);
            }
            catch (e:haxe.Exception) {
                error = e;
            }
            context.dispose();
            controller.dispose();
            if (error != null) {
                throw error;
            }
        }, cityscape);

        if (provider != null) {
            provider.assertNotCalledTwiceWithin50ms();
        }
    }

}
