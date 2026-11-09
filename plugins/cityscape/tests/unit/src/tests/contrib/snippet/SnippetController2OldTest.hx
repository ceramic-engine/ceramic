// Ported from vscode src/vs/editor/contrib/snippet/test/browser/snippetController2.old.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.snippet;

// Classes of this module:
// - SnippetController2OldTest
//
// All the tests are ported (vscode comments out four of them, kept
// commented here). `assert.strictEqual(actual, expected)`,
// `assert.ok` and `assert.deepStrictEqual` on positions are the helpers
// `strictEqual`, `ok` and `deepStrictEqual` of the class, which keep
// vscode's argument order.

import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.view.EditorBrowser.ICodeEditor;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.TestLanguageConfigurationService;

private class TestSnippetController extends SnippetController2 {

    final _testLanguageConfigurationService:TestLanguageConfigurationService;

    public function new(editor:ICodeEditor) {
        super(editor);
        this._testLanguageConfigurationService = new TestLanguageConfigurationService();
    }

    override public function dispose():Void {
        super.dispose();
        this._testLanguageConfigurationService.dispose();
    }

    public function isInSnippetMode():Bool {
        return SnippetController2.InSnippetMode.getValue(@:privateAccess this._editor.contextKeyService) == true;
    }
}

/**
 * suite('SnippetController')
 */
class SnippetController2OldTest extends TestCase {

    function strictEqual<T>(actual:T, expected:T, ?message:String, ?pos:haxe.PosInfos):Void {
        assertEquals(expected, actual, message, pos);
    }

    function ok(value:Bool, ?message:String, ?pos:haxe.PosInfos):Void {
        assertTrue(value, message, pos);
    }

    function deepStrictEqual(actual:Null<Position>, expected:Position, ?pos:haxe.PosInfos):Void {
        assertTrue(actual != null && actual.equals(expected), 'expected ' + expected.toString() + ' but got ' + (actual != null ? actual.toString() : 'null'), pos);
    }

    function snippetTest(cb:(editor:TestCodeEditor, template:String, snippetController:TestSnippetController) -> Void, ?lines:Array<String>):Void {

        if (lines == null) {
            lines = [
                'function test() {',
                '\tvar x = 3;',
                '\tvar arr = [];',
                '\t',
                '}'
            ];
        }

        TestCodeEditor.withTestCodeEditor(lines, null, (editor, _) -> {
            editor.getModel().updateOptions({
                insertSpaces: false
            });
            final snippetController = editor.registerAndInstantiateContribution(SnippetController2.ID, e -> new TestSnippetController(e));
            final template = [
                "for (var ${1:index}; $1 < ${2:array}.length; $1++) {",
                "\tvar element = $2[$1];",
                "\t$0",
                '}'
            ].join('\n');

            cb(editor, template, snippetController);
            snippetController.dispose();
        });
    }

    function testSimpleAccepted() {
        snippetTest((editor, template, snippetController) -> {
            editor.setPosition({ lineNumber: 4, column: 2 });

            snippetController.insert(template);
            strictEqual(editor.getModel().getLineContent(4), '\tfor (var index; index < array.length; index++) {');
            strictEqual(editor.getModel().getLineContent(5), '\t\tvar element = array[index];');
            strictEqual(editor.getModel().getLineContent(6), '\t\t');
            strictEqual(editor.getModel().getLineContent(7), '\t}');

            editor.trigger('test', 'type', { text: 'i' });
            strictEqual(editor.getModel().getLineContent(4), '\tfor (var i; i < array.length; i++) {');
            strictEqual(editor.getModel().getLineContent(5), '\t\tvar element = array[i];');
            strictEqual(editor.getModel().getLineContent(6), '\t\t');
            strictEqual(editor.getModel().getLineContent(7), '\t}');

            snippetController.next();
            editor.trigger('test', 'type', { text: 'arr' });
            strictEqual(editor.getModel().getLineContent(4), '\tfor (var i; i < arr.length; i++) {');
            strictEqual(editor.getModel().getLineContent(5), '\t\tvar element = arr[i];');
            strictEqual(editor.getModel().getLineContent(6), '\t\t');
            strictEqual(editor.getModel().getLineContent(7), '\t}');

            snippetController.prev();
            editor.trigger('test', 'type', { text: 'j' });
            strictEqual(editor.getModel().getLineContent(4), '\tfor (var j; j < arr.length; j++) {');
            strictEqual(editor.getModel().getLineContent(5), '\t\tvar element = arr[j];');
            strictEqual(editor.getModel().getLineContent(6), '\t\t');
            strictEqual(editor.getModel().getLineContent(7), '\t}');

            snippetController.next();
            snippetController.next();
            deepStrictEqual(editor.getPosition(), new Position(6, 3));
        });
    }

    function testSimpleCanceled() {
        snippetTest((editor, template, snippetController) -> {
            editor.setPosition({ lineNumber: 4, column: 2 });

            snippetController.insert(template);
            strictEqual(editor.getModel().getLineContent(4), '\tfor (var index; index < array.length; index++) {');
            strictEqual(editor.getModel().getLineContent(5), '\t\tvar element = array[index];');
            strictEqual(editor.getModel().getLineContent(6), '\t\t');
            strictEqual(editor.getModel().getLineContent(7), '\t}');

            snippetController.cancel();
            deepStrictEqual(editor.getPosition(), new Position(4, 16));
        });
    }

    // test('Stops when deleting lines above', () => {
    //     snippetTest((editor, codeSnippet, snippetController) => {
    //         editor.setPosition({ lineNumber: 4, column: 2 });
    //         snippetController.insert(codeSnippet, 0, 0);

    //         editor.getModel()!.applyEdits([{
    //             forceMoveMarkers: false,
    //             identifier: null,
    //             isAutoWhitespaceEdit: false,
    //             range: new Range(1, 1, 3, 1),
    //             text: null
    //         }]);

    //         assert.strictEqual(snippetController.isInSnippetMode(), false);
    //     });
    // });

    // test('Stops when deleting lines below', () => {
    //     snippetTest((editor, codeSnippet, snippetController) => {
    //         editor.setPosition({ lineNumber: 4, column: 2 });
    //         snippetController.run(codeSnippet, 0, 0);

    //         editor.getModel()!.applyEdits([{
    //             forceMoveMarkers: false,
    //             identifier: null,
    //             isAutoWhitespaceEdit: false,
    //             range: new Range(8, 1, 8, 100),
    //             text: null
    //         }]);

    //         assert.strictEqual(snippetController.isInSnippetMode(), false);
    //     });
    // });

    // test('Stops when inserting lines above', () => {
    //     snippetTest((editor, codeSnippet, snippetController) => {
    //         editor.setPosition({ lineNumber: 4, column: 2 });
    //         snippetController.run(codeSnippet, 0, 0);

    //         editor.getModel()!.applyEdits([{
    //             forceMoveMarkers: false,
    //             identifier: null,
    //             isAutoWhitespaceEdit: false,
    //             range: new Range(1, 100, 1, 100),
    //             text: '\nHello'
    //         }]);

    //         assert.strictEqual(snippetController.isInSnippetMode(), false);
    //     });
    // });

    // test('Stops when inserting lines below', () => {
    //     snippetTest((editor, codeSnippet, snippetController) => {
    //         editor.setPosition({ lineNumber: 4, column: 2 });
    //         snippetController.run(codeSnippet, 0, 0);

    //         editor.getModel()!.applyEdits([{
    //             forceMoveMarkers: false,
    //             identifier: null,
    //             isAutoWhitespaceEdit: false,
    //             range: new Range(8, 100, 8, 100),
    //             text: '\nHello'
    //         }]);

    //         assert.strictEqual(snippetController.isInSnippetMode(), false);
    //     });
    // });

    function testStopsWhenCallingModelSetValue() {
        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setPosition({ lineNumber: 4, column: 2 });
            snippetController.insert(codeSnippet);

            editor.getModel().setValue('goodbye');

            strictEqual(snippetController.isInSnippetMode(), false);
        });
    }

    function testStopsWhenUndoing() {
        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setPosition({ lineNumber: 4, column: 2 });
            snippetController.insert(codeSnippet);

            editor.getModel().undo();

            strictEqual(snippetController.isInSnippetMode(), false);
        });
    }

    function testStopsWhenMovingCursorOutside() {
        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setPosition({ lineNumber: 4, column: 2 });
            snippetController.insert(codeSnippet);

            editor.setPosition({ lineNumber: 1, column: 1 });

            strictEqual(snippetController.isInSnippetMode(), false);
        });
    }

    function testStopsWhenDisconnectingEditorModel() {
        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setPosition({ lineNumber: 4, column: 2 });
            snippetController.insert(codeSnippet);

            editor.setModel(null);

            strictEqual(snippetController.isInSnippetMode(), false);
        });
    }

    function testStopsWhenDisposingEditor() {
        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setPosition({ lineNumber: 4, column: 2 });
            snippetController.insert(codeSnippet);

            snippetController.dispose();

            strictEqual(snippetController.isInSnippetMode(), false);
        });
    }

    function testFinalTabstopWithMultipleSelections() {
        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 1),
                new Selection(2, 1, 2, 1),
            ]);

            codeSnippet = "foo$0";
            snippetController.insert(codeSnippet);

            strictEqual(editor.getSelections().length, 2);
			final sels = editor.getSelections();
			final first = sels[0];
			final second = sels[1];
            ok(first.equalsRange({ startLineNumber: 1, startColumn: 4, endLineNumber: 1, endColumn: 4 }), first.toString());
            ok(second.equalsRange({ startLineNumber: 2, startColumn: 4, endLineNumber: 2, endColumn: 4 }), second.toString());
        });

        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 1),
                new Selection(2, 1, 2, 1),
            ]);

            codeSnippet = "foo$0bar";
            snippetController.insert(codeSnippet);

            strictEqual(editor.getSelections().length, 2);
			final sels = editor.getSelections();
			final first = sels[0];
			final second = sels[1];
            ok(first.equalsRange({ startLineNumber: 1, startColumn: 4, endLineNumber: 1, endColumn: 4 }), first.toString());
            ok(second.equalsRange({ startLineNumber: 2, startColumn: 4, endLineNumber: 2, endColumn: 4 }), second.toString());
        });

        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 1),
                new Selection(1, 5, 1, 5),
            ]);

            codeSnippet = "foo$0bar";
            snippetController.insert(codeSnippet);

            strictEqual(editor.getSelections().length, 2);
			final sels = editor.getSelections();
			final first = sels[0];
			final second = sels[1];
            ok(first.equalsRange({ startLineNumber: 1, startColumn: 4, endLineNumber: 1, endColumn: 4 }), first.toString());
            ok(second.equalsRange({ startLineNumber: 1, startColumn: 14, endLineNumber: 1, endColumn: 14 }), second.toString());
        });

        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 1),
                new Selection(1, 5, 1, 5),
            ]);

            codeSnippet = "foo\n$0\nbar";
            snippetController.insert(codeSnippet);

            strictEqual(editor.getSelections().length, 2);
			final sels = editor.getSelections();
			final first = sels[0];
			final second = sels[1];
            ok(first.equalsRange({ startLineNumber: 2, startColumn: 1, endLineNumber: 2, endColumn: 1 }), first.toString());
            ok(second.equalsRange({ startLineNumber: 4, startColumn: 1, endLineNumber: 4, endColumn: 1 }), second.toString());
        });

        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 1),
                new Selection(1, 5, 1, 5),
            ]);

            codeSnippet = "foo\n$0\nbar";
            snippetController.insert(codeSnippet);

            strictEqual(editor.getSelections().length, 2);
			final sels = editor.getSelections();
			final first = sels[0];
			final second = sels[1];
            ok(first.equalsRange({ startLineNumber: 2, startColumn: 1, endLineNumber: 2, endColumn: 1 }), first.toString());
            ok(second.equalsRange({ startLineNumber: 4, startColumn: 1, endLineNumber: 4, endColumn: 1 }), second.toString());
        });

        snippetTest((editor, codeSnippet, snippetController) -> {
            editor.setSelections([
                new Selection(2, 7, 2, 7),
            ]);

            codeSnippet = "xo$0r";
            snippetController.insert(codeSnippet, { overwriteBefore: 1 });

            strictEqual(editor.getSelections().length, 1);
            ok(editor.getSelection().equalsRange({ startLineNumber: 2, startColumn: 8, endColumn: 8, endLineNumber: 2 }));
        });
    }

    function testFinalTabstop11742Simple() {
        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelection(new Selection(1, 19, 1, 19));

            codeSnippet = "{{% url_**$1** %}}";
            controller.insert(codeSnippet, { overwriteBefore: 2 });

            strictEqual(editor.getSelections().length, 1);
            ok(editor.getSelection().equalsRange({ startLineNumber: 1, startColumn: 27, endLineNumber: 1, endColumn: 27 }));
            strictEqual(editor.getModel().getValue(), 'example example {{% url_**** %}}');

        }, ['example example sc']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelection(new Selection(1, 3, 1, 3));

            codeSnippet = [
                'afterEach((done) => {',
                "\t${1}test",
                '});'
            ].join('\n');

            controller.insert(codeSnippet, { overwriteBefore: 2 });

            strictEqual(editor.getSelections().length, 1);
            ok(editor.getSelection().equalsRange({ startLineNumber: 2, startColumn: 2, endLineNumber: 2, endColumn: 2 }), editor.getSelection().toString());
            strictEqual(editor.getModel().getValue(), 'afterEach((done) => {\n\ttest\n});');

        }, ['af']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelection(new Selection(1, 3, 1, 3));

            codeSnippet = [
                'afterEach((done) => {',
                "${1}\ttest",
                '});'
            ].join('\n');

            controller.insert(codeSnippet, { overwriteBefore: 2 });

            strictEqual(editor.getSelections().length, 1);
            ok(editor.getSelection().equalsRange({ startLineNumber: 2, startColumn: 1, endLineNumber: 2, endColumn: 1 }), editor.getSelection().toString());
            strictEqual(editor.getModel().getValue(), 'afterEach((done) => {\n\ttest\n});');

        }, ['af']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelection(new Selection(1, 9, 1, 9));

            codeSnippet = [
                "aft${1}er"
            ].join('\n');

            controller.insert(codeSnippet, { overwriteBefore: 8 });

            strictEqual(editor.getModel().getValue(), 'after');
            strictEqual(editor.getSelections().length, 1);
            ok(editor.getSelection().equalsRange({ startLineNumber: 1, startColumn: 4, endLineNumber: 1, endColumn: 4 }), editor.getSelection().toString());

        }, ['afterone']);
    }

    function testFinalTabstop11742DifferentIndents() {

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(2, 4, 2, 4),
                new Selection(1, 3, 1, 3)
            ]);

            codeSnippet = [
                'afterEach((done) => {',
                "\t${0}test",
                '});'
            ].join('\n');

            controller.insert(codeSnippet, { overwriteBefore: 2 });

            strictEqual(editor.getSelections().length, 2);
			final sels = editor.getSelections();
			final first = sels[0];
			final second = sels[1];

            ok(first.equalsRange({ startLineNumber: 5, startColumn: 3, endLineNumber: 5, endColumn: 3 }), first.toString());
            ok(second.equalsRange({ startLineNumber: 2, startColumn: 2, endLineNumber: 2, endColumn: 2 }), second.toString());

        }, ['af', '\taf']);
    }

    function testFinalTabstop11890StayAtTheBeginning() {

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 5, 1, 5)
            ]);

            codeSnippet = [
                'afterEach((done) => {',
                "${1}\ttest",
                '});'
            ].join('\n');

            controller.insert(codeSnippet, { overwriteBefore: 2 });

            strictEqual(editor.getSelections().length, 1);
            final first = editor.getSelections()[0];

            ok(first.equalsRange({ startLineNumber: 2, startColumn: 3, endLineNumber: 2, endColumn: 3 }), first.toString());

        }, ['  af']);
    }

    function testFinalTabstopNoTabstop() {

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 3, 1, 3)
            ]);

            codeSnippet = 'afterEach';

            controller.insert(codeSnippet, { overwriteBefore: 2 });

            ok(editor.getSelection().equalsRange({ startLineNumber: 1, startColumn: 10, endLineNumber: 1, endColumn: 10 }));

        }, ['af', '\taf']);
    }

    function testMultipleCursorAndOverwriteBeforeAfterIssue11060() {

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 7, 1, 7),
                new Selection(2, 4, 2, 4)
            ]);

            codeSnippet = '_foo';
            controller.insert(codeSnippet, { overwriteBefore: 1 });
            strictEqual(editor.getModel().getValue(), 'this._foo\nabc_foo');

        }, ['this._', 'abc']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 7, 1, 7),
                new Selection(2, 4, 2, 4)
            ]);

            codeSnippet = 'XX';
            controller.insert(codeSnippet, { overwriteBefore: 1 });
            strictEqual(editor.getModel().getValue(), 'this.XX\nabcXX');

        }, ['this._', 'abc']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 7, 1, 7),
                new Selection(2, 4, 2, 4),
                new Selection(3, 5, 3, 5)
            ]);

            codeSnippet = '_foo';
            controller.insert(codeSnippet, { overwriteBefore: 1 });
            strictEqual(editor.getModel().getValue(), 'this._foo\nabc_foo\ndef_foo');

        }, ['this._', 'abc', 'def_']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 7, 1, 7), // primary at `this._`
                new Selection(2, 4, 2, 4),
                new Selection(3, 6, 3, 6)
            ]);

            codeSnippet = '._foo';
            controller.insert(codeSnippet, { overwriteBefore: 2 });
            strictEqual(editor.getModel().getValue(), 'this._foo\nabc._foo\ndef._foo');

        }, ['this._', 'abc', 'def._']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(3, 6, 3, 6), // primary at `def._`
                new Selection(1, 7, 1, 7),
                new Selection(2, 4, 2, 4),
            ]);

            codeSnippet = '._foo';
            controller.insert(codeSnippet, { overwriteBefore: 2 });
            strictEqual(editor.getModel().getValue(), 'this._foo\nabc._foo\ndef._foo');

        }, ['this._', 'abc', 'def._']);

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(2, 4, 2, 4), // primary at `abc`
                new Selection(3, 6, 3, 6),
                new Selection(1, 7, 1, 7),
            ]);

            codeSnippet = '._foo';
            controller.insert(codeSnippet, { overwriteBefore: 2 });
            strictEqual(editor.getModel().getValue(), 'this._._foo\na._foo\ndef._._foo');

        }, ['this._', 'abc', 'def._']);

    }

    function testMultipleCursorAndOverwriteBeforeAfter16277() {
        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 5, 1, 5),
                new Selection(2, 5, 2, 5),
            ]);

            codeSnippet = 'document';
            controller.insert(codeSnippet, { overwriteBefore: 3 });
            strictEqual(editor.getModel().getValue(), '{document}\n{document && true}');

        }, ['{foo}', '{foo && true}']);
    }

    function testInsertSnippetTwice19449() {

        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 1, 1, 1)
            ]);

            codeSnippet = "for (var ${1:i}=0; ${1:i}<len; ${1:i}++) { $0 }";
            controller.insert(codeSnippet);
            strictEqual(editor.getModel().getValue(), 'for (var i=0; i<len; i++) {  }for (var i=0; i<len; i++) {  }');

        }, ['for (var i=0; i<len; i++) {  }']);


        snippetTest((editor, codeSnippet, controller) -> {

            editor.setSelections([
                new Selection(1, 1, 1, 1)
            ]);

            codeSnippet = "for (var ${1:i}=0; ${1:i}<len; ${1:i}++) { $0 }";
            controller.insert(codeSnippet);
            strictEqual(editor.getModel().getValue(), 'for (var i=0; i<len; i++) {  }for (var i=0; i<len; i++) {  }');

        }, ['for (var i=0; i<len; i++) {  }']);

    }

}
