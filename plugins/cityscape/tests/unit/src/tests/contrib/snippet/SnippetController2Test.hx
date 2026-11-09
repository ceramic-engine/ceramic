// Ported from vscode src/vs/editor/contrib/snippet/test/browser/snippetController2.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.snippet;

// Classes of this module:
// - SnippetController2Test
//
// All the tests are ported (the suite 'createEditsAndSnippetsFromEdits' is
// in the same class, its tests prefixed with `Apply`), except the one
// vscode skips ('Snippet transformation does not work after inserting
// variable using intellisense, #112362', `test.skip`). The context keys
// are read from the editor's context key service (vscode's
// `MockContextKeyService` given to the editor); `assert.deepStrictEqual`
// on selections compares them with `equalsSelection`.

import cityscape.Cityscape;
import cityscape.common.EditorCommon.Handler;
import cityscape.common.Model.EndOfLineSequence;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.platform.workspace.common.Workspace;
import cityscape.view.CoreCommands.CoreEditingCommands;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

private class FooWorkspaceService implements IWorkspaceContextService {
    public function new() {}

    public function getWorkspace():IWorkspace {
        return {id: 'foo', folders: []};
    }
}

/**
 * suite('SnippetController2')
 */
class SnippetController2Test extends TestCase {

    var ctrl:SnippetController2;
    var editor:TestCodeEditor;
    var model:TextModel;

    /** @deprecated */
    function assertSelections(editor:TestCodeEditor, s:Array<Selection>, ?pos:haxe.PosInfos) {
        s = s.copy();
        for (selection in editor.getSelections()) {
            final actual = s.shift();
            assertTrue(actual != null && selection.equalsSelection(actual), 'actual=' + selection.toString() + ' <> expected=' + (actual != null ? actual.toString() : 'none'), pos);
        }
        assertEquals(0, s.length, 'selection count', pos);
    }

    function assertContextKeys(inSnippet:Bool, hasPrev:Bool, hasNext:Bool, ?pos:haxe.PosInfos):Void {
        final state = getContextState();
        assertEquals(inSnippet, state.inSnippet, 'inSnippetMode', pos);
        assertEquals(hasPrev, state.hasPrev, 'HasPrevTabstop', pos);
        assertEquals(hasNext, state.hasNext, 'HasNextTabstop', pos);
    }

    function getContextState():{inSnippet:Null<Bool>, hasPrev:Null<Bool>, hasNext:Null<Bool>} {
        final service = editor.contextKeyService;
        return {
            inSnippet: SnippetController2.InSnippetMode.getValue(service),
            hasPrev: SnippetController2.HasPrevTabstop.getValue(service),
            hasNext: SnippetController2.HasNextTabstop.getValue(service),
        };
    }

    override public function setup():Void {
        model = TestTextModel.createTextModel("if\n    $state\nfi");
        final context:Cityscape = model.context;
        context.workspaceContextService = new FooWorkspaceService();
        editor = new TestCodeEditor(context, model, {});
        editor.setSelections([new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);
        assertEquals('\n', model.getEOL());
    }

    override public function teardown():Void {
        model.dispose();
        if (ctrl != null) {
            ctrl.dispose();
            ctrl = null;
        }
        editor.dispose();
    }

    function createController():SnippetController2 {
        return new SnippetController2(editor);
    }

    function testCreation() {
        ctrl = createController();
        assertContextKeys(false, false, false);
    }

    function testInsertInsertAbort() {
        ctrl = createController();

        ctrl.insert("foo${1:bar}foo$0");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);

        ctrl.cancel();
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);
    }

    function testInsertInsertTabTabDone() {
        ctrl = createController();

        ctrl.insert("${1:one}${2:two}$0");
        assertContextKeys(true, false, true);

        ctrl.next();
        assertContextKeys(true, true, true);

        ctrl.next();
        assertContextKeys(false, false, false);

        editor.trigger('test', 'type', {text: '\t'});
        assertEquals(false, SnippetController2.InSnippetMode.getValue(editor.contextKeyService));
        assertEquals(false, SnippetController2.HasNextTabstop.getValue(editor.contextKeyService));
        assertEquals(false, SnippetController2.HasPrevTabstop.getValue(editor.contextKeyService));
    }

    function testInsertInsertCursorMovesOutLeftRight() {
        ctrl = createController();

        ctrl.insert("foo${1:bar}foo$0");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);

        // bad selection change
        editor.setSelections([new Selection(1, 12, 1, 12), new Selection(2, 16, 2, 16)]);
        assertContextKeys(false, false, false);
    }

    function testInsertInsertCursorMovesOutUpDown() {
        ctrl = createController();

        ctrl.insert("foo${1:bar}foo$0");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);

        // bad selection change
        editor.setSelections([new Selection(2, 4, 2, 7), new Selection(3, 8, 3, 11)]);
        assertContextKeys(false, false, false);
    }

    function testInsertInsertCursorsCollapse() {
        ctrl = createController();

        ctrl.insert("foo${1:bar}foo$0");
        assertEquals(true, SnippetController2.InSnippetMode.getValue(editor.contextKeyService));
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(2, 8, 2, 11)]);

        // bad selection change
        editor.setSelections([new Selection(1, 4, 1, 7)]);
        assertContextKeys(false, false, false);
    }

    function testInsertInsertPlainTextNoSnippetMode() {
        ctrl = createController();

        ctrl.insert('foobar');
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
    }

    function testInsertDeleteSnippetText() {
        ctrl = createController();

        ctrl.insert("${1:foobar}$0");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 1, 1, 7), new Selection(2, 5, 2, 11)]);

        editor.trigger('test', 'cut', {});
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(2, 5, 2, 5)]);

        editor.trigger('test', 'type', {text: 'abc'});
        assertContextKeys(true, false, true);

        ctrl.next();
        assertContextKeys(false, false, false);

        editor.trigger('test', 'tab', {});
        assertContextKeys(false, false, false);

        // editor.trigger('test', 'type', { text: 'abc' });
        // assertContextKeys(contextKeys, false, false, false);
    }

    function testInsertNestedTrivialSnippet() {
        ctrl = createController();
        ctrl.insert("${1:foo}bar$0");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 1, 1, 4), new Selection(2, 5, 2, 8)]);

        ctrl.insert("FOO$0");
        assertSelections(editor, [new Selection(1, 4, 1, 4), new Selection(2, 8, 2, 8)]);
        assertContextKeys(true, false, true);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
        assertContextKeys(false, false, false);
    }

    function testInsertNestedSnippet() {
        ctrl = createController();
        ctrl.insert("${1:foobar}$0");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 1, 1, 7), new Selection(2, 5, 2, 11)]);

        ctrl.insert("far$1boo$0");
        assertSelections(editor, [new Selection(1, 4, 1, 4), new Selection(2, 8, 2, 8)]);
        assertContextKeys(true, false, true);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
        assertContextKeys(true, true, true);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
        assertContextKeys(false, false, false);
    }

    function testInsertNestedPlainText() {
        ctrl = createController();
        ctrl.insert("${1:foobar}$0");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 1, 1, 7), new Selection(2, 5, 2, 11)]);

        ctrl.insert('farboo');
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
        assertContextKeys(true, false, true);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 7, 1, 7), new Selection(2, 11, 2, 11)]);
        assertContextKeys(false, false, false);
    }

    function testNestedSnippetsWithoutFinalPlaceholderJumpsToNextOuterPlaceholder27898() {
        ctrl = createController();

        ctrl.insert("for(const ${1:element} of ${2:array}) {$0}");
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 11, 1, 18), new Selection(2, 15, 2, 22)]);

        ctrl.next();
        assertContextKeys(true, true, true);
        assertSelections(editor, [new Selection(1, 22, 1, 27), new Selection(2, 26, 2, 31)]);

        ctrl.insert('document');
        assertContextKeys(true, true, true);
        assertSelections(editor, [new Selection(1, 30, 1, 30), new Selection(2, 34, 2, 34)]);

        ctrl.next();
        assertContextKeys(false, false, false);
    }

    function testInconsistentTabStopBehaviourWithRecursiveSnippetsAndTabShiftTab27543() {
        ctrl = createController();
        ctrl.insert("1_calize(${1:nl}, '${2:value}')$0");

        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 10, 1, 12), new Selection(2, 14, 2, 16)]);

        ctrl.insert("2_calize(${1:nl}, '${2:value}')$0");

        assertSelections(editor, [new Selection(1, 19, 1, 21), new Selection(2, 23, 2, 25)]);

        ctrl.next(); // inner `value`
        assertSelections(editor, [new Selection(1, 24, 1, 29), new Selection(2, 28, 2, 33)]);

        ctrl.next(); // inner `$0`
        assertSelections(editor, [new Selection(1, 31, 1, 31), new Selection(2, 35, 2, 35)]);

        ctrl.next(); // outer `value`
        assertSelections(editor, [new Selection(1, 34, 1, 39), new Selection(2, 38, 2, 43)]);

        ctrl.prev(); // inner `$0`
        assertSelections(editor, [new Selection(1, 31, 1, 31), new Selection(2, 35, 2, 35)]);
    }

    function testSnippetTabstopSelectingContentOfPreviouslyEnteredVariableOnlyWorksWhenSeparatedBySpace23728() {
        ctrl = createController();

        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));

        ctrl.insert("import ${2:${1:module}} from '${1:module}'$0");

        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 8, 1, 14), new Selection(1, 21, 1, 27)]);

        ctrl.insert('foo');
        assertSelections(editor, [new Selection(1, 11, 1, 11), new Selection(1, 21, 1, 21)]);

        ctrl.next(); // ${2:...}
        assertSelections(editor, [new Selection(1, 8, 1, 11)]);
    }

    function testHTMLSnippetsCombine32211() {
        ctrl = createController();

        model.setValue('');
        model.updateOptions({insertSpaces: false, tabSize: 4, trimAutoWhitespace: false});
        editor.setSelection(new Selection(1, 1, 1, 1));

        ctrl.insert([
            "",
            "\t\t\t<!DOCTYPE html>",
            "\t\t\t<html lang=\"en\">",
            "\t\t\t<head>",
            "\t\t\t\t<meta charset=\"UTF-8\">",
            "\t\t\t\t<meta name=\"viewport\" content=\"width=${2:device-width}, initial-scale=${3:1.0}\">",
            "\t\t\t\t<meta http-equiv=\"X-UA-Compatible\" content=\"${5:ie=edge}\">",
            "\t\t\t\t<title>${7:Document}</title>",
            "\t\t\t</head>",
            "\t\t\t<body>",
            "\t\t\t\t${8}",
            "\t\t\t</body>",
            "\t\t\t</html>",
            "\t\t"
        ].join('\n'));
        ctrl.next();
        ctrl.next();
        ctrl.next();
        ctrl.next();
        assertSelections(editor, [new Selection(11, 5, 11, 5)]);

        ctrl.insert("<input type=\"${2:text}\">");
        assertSelections(editor, [new Selection(11, 18, 11, 22)]);
    }

    function testProblemsWithNestedSnippetInsertion39594() {
        ctrl = createController();

        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));

        ctrl.insert("$1 = ConvertTo-Json $1");
        assertSelections(editor, [new Selection(1, 1, 1, 1), new Selection(1, 19, 1, 19)]);

        editor.setSelection(new Selection(1, 19, 1, 19));

        // snippet mode should stop because $1 has two occurrences
        // and we only have one selection left
        assertContextKeys(false, false, false);
    }

    function testProblemsWithNestedSnippetInsertion39594Part2() {
        // ensure selection-change-to-cancel logic isn't too aggressive
        ctrl = createController();

        model.setValue('a-\naaa-');
        editor.setSelections([new Selection(2, 5, 2, 5), new Selection(1, 3, 1, 3)]);

        ctrl.insert("log($1);$0");
        assertSelections(editor, [new Selection(2, 9, 2, 9), new Selection(1, 7, 1, 7)]);
        assertContextKeys(true, false, true);
    }

    function testNestedSnippetsTerminatingAbruptlyInVSCode1_19_2_42012() {

        ctrl = createController();
        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        ctrl.insert("var ${2:${1:name}} = ${1:name} + 1;${0}");

        assertSelections(editor, [new Selection(1, 5, 1, 9), new Selection(1, 12, 1, 16)]);
        assertContextKeys(true, false, true);

        ctrl.next();
        assertContextKeys(true, true, true);
    }

    function testPlaceholdersOrder58267() {

        ctrl = createController();
        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        ctrl.insert("\\pth{$1}$0");

        assertSelections(editor, [new Selection(1, 6, 1, 6)]);
        assertContextKeys(true, false, true);

        ctrl.insert("\\itv{${1:left}}{${2:right}}{${3:left_value}}{${4:right_value}}$0");
        assertSelections(editor, [new Selection(1, 11, 1, 15)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 17, 1, 22)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 24, 1, 34)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 36, 1, 47)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 48, 1, 48)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 49, 1, 49)]);
        assertContextKeys(false, false, false);
    }

    function testMustTabThroughDeletedTabStopsInSnippets31619() {
        ctrl = createController();
        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));
        ctrl.insert("foo${1:a${2:bar}baz}end$0");
        assertSelections(editor, [new Selection(1, 4, 1, 11)]);

        editor.trigger('test', Handler.Cut, null);
        assertSelections(editor, [new Selection(1, 4, 1, 4)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 7, 1, 7)]);
        assertContextKeys(false, false, false);
    }

    function testCancellingSnippetModeShouldDiscardAddedCursors68512SoftCancel() {
        ctrl = createController();
        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));

        ctrl.insert(".REGION ${2:FUNCTION_NAME}\nCREATE.FUNCTION ${1:VOID} ${2:FUNCTION_NAME}(${3:})\n\t${4:}\nEND\n.ENDREGION$0");
        assertSelections(editor, [new Selection(2, 17, 2, 21)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 9, 1, 22), new Selection(2, 22, 2, 35)]);
        assertContextKeys(true, true, true);

        editor.setSelections([new Selection(1, 22, 1, 22), new Selection(2, 35, 2, 35)]);
        assertContextKeys(true, true, true);

        editor.setSelections([new Selection(2, 1, 2, 1), new Selection(2, 36, 2, 36)]);
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(2, 1, 2, 1), new Selection(2, 36, 2, 36)]);
    }

    function testCancellingSnippetModeShouldDiscardAddedCursors68512HardCancel() {
        ctrl = createController();
        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));

        ctrl.insert(".REGION ${2:FUNCTION_NAME}\nCREATE.FUNCTION ${1:VOID} ${2:FUNCTION_NAME}(${3:})\n\t${4:}\nEND\n.ENDREGION$0");
        assertSelections(editor, [new Selection(2, 17, 2, 21)]);

        ctrl.next();
        assertSelections(editor, [new Selection(1, 9, 1, 22), new Selection(2, 22, 2, 35)]);
        assertContextKeys(true, true, true);

        editor.setSelections([new Selection(1, 22, 1, 22), new Selection(2, 35, 2, 35)]);
        assertContextKeys(true, true, true);

        ctrl.cancel(true);
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(1, 22, 1, 22)]);
    }

    function testUserDefinedSnippetTabStopsIgnored72862() {
        ctrl = createController();
        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));

        ctrl.insert("export default $1");
        assertContextKeys(true, false, true);
    }

    function testOptionalTabstopInSnippets72358() {
        ctrl = createController();
        model.setValue('');
        editor.setSelection(new Selection(1, 1, 1, 1));

        ctrl.insert("${1:prop: {$2\\},}\nmore$0");
        assertContextKeys(true, false, true);

        assertSelections(editor, [new Selection(1, 1, 1, 10)]);
        editor.trigger('test', Handler.Cut, {});

        assertSelections(editor, [new Selection(1, 1, 1, 1)]);

        ctrl.next();
        assertSelections(editor, [new Selection(2, 5, 2, 5)]);
        assertContextKeys(false, false, false);
    }

    function testIssue90135ConfusingTrimWhitespaceEdits() {
        ctrl = createController();
        model.setValue('');
        CoreEditingCommands.Tab.runEditorCommand(null, editor, null);

        ctrl.insert('\nfoo');
        assertSelections(editor, [new Selection(2, 8, 2, 8)]);
    }

    function testIssue145727InsertSnippetCanPutSnippetSelectionsInWrongPositions1Of2() {
        ctrl = createController();
        model.setValue('');
        CoreEditingCommands.Tab.runEditorCommand(null, editor, null);

        ctrl.insert("\naProperty: aClass<${2:boolean}> = new aClass<${2:boolean}>();\n", {adjustWhitespace: false});
        assertSelections(editor, [new Selection(2, 19, 2, 26), new Selection(2, 41, 2, 48)]);
    }

    function testIssue145727InsertSnippetCanPutSnippetSelectionsInWrongPositions2Of2() {
        ctrl = createController();
        model.setValue('');
        CoreEditingCommands.Tab.runEditorCommand(null, editor, null);

        ctrl.insert("\naProperty: aClass<${2:boolean}> = new aClass<${2:boolean}>();\n");
        // This will insert \n    aProperty....
        assertSelections(editor, [new Selection(2, 23, 2, 30), new Selection(2, 45, 2, 52)]);
    }

    function testLeadingTABBySnippetsWontReplaceBySpaces101870() {
        ctrl = createController();
        model.setValue('');
        model.updateOptions({insertSpaces: true, tabSize: 4});
        ctrl.insert('\tHello World\n\tNew Line');
        assertEquals('    Hello World\n    New Line', model.getValue());
    }

    function testLeadingTABBySnippetsWontReplaceBySpaces101870Part2() {
        ctrl = createController();
        model.setValue('');
        model.updateOptions({insertSpaces: true, tabSize: 4});
        ctrl.insert("\tHello World\n\tNew Line\n${1:\tmore}");
        assertEquals('    Hello World\n    New Line\n    more', model.getValue());
    }

    // suite('createEditsAndSnippetsFromEdits')

    function testApplyTabDone() {

        ctrl = createController();

        model.setValue('foo("bar")');

        ctrl.apply([
            {range: new Range(1, 5, 1, 10), template: "$1"},
            {range: new Range(1, 1, 1, 1), template: "const ${1:new_const} = \"bar\";\n"}
        ]);

        assertEquals("const new_const = \"bar\";\nfoo(new_const)", model.getValue());
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 7, 1, 16), new Selection(2, 5, 2, 14)]);

        ctrl.next();
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(2, 14, 2, 14)]);
    }

    function testApplyTabDoneWithSpecialFinalTabstop() {

        model.setValue('foo("bar")');

        ctrl = createController();
        ctrl.apply([
            {range: new Range(1, 5, 1, 10), template: "$1"},
            {range: new Range(1, 1, 1, 1), template: "const ${1:new_const}$0 = \"bar\";\n"}
        ]);

        assertEquals("const new_const = \"bar\";\nfoo(new_const)", model.getValue());
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 7, 1, 16), new Selection(2, 5, 2, 14)]);

        ctrl.next();
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(1, 16, 1, 16)]);
    }

    function testApplyTabTabDone() {

        model.setValue('foo\nbar');

        ctrl = createController();
        ctrl.apply([
            {range: new Range(1, 4, 1, 4), template: "${3}"},
            {range: new Range(2, 4, 2, 4), template: "$3"},
            {range: new Range(1, 1, 1, 1), template: "### ${2:Header}\n"}
        ]);

        assertEquals("### Header\nfoo\nbar", model.getValue());
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 5, 1, 11)]);

        ctrl.next();
        assertContextKeys(true, true, true);
        assertSelections(editor, [new Selection(2, 4, 2, 4), new Selection(3, 4, 3, 4)]);

        ctrl.next();
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(3, 4, 3, 4)]);
    }

    function testApplyNestedIntoApplyWorks() {

        ctrl = createController();
        model.setValue('onetwo');

        editor.setSelections([new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1)]);

        ctrl.apply([{
            range: new Range(1, 7, 1, 7),
            template: "$0${1:three}"
        }]);

        assertEquals('onetwothree', model.getValue());
        assertContextKeys(true, false, true);
        assertSelections(editor, [new Selection(1, 7, 1, 12)]);

        ctrl.insert("foo$1bar$1");
        assertEquals('onetwofoobar', model.getValue());
        assertSelections(editor, [new Selection(1, 10, 1, 10), new Selection(1, 13, 1, 13)]);
        assertContextKeys(true, false, true);

        ctrl.next();
        assertContextKeys(true, true, true);
        assertSelections(editor, [new Selection(1, 13, 1, 13)]);

        ctrl.next();
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(1, 7, 1, 7)]);
    }

    function testApplyNestedIntoInsertAbortOuterSnippet() {

        ctrl = createController();
        model.setValue('one\ntwo');

        editor.setSelections([new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1)]);

        ctrl.insert("foo${1:bar}bazz${1:bang}");
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(1, 11, 1, 14), new Selection(2, 4, 2, 7), new Selection(2, 11, 2, 14)]);
        assertContextKeys(true, false, true);

        ctrl.apply([{
            range: new Range(1, 4, 1, 7),
            template: "$0A"
        }]);

        assertEquals('fooAbazzbarone\nfoobarbazzbartwo', model.getValue());
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(1, 4, 1, 4)]);
    }

    function testApplyNestedIntoInsertAbortOuterSnippet2() {

        ctrl = createController();
        model.setValue('one\ntwo');

        editor.setSelections([new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1)]);

        ctrl.insert("foo${1:bar}bazz${1:bang}");
        assertSelections(editor, [new Selection(1, 4, 1, 7), new Selection(1, 11, 1, 14), new Selection(2, 4, 2, 7), new Selection(2, 11, 2, 14)]);
        assertContextKeys(true, false, true);

        final edits = [{
            range: new Range(1, 4, 1, 7),
            template: 'A'
        }, {
            range: new Range(1, 11, 1, 14),
            template: 'B'
        }, {
            range: new Range(2, 4, 2, 7),
            template: 'C'
        }, {
            range: new Range(2, 11, 2, 14),
            template: 'D'
        }];
        ctrl.apply(edits);

        assertEquals("fooAbazzBone\nfooCbazzDtwo", model.getValue());
        assertContextKeys(false, false, false);
        assertSelections(editor, [new Selection(1, 5, 1, 5), new Selection(1, 10, 1, 10), new Selection(2, 5, 2, 5), new Selection(2, 10, 2, 10)]);
    }

    function testBugCursorPosition0WithUserSnippets163808() {

        ctrl = createController();
        model.setValue('');

        ctrl.insert("<Element1 Attr1=\"foo\" $1>\n  <Element2 Attr1=\"$2\"/>\n$0\"\n</Element1>");
        assertSelections(editor, [new Selection(1, 23, 1, 23)]);

        ctrl.insert("Qualifier=\"$0\"");
        assertEquals('<Element1 Attr1="foo" Qualifier="">\n  <Element2 Attr1=""/>\n"\n</Element1>', model.getValue());
        assertSelections(editor, [new Selection(1, 34, 1, 34)]);
    }

    function testEOLSequenceCRLFShiftsTabStopInIsFileTemplateSnippets167386() {
        ctrl = createController();
        model.setValue('');
        model.setEOL(EndOfLineSequence.CRLF);

        ctrl.apply([{
            range: model.getFullModelRange(),
            template: "line 54321${1:FOO}\nline 54321${1:FOO}\n(no tab stop)\nline 54321${1:FOO}\nline 54321"
        }]);

        assertSelections(editor, [new Selection(1, 11, 1, 14), new Selection(2, 11, 2, 14), new Selection(4, 11, 4, 14)]);
    }

    function testSurroundWithCodeActionSnippetsUseIncorrectIndentationLevelsAndStyles169319() {
        model.setValue('function foo(f, x, condition) {\n    f();\n    return x;\n}');
        final sel = new Range(2, 5, 3, 14);
        editor.setSelection(sel);
        ctrl = createController();
        ctrl.apply([{
            range: sel,
            template: "if (${1:condition}) {\n\t$TM_SELECTED_TEXT$0\n}"
        }]);

        assertEquals('function foo(f, x, condition) {\n    if (condition) {\n        f();\n        return x;\n    }\n}', model.getValue());
    }

}
