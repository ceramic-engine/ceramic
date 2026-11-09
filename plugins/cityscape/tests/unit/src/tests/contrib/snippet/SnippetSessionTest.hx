// Ported from vscode src/vs/editor/contrib/snippet/test/browser/snippetSession.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.snippet;

// Classes of this module:
// - SnippetSessionTest
//
// All the tests are ported (the suite 'createEditsAndSnippetsFromEdits'
// is in the same class, its tests prefixed with
// `CreateEditsAndSnippetsFromEdits`). The services of vscode's test editor
// are the context's: an empty workspace (`folders: []`) and the
// `TestLanguageConfigurationService`.

import cityscape.Cityscape;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.snippet.view.SnippetParser;
import cityscape.contrib.snippet.view.SnippetSession;
import cityscape.platform.workspace.common.Workspace;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.TestLanguageConfigurationService;
import tests.TestTextModel;

private class EmptyWorkspaceService implements IWorkspaceContextService {
    public function new() {}

    public function getWorkspace():IWorkspace {
        return {id: 'workspace-id', folders: []};
    }
}

/**
 * suite('SnippetSession')
 */
class SnippetSessionTest extends TestCase {

    var languageConfigurationService:TestLanguageConfigurationService;
    var editor:TestCodeEditor;
    var model:TextModel;

    function assertSelections(editor:TestCodeEditor, s:Array<Selection>, ?pos:haxe.PosInfos) {
        s = s.copy();
        for (selection in editor.getSelections()) {
            final actual = s.shift();
            assertTrue(actual != null && selection.equalsSelection(actual), 'actual=' + selection.toString() + ' <> expected=' + (actual != null ? actual.toString() : 'none'), pos);
        }
        assertEquals(0, s.length, 'selection count', pos);
    }

    override public function setup():Void {
        model = TestTextModel.createTextModel('function foo() {\n    console.log(a);\n}');
        languageConfigurationService = new TestLanguageConfigurationService();
        final context:Cityscape = model.context;
        context.workspaceContextService = new EmptyWorkspaceService();
        editor = new TestCodeEditor(context, model, {});
        editor.setSelections([new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);
        assertEquals('\n', model.getEOL());
    }

    override public function teardown():Void {
        model.dispose();
        editor.dispose();
        languageConfigurationService.dispose();
    }

    function newSession(template:String, ?options:ISnippetSessionInsertOptions):SnippetSession {
        return new SnippetSession(editor, template, options, languageConfigurationService);
    }

    function testNormalizeWhitespace() {

        function assertNormalized(position:Position, input:String, expected:String, ?pos:haxe.PosInfos):Void {
            final snippet = new SnippetParser().parse(input);
            SnippetSession.adjustWhitespace(model, position, true, snippet);
            assertEquals(expected, snippet.toTextmateString(), input, pos);
        }

        assertNormalized(new Position(1, 1), 'foo', 'foo');
        assertNormalized(new Position(1, 1), 'foo\rbar', 'foo\nbar');
        assertNormalized(new Position(1, 1), 'foo\rbar', 'foo\nbar');
        assertNormalized(new Position(2, 5), 'foo\r\tbar', 'foo\n        bar');
        assertNormalized(new Position(2, 3), 'foo\r\tbar', 'foo\n    bar');
        assertNormalized(new Position(2, 5), 'foo\r\tbar\nfoo', 'foo\n        bar\n    foo');

        //Indentation issue with choice elements that span multiple lines #46266
        assertNormalized(new Position(2, 5), "a\nb${1|foo,\nbar|}", "a\n    b${1|foo,\nbar|}");
    }

    function testAdjustSelectionOverwriteBeforeAfter() {

        var range = SnippetSession.adjustSelection(model, new Selection(1, 2, 1, 2), 1, 0);
        assertTrue(range.equalsRange(new Range(1, 1, 1, 2)));
        range = SnippetSession.adjustSelection(model, new Selection(1, 2, 1, 2), 1111, 0);
        assertTrue(range.equalsRange(new Range(1, 1, 1, 2)));
        range = SnippetSession.adjustSelection(model, new Selection(1, 2, 1, 2), 0, 10);
        assertTrue(range.equalsRange(new Range(1, 2, 1, 12)));
        range = SnippetSession.adjustSelection(model, new Selection(1, 2, 1, 2), 0, 10111);
        assertTrue(range.equalsRange(new Range(1, 2, 1, 17)));
    }

    function testTextEditsSelection() {
        final session = newSession("foo${1:bar}foo$0");
        session.insert();
        assertEquals('foobarfoofunction foo() {\n    foobarfooconsole.log(a);\n}', editor.getModel().getValue());

        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);
        session.next();
        assertSelections(editor, [new Selection(1, 10, 1, 10), new Selection(2, 14, 2, 14)]);
    }

    function testTextEditWithReversedSelection() {

        final session = newSession("${1:bar}$0");
        editor.setSelections([new Selection(2, 5, 2, 5), new Selection(1, 1, 1, 1)]);

        session.insert();
        assertEquals('barfunction foo() {\n    barconsole.log(a);\n}', model.getValue());
        assertSelections(editor, [new Selection(2, 5, 2, 8), new Selection(1, 1, 1, 4)]);
    }

    function testSnippetsRepeatedTabstops() {
        final session = newSession("${1:abc}foo${1:abc}$0");
        session.insert();
        assertSelections(editor, [
            new Selection(1, 1, 1, 4), new Selection(1, 7, 1, 10),
            new Selection(2, 5, 2, 8), new Selection(2, 11, 2, 14),
        ]);
        session.next();
        assertSelections(editor, [
            new Selection(1, 10, 1, 10),
            new Selection(2, 14, 2, 14),
        ]);
    }

    function testSnippetsJustText() {
        final session = newSession('foobar');
        session.insert();
        assertEquals('foobarfunction foo() {\n    foobarconsole.log(a);\n}', model.getValue());
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
    }

    function testSnippetsSelectionsAndNewTextWithNewlines() {

        final session = newSession("foo\n\t${1:bar}\n$0");
        session.insert();

        assertEquals('foo\n    bar\nfunction foo() {\n    foo\n        bar\n    console.log(a);\n}', editor.getModel().getValue());

        assertSelections(editor, [new Selection(2, 5, 2, 8), new Selection(5, 9, 5, 12)]);

        session.next();
        assertSelections(editor, [new Selection(3, 1, 3, 1), new Selection(6, 5, 6, 5)]);
    }

    function testSnippetsNewlineNOWhitespaceAdjust() {

        editor.setSelection(new Selection(2, 5, 2, 5));
        final session = newSession("abc\n    foo\n        bar\n$0", {overwriteBefore: 0, overwriteAfter: 0, adjustWhitespace: false, clipboardText: null, overtypingCapturer: null});
        session.insert();
        assertEquals('function foo() {\n    abc\n    foo\n        bar\nconsole.log(a);\n}', editor.getModel().getValue());
    }

    function testSnippetsSelectionsNextPrev() {

        final session = newSession("f$1oo${2:bar}foo$0");
        session.insert();

        // @ $2
        assertSelections(editor, [new Selection(1, 2, 1, 2), new Selection(2, 6, 2, 6)]);
        // @ $1
        session.next();
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);
        // @ $2
        session.prev();
        assertSelections(editor, [new Selection(1, 2, 1, 2), new Selection(2, 6, 2, 6)]);
        // @ $1
        session.next();
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);
        // @ $0
        session.next();
        assertSelections(editor, [new Selection(1, 10, 1, 10), new Selection(2, 14, 2, 14)]);
    }

    function testSnippetsSelectionsTyping() {
        final session = newSession("f${1:oo}_$2_$0");
        session.insert();

        editor.trigger('test', 'type', {text: 'X'});
        session.next();
        editor.trigger('test', 'type', {text: 'bar'});

        // go back to ${2:oo} which is now just 'X'
        session.prev();
        assertSelections(editor, [new Selection(1, 2, 1, 3), new Selection(2, 6, 2, 7)]);

        // go forward to $1 which is now 'bar'
        session.next();
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);

        // go to final tabstop
        session.next();
        assertEquals('fX_bar_function foo() {\n    fX_bar_console.log(a);\n}', model.getValue());
        assertSelections(editor, [new Selection(1, 8, 1, 8), new Selection(2, 12, 2, 12)]);
    }

    function testSnippetsInsertShorterSnippetIntoNonEmptySelection() {
        model.setValue('foo_bar_foo');
        editor.setSelections([new Selection(1, 1, 1, 4), new Selection(1, 9, 1, 12)]);

        newSession("x$0").insert();
        assertEquals('x_bar_x', model.getValue());
        assertSelections(editor, [new Selection(1, 2, 1, 2), new Selection(1, 8, 1, 8)]);
    }

    function testSnippetsInsertLongerSnippetIntoNonEmptySelection() {
        model.setValue('foo_bar_foo');
        editor.setSelections([new Selection(1, 1, 1, 4), new Selection(1, 9, 1, 12)]);

        newSession("LONGER$0").insert();
        assertEquals('LONGER_bar_LONGER', model.getValue());
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(1, 18, 1, 18)]);
    }

    function testSnippetsDontGrowFinalTabstop() {
        model.setValue('foo_zzz_foo');
        editor.setSelection(new Selection(1, 5, 1, 8));
        final session = newSession("$1bar$0");
        session.insert();

        assertSelections(editor, [new Selection(1, 5, 1, 5)]);
        editor.trigger('test', 'type', {text: 'foo-'});

        session.next();
        assertEquals('foo_foo-bar_foo', model.getValue());
        assertSelections(editor, [new Selection(1, 12, 1, 12)]);

        editor.trigger('test', 'type', {text: 'XXX'});
        assertEquals('foo_foo-barXXX_foo', model.getValue());
        session.prev();
        assertSelections(editor, [new Selection(1, 5, 1, 9)]);
        session.next();
        assertSelections(editor, [new Selection(1, 15, 1, 15)]);
    }

    function testSnippetsDontMergeTouchingTabstops1_2() {

        final session = newSession("$1$2$3$0");
        session.insert();
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);

        session.next();
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);

        session.next();
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);

        session.next();
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);

        session.prev();
        session.prev();
        session.prev();
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);
        editor.trigger('test', 'type', {text: '111'});

        session.next();
        editor.trigger('test', 'type', {text: '222'});

        session.next();
        editor.trigger('test', 'type', {text: '333'});

        session.next();
        assertEquals('111222333function foo() {\n    111222333console.log(a);\n}', model.getValue());
        assertSelections(editor, [new Selection(1, 10, 1, 10), new Selection(2, 14, 2, 14)]);

        session.prev();
        assertSelections(editor, [new Selection(1, 7, 1, 10), new Selection(2, 11, 2, 14)]);
        session.prev();
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);
        session.prev();
        assertSelections(editor, [new Selection(1, 1, 1, 4), new Selection(2, 5, 2, 8)]);
    }

    function testSnippetsDontMergeTouchingTabstops2_2() {

        final session = newSession("$1$2$3$0");
        session.insert();
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);

        editor.trigger('test', 'type', {text: '111'});

        session.next();
        assertSelections(editor, [new Selection(1, 4, 1, 4), new Selection(2, 8, 2, 8)]);
        editor.trigger('test', 'type', {text: '222'});

        session.next();
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
        editor.trigger('test', 'type', {text: '333'});

        session.next();
        assertEquals(true, session.isAtLastPlaceholder);
    }

    function testSnippetsGracefullyMoveOverFinalTabstop() {
        final session = newSession("${1}bar$0");
        session.insert();

        assertEquals(false, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);

        session.next();
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 4, 1, 4), new Selection(2, 8, 2, 8)]);

        session.next();
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 4, 1, 4), new Selection(2, 8, 2, 8)]);
    }

    function testSnippetsOverwritingNestedPlaceholder() {
        final session = newSession("log(${1:\"$2\"});$0");
        session.insert();
        assertSelections(editor, [new Selection(1, 5, 1, 7), new Selection(2, 9, 2, 11)]);

        editor.trigger('test', 'type', {text: 'XXX'});
        assertEquals('log(XXX);function foo() {\n    log(XXX);console.log(a);\n}', model.getValue());

        session.next();
        assertEquals(false, session.isAtLastPlaceholder);
        // assertSelections(editor, new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11));

        session.next();
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 10, 1, 10), new Selection(2, 14, 2, 14)]);
    }

    function testSnippetsSelectionsAndSnippetRanges() {
        final session = newSession("${1:foo}farboo${2:bar}$0");
        session.insert();
        assertEquals('foofarboobarfunction foo() {\n    foofarboobarconsole.log(a);\n}', model.getValue());
        assertSelections(editor, [new Selection(1, 1, 1, 4), new Selection(2, 5, 2, 8)]);

        assertEquals(true, session.isSelectionWithinPlaceholders());

        editor.setSelections([new Selection(1, 1, 1, 1)]);
        assertEquals(false, session.isSelectionWithinPlaceholders());

        editor.setSelections([new Selection(1, 6, 1, 6), new Selection(2, 10, 2, 10)]);
        assertEquals(false, session.isSelectionWithinPlaceholders()); // in snippet, outside placeholder

        editor.setSelections([new Selection(1, 6, 1, 6), new Selection(2, 10, 2, 10), new Selection(1, 1, 1, 1)]);
        assertEquals(false, session.isSelectionWithinPlaceholders()); // in snippet, outside placeholder

        editor.setSelections([new Selection(1, 6, 1, 6), new Selection(2, 10, 2, 10), new Selection(2, 20, 2, 21)]);
        assertEquals(false, session.isSelectionWithinPlaceholders());

        // reset selection to placeholder
        session.next();
        assertEquals(true, session.isSelectionWithinPlaceholders());
        assertSelections(editor, [new Selection(1, 10, 1, 13), new Selection(2, 14, 2, 17)]);

        // reset selection to placeholder
        session.next();
        assertEquals(true, session.isSelectionWithinPlaceholders());
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 13, 1, 13), new Selection(2, 17, 2, 17)]);
    }

    function testSnippetsNestedSessions() {

        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));

        final first = newSession("foo${2:bar}foo$0");
        first.insert();
        assertEquals('foobarfoo', model.getValue());
        assertSelections(editor, [new Selection(1, 4, 1, 7)]);

        final second = newSession("ba${1:zzzz}$0");
        second.insert();
        assertEquals('foobazzzzfoo', model.getValue());
        assertSelections(editor, [new Selection(1, 6, 1, 10)]);

        second.next();
        assertEquals(true, second.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 10, 1, 10)]);

        first.next();
        assertEquals(true, first.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 13, 1, 13)]);
    }

    function testSnippetsTypingAtFinalTabstop() {

        final session = newSession("farboo$0");
        session.insert();
        assertEquals(true, session.isAtLastPlaceholder);
        assertEquals(false, session.isSelectionWithinPlaceholders());

        editor.trigger('test', 'type', {text: 'XXX'});
        assertEquals(false, session.isSelectionWithinPlaceholders());
    }

    function testSnippetsTypingAtBeginning() {

        editor.setSelection(new Selection(1, 2, 1, 2));
        final session = newSession("farboo$0");
        session.insert();

        editor.setSelection(new Selection(1, 2, 1, 2));
        assertEquals(false, session.isSelectionWithinPlaceholders());
        assertEquals(true, session.isAtLastPlaceholder);

        editor.trigger('test', 'type', {text: 'XXX'});
        assertEquals('fXXXfarboounction foo() {', model.getLineContent(1));
        assertEquals(false, session.isSelectionWithinPlaceholders());

        session.next();
        assertSelections(editor, [new Selection(1, 11, 1, 11)]);
    }

    function testSnippetsTypingWithNestedPlaceholder() {

        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("This ${1:is ${2:nested}}.$0");
        session.insert();
        assertSelections(editor, [new Selection(1, 6, 1, 15)]);

        session.next();
        assertSelections(editor, [new Selection(1, 9, 1, 15)]);

        editor.trigger('test', 'cut', {});
        assertSelections(editor, [new Selection(1, 9, 1, 9)]);

        editor.trigger('test', 'type', {text: 'XXX'});
        session.prev();
        assertSelections(editor, [new Selection(1, 6, 1, 12)]);
    }

    function testSnippetsSnippetWithVariables() {
        final session = newSession("@line=$TM_LINE_NUMBER$0");
        session.insert();

        assertEquals('@line=1function foo() {\n    @line=2console.log(a);\n}', model.getValue());
        assertSelections(editor, [new Selection(1, 8, 1, 8), new Selection(2, 12, 2, 12)]);
    }

    function testSnippetsMerge() {
        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("This ${1:is ${2:nested}}.$0");
        session.insert();
        session.next();
        assertSelections(editor, [new Selection(1, 9, 1, 15)]);

        session.merge("really ${1:nested}$0");
        assertSelections(editor, [new Selection(1, 16, 1, 22)]);

        session.next();
        assertSelections(editor, [new Selection(1, 22, 1, 22)]);
        assertEquals(false, session.isAtLastPlaceholder);

        session.next();
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 23, 1, 23)]);

        session.prev();
        editor.trigger('test', 'type', {text: 'AAA'});

        // back to `really ${1:nested}`
        session.prev();
        assertSelections(editor, [new Selection(1, 16, 1, 22)]);

        // back to `${1:is ...}` which now grew
        session.prev();
        assertSelections(editor, [new Selection(1, 6, 1, 25)]);
    }

    function testSnippetsTransform() {
        editor.getModel().setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("${1/foo/bar/}$0");
        session.insert();
        assertSelections(editor, [new Selection(1, 1, 1, 1)]);

        editor.trigger('test', 'type', {text: 'foo'});
        session.next();

        assertEquals('bar', model.getValue());
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 4, 1, 4)]);
    }

    function testSnippetsMultiPlaceholderSameIndexOneTransform() {
        editor.getModel().setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("$1 baz ${1/foo/bar/}$0");
        session.insert();
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(1, 6, 1, 6)]);

        editor.trigger('test', 'type', {text: 'foo'});
        session.next();

        assertEquals('foo baz bar', model.getValue());
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 12, 1, 12)]);
    }

    function testSnippetsTransformExample() {
        editor.getModel().setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("${1:name} : ${2:type}${3/\\s:=(.*)/${1:+ :=}${1}/};\n$0");
        session.insert();

        assertSelections(editor, [new Selection(1, 1, 1, 5)]);
        editor.trigger('test', 'type', {text: 'clk'});
        session.next();

        assertSelections(editor, [new Selection(1, 7, 1, 11)]);
        editor.trigger('test', 'type', {text: 'std_logic'});
        session.next();

        assertSelections(editor, [new Selection(1, 16, 1, 16)]);
        session.next();

        assertEquals('clk : std_logic;\n', model.getValue());
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(2, 1, 2, 1)]);
    }

    function testSnippetsTransformWithIndent() {
        final snippet = [
            "private readonly ${1} = new Emitter<$2>();",
            "readonly ${1/^_(.*)/$1/}: Event<$2> = this.$1.event;",
            "$0"
        ].join('\n');
        final expected = [
            '{',
            '\tprivate readonly _prop = new Emitter<string>();',
            '\treadonly prop: Event<string> = this._prop.event;',
            '\t',
            '}'
        ].join('\n');
        final base = [
            '{',
            '\t',
            '}'
        ].join('\n');

        editor.getModel().setValue(base);
        editor.getModel().updateOptions({insertSpaces: false});
        editor.setSelection(new Selection(2, 2, 2, 2));

        final session = newSession(snippet);
        session.insert();

        assertSelections(editor, [new Selection(2, 19, 2, 19), new Selection(3, 11, 3, 11), new Selection(3, 28, 3, 28)]);
        editor.trigger('test', 'type', {text: '_prop'});
        session.next();

        assertSelections(editor, [new Selection(2, 39, 2, 39), new Selection(3, 23, 3, 23)]);
        editor.trigger('test', 'type', {text: 'string'});
        session.next();

        assertEquals(expected, model.getValue());
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(4, 2, 4, 2)]);
    }

    function testSnippetsTransformExampleHitIf() {
        editor.getModel().setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("${1:name} : ${2:type}${3/\\s:=(.*)/${1:+ :=}${1}/};\n$0");
        session.insert();

        assertSelections(editor, [new Selection(1, 1, 1, 5)]);
        editor.trigger('test', 'type', {text: 'clk'});
        session.next();

        assertSelections(editor, [new Selection(1, 7, 1, 11)]);
        editor.trigger('test', 'type', {text: 'std_logic'});
        session.next();

        assertSelections(editor, [new Selection(1, 16, 1, 16)]);
        editor.trigger('test', 'type', {text: ' := \'1\''});
        session.next();

        assertEquals('clk : std_logic := \'1\';\n', model.getValue());
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(2, 1, 2, 1)]);
    }

    function testSnippetTabStopSelectionIssue96545SnippetsTransformAdjacentToPreviousPlaceholder() {
        editor.getModel().setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("${1:{}${2:fff}${1/{/}/}");
        session.insert();

        assertSelections(editor, [new Selection(1, 1, 1, 2), new Selection(1, 5, 1, 6)]);
        session.next();

        assertEquals('{fff}', model.getValue());
        assertSelections(editor, [new Selection(1, 2, 1, 5)]);
        editor.trigger('test', 'type', {text: 'ggg'});
        session.next();

        assertEquals('{ggg}', model.getValue());
        assertEquals(true, session.isAtLastPlaceholder);
        assertSelections(editor, [new Selection(1, 6, 1, 6)]);
    }

    function testSnippetTabStopSelectionIssue96545() {
        editor.getModel().setValue('');
        final session = newSession("${1:{}${2:fff}${1/[\\{]/}/}$0");
        session.insert();
        assertEquals('{fff{', editor.getModel().getValue());

        assertSelections(editor, [new Selection(1, 1, 1, 2), new Selection(1, 5, 1, 6)]);
        session.next();
        assertSelections(editor, [new Selection(1, 2, 1, 5)]);
    }

    function testSnippetPlaceholderIndexIncorrectAfterUsing2SnippetsInARowThatEachEndWithAPlaceholder30769() {
        editor.getModel().setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        final session = newSession("test ${1:replaceme}");
        session.insert();

        editor.trigger('test', 'type', {text: '1'});
        editor.trigger('test', 'type', {text: '\n'});
        assertEquals('test 1\n', editor.getModel().getValue());

        session.merge("test ${1:replaceme}");
        editor.trigger('test', 'type', {text: '2'});
        editor.trigger('test', 'type', {text: '\n'});

        assertEquals('test 1\ntest 2\n', editor.getModel().getValue());

        session.merge("test ${1:replaceme}");
        editor.trigger('test', 'type', {text: '3'});
        editor.trigger('test', 'type', {text: '\n'});

        assertEquals('test 1\ntest 2\ntest 3\n', editor.getModel().getValue());

        session.merge("test ${1:replaceme}");
        editor.trigger('test', 'type', {text: '4'});
        editor.trigger('test', 'type', {text: '\n'});

        assertEquals('test 1\ntest 2\ntest 3\ntest 4\n', editor.getModel().getValue());
    }

    function testSnippetVariableTextIsntWhitespaceNormalised31124() {
        editor.getModel().setValue([
            'start',
            '\t\t-one',
            '\t\t-two',
            'end'
        ].join('\n'));

        editor.getModel().updateOptions({insertSpaces: false});
        editor.setSelection(new Selection(2, 2, 3, 7));

        newSession("<div>\n\t$TM_SELECTED_TEXT\n</div>$0").insert();

        var expected = [
            'start',
            '\t<div>',
            '\t\t\t-one',
            '\t\t\t-two',
            '\t</div>',
            'end'
        ].join('\n');

        assertEquals(expected, editor.getModel().getValue());

        editor.getModel().setValue([
            'start',
            '\t\t-one',
            '\t-two',
            'end'
        ].join('\n'));

        editor.getModel().updateOptions({insertSpaces: false});
        editor.setSelection(new Selection(2, 2, 3, 7));

        newSession("<div>\n\t$TM_SELECTED_TEXT\n</div>$0").insert();

        expected = [
            'start',
            '\t<div>',
            '\t\t\t-one',
            '\t\t-two',
            '\t</div>',
            'end'
        ].join('\n');

        assertEquals(expected, editor.getModel().getValue());
    }

    function testSelectingTextFromLeftToRightAndChoosingItemMessesUpCode31199() {
        final model = editor.getModel();
        model.setValue('console.log');

        var actual = SnippetSession.adjustSelection(model, new Selection(1, 12, 1, 9), 3, 0);
        assertTrue(actual.equalsSelection(new Selection(1, 9, 1, 6)));

        actual = SnippetSession.adjustSelection(model, new Selection(1, 9, 1, 12), 3, 0);
        assertTrue(actual.equalsSelection(new Selection(1, 9, 1, 12)));

        editor.setSelections([new Selection(1, 9, 1, 12)]);
        newSession('far', {overwriteBefore: 3, overwriteAfter: 0, adjustWhitespace: true, clipboardText: null, overtypingCapturer: null}).insert();
        assertEquals('console.far', model.getValue());
    }

    function testTabsDontGetReplacedWithSpacesInSnippetTransformations103818() {
        final model = editor.getModel();
        model.setValue('\n{\n  \n}');
        model.updateOptions({insertSpaces: true, indentSize: 2});
        editor.setSelections([new Selection(1, 1, 1, 1), new Selection(3, 6, 3, 6)]);
        final session = newSession([
            'function animate () {',
            "\tvar ${1:a} = 12;",
            "\tconsole.log(${1/(.*)/\n\t\t$1\n\t/})",
            '}'
        ].join('\n'));

        session.insert();

        assertEquals([
            'function animate () {',
            '  var a = 12;',
            '  console.log(a)',
            '}',
            '{',
            '  function animate () {',
            '    var a = 12;',
            '    console.log(a)',
            '  }',
            '}',
        ].join('\n'), model.getValue());

        editor.trigger('test', 'type', {text: 'bbb'});
        session.next();

        assertEquals([
            'function animate () {',
            '  var bbb = 12;',
            '  console.log(',
            '    bbb',
            '  )',
            '}',
            '{',
            '  function animate () {',
            '    var bbb = 12;',
            '    console.log(',
            '      bbb',
            '    )',
            '  }',
            '}',
        ].join('\n'), model.getValue());
    }

    // suite('createEditsAndSnippetsFromEdits')

    function testCreateEditsAndSnippetsFromEditsEmpty() {

        final result = SnippetSession.createEditsAndSnippetsFromEdits(editor, [], true, true, null, null, languageConfigurationService);

        assertEquals(0, result.edits.length);
        assertEquals(0, result.snippets.length);
    }

    function testCreateEditsAndSnippetsFromEditsBasic() {

        editor.getModel().setValue('foo("bar")');

        final result = SnippetSession.createEditsAndSnippetsFromEdits(
            editor,
            [{range: new Range(1, 5, 1, 9), template: "$1"}, {range: new Range(1, 1, 1, 1), template: "const ${1:new_const} = \"bar\""}],
            true, true, null, null, languageConfigurationService
        );

        assertEquals(2, result.edits.length);
        assertTrue(Range.lift(result.edits[0].range).equalsRange(new Range(1, 1, 1, 1)));
        assertEquals('const new_const = "bar"', result.edits[0].text);
        assertTrue(Range.lift(result.edits[1].range).equalsRange(new Range(1, 5, 1, 9)));
        assertEquals('new_const', result.edits[1].text);

        assertEquals(1, result.snippets.length);
        assertEquals(false, result.snippets[0].isTrivialSnippet);
    }

    function testCreateEditsAndSnippetsFromEditsWithSELECTIONVariable() {
        editor.getModel().setValue('Some text and a selection');
        editor.setSelections([new Selection(1, 17, 1, 26)]);

        final result = SnippetSession.createEditsAndSnippetsFromEdits(
            editor,
            [{range: new Range(1, 17, 1, 26), template: "wrapped <$SELECTION>"}],
            true, true, null, null, languageConfigurationService
        );

        assertEquals(1, result.edits.length);
        assertTrue(Range.lift(result.edits[0].range).equalsRange(new Range(1, 17, 1, 26)));
        assertEquals('wrapped <selection>', result.edits[0].text);

        assertEquals(1, result.snippets.length);
        assertEquals(true, result.snippets[0].isTrivialSnippet);
    }

}
