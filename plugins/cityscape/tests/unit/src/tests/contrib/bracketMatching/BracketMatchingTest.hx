// Ported from vscode src/vs/editor/contrib/bracketMatching/test/browser/bracketMatching.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.bracketMatching;

import cityscape.Cityscape;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.bracketMatching.view.BracketMatching;
import cityscape.view.EditorExtensions.EditorContributionInstantiation;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

/**
 * suite('bracket matching'), plus Cityscape tests of the decorations (the
 * matching brackets of the cursor, Monaco's `_updateBrackets`, flushed
 * instead of waiting 50 ms).
 */
class BracketMatchingTest extends TestCase {

    var disposables:Array<{function dispose():Void;}> = [];

    override public function setup():Void {
        disposables = [];
    }

    override public function teardown():Void {
        for (d in disposables) {
            d.dispose();
        }
        disposables = [];
    }

    function createTextModelWithBrackets(context:Cityscape, text:String):TestTextModel {
        final languageId = 'bracketMode';
        disposables.push(context.languageService.registerLanguage({id: languageId}));
        disposables.push(context.languageConfigurationService.register(languageId, {
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')'],
            ]
        }));
        final model = TestTextModel.instantiateTextModel(context, text, languageId);
        disposables.push(model);
        return model;
    }

    /**
     * `createCodeEditorWithBrackets` and
     * `editor.registerAndInstantiateContribution(BracketMatchingController.ID, BracketMatchingController)`.
     */
    function createCodeEditorWithBrackets(text:String):TestCodeEditor {
        final context = new Cityscape();
        final model = createTextModelWithBrackets(context, text);
        final editor = new TestCodeEditor(context, model, {}, [{
            id: BracketMatchingController.ID,
            ctor: e -> new BracketMatchingController(e),
            instantiation: EditorContributionInstantiation.Eager
        }]);
        disposables.unshift(editor);
        return editor;
    }

    function controllerOf(editor:TestCodeEditor):BracketMatchingController {
        return BracketMatchingController.get(editor);
    }

    function assertPosition(expected:Position, actual:Null<Position>, ?pos:haxe.PosInfos) {
        assertEquals(expected.toString(), actual != null ? actual.toString() : null, null, pos);
    }

    function assertSelection(expected:Selection, actual:Null<Selection>, ?pos:haxe.PosInfos) {
        assertEquals(expected.toString(), actual != null ? actual.toString() : null, null, pos);
    }

    function testIssue183JumpToMatchingBracketPosition() {
        final editor = createCodeEditorWithBrackets('var x = (3 + (5-7)) + ((5+3)+5);');
        final bracketMatchingController = controllerOf(editor);

        // start on closing bracket
        editor.setPosition(new Position(1, 20));
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 9), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 19), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 9), editor.getPosition());

        // start on opening bracket
        editor.setPosition(new Position(1, 23));
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 31), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 23), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 31), editor.getPosition());
    }

    function testJumpToNextBracket() {
        final editor = createCodeEditorWithBrackets('var x = (3 + (5-7)); y();');
        final bracketMatchingController = controllerOf(editor);

        // start position between brackets
        editor.setPosition(new Position(1, 16));
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 18), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 14), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 18), editor.getPosition());

        // skip brackets in comments
        editor.setPosition(new Position(1, 21));
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 23), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 24), editor.getPosition());
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 23), editor.getPosition());

        // do not break if no brackets are available
        editor.setPosition(new Position(1, 26));
        bracketMatchingController.jumpToBracket();
        assertPosition(new Position(1, 26), editor.getPosition());
    }

    function testSelectToNextBracket() {
        final editor = createCodeEditorWithBrackets('var x = (3 + (5-7)); y();');
        final bracketMatchingController = controllerOf(editor);

        // start position in open brackets
        editor.setPosition(new Position(1, 9));
        bracketMatchingController.selectToBracket(true);
        assertPosition(new Position(1, 20), editor.getPosition());
        assertSelection(new Selection(1, 9, 1, 20), editor.getSelection());

        // start position in close brackets (should select backwards)
        editor.setPosition(new Position(1, 20));
        bracketMatchingController.selectToBracket(true);
        assertPosition(new Position(1, 9), editor.getPosition());
        assertSelection(new Selection(1, 20, 1, 9), editor.getSelection());

        // start position between brackets
        editor.setPosition(new Position(1, 16));
        bracketMatchingController.selectToBracket(true);
        assertPosition(new Position(1, 19), editor.getPosition());
        assertSelection(new Selection(1, 14, 1, 19), editor.getSelection());

        // start position outside brackets
        editor.setPosition(new Position(1, 21));
        bracketMatchingController.selectToBracket(true);
        assertPosition(new Position(1, 25), editor.getPosition());
        assertSelection(new Selection(1, 23, 1, 25), editor.getSelection());

        // do not break if no brackets are available
        editor.setPosition(new Position(1, 26));
        bracketMatchingController.selectToBracket(true);
        assertPosition(new Position(1, 26), editor.getPosition());
        assertSelection(new Selection(1, 26, 1, 26), editor.getSelection());
    }

    function testIssue1772JumpToEnclosingBrackets() {
        final text = [
            'const x = {',
            '    something: [0, 1, 2],',
            '    another: true,',
            '    somethingmore: [0, 2, 4]',
            '};',
        ].join('\n');
        final editor = createCodeEditorWithBrackets(text);
        final bracketMatchingController = controllerOf(editor);

        editor.setPosition(new Position(3, 5));
        bracketMatchingController.jumpToBracket();
        assertSelection(new Selection(5, 1, 5, 1), editor.getSelection());
    }

    function testIssue43371ArgumentToNotSelectBrackets() {
        final text = [
            'const x = {',
            '    something: [0, 1, 2],',
            '    another: true,',
            '    somethingmore: [0, 2, 4]',
            '};',
        ].join('\n');
        final editor = createCodeEditorWithBrackets(text);
        final bracketMatchingController = controllerOf(editor);

        editor.setPosition(new Position(3, 5));
        bracketMatchingController.selectToBracket(false);
        assertSelection(new Selection(1, 12, 5, 1), editor.getSelection());
    }

    function testIssue45369SelectToBracketWithMulticursor() {
        final editor = createCodeEditorWithBrackets('{  }   {   }   { }');
        final bracketMatchingController = controllerOf(editor);

        // cursors inside brackets become selections of the entire bracket contents
        editor.setSelections([
            new Selection(1, 3, 1, 3),
            new Selection(1, 10, 1, 10),
            new Selection(1, 17, 1, 17)
        ]);
        bracketMatchingController.selectToBracket(true);
        assertEquals([
            new Selection(1, 1, 1, 5),
            new Selection(1, 8, 1, 13),
            new Selection(1, 16, 1, 19)
        ].join(','), editor.getSelections().join(','));

        // cursors to the left of bracket pairs become selections of the entire pair
        editor.setSelections([
            new Selection(1, 1, 1, 1),
            new Selection(1, 6, 1, 6),
            new Selection(1, 14, 1, 14)
        ]);
        bracketMatchingController.selectToBracket(true);
        assertEquals([
            new Selection(1, 1, 1, 5),
            new Selection(1, 8, 1, 13),
            new Selection(1, 16, 1, 19)
        ].join(','), editor.getSelections().join(','));

        // cursors just right of a bracket pair become selections of the entire pair
        editor.setSelections([
            new Selection(1, 5, 1, 5),
            new Selection(1, 13, 1, 13),
            new Selection(1, 19, 1, 19)
        ]);
        bracketMatchingController.selectToBracket(true);
        assertEquals([
            new Selection(1, 5, 1, 1),
            new Selection(1, 13, 1, 8),
            new Selection(1, 19, 1, 16)
        ].join(','), editor.getSelections().join(','));
    }

    function testRemovesBrackets() {
        final editor = createCodeEditorWithBrackets('var x = (3 + (5-7)); y();');
        final bracketMatchingController = controllerOf(editor);
        function removeBrackets() {
            bracketMatchingController.removeBrackets();
        }

        // position before the bracket
        editor.setPosition(new Position(1, 9));
        removeBrackets();
        assertEquals('var x = 3 + (5-7); y();', editor.getModel().getValue());
        editor.getModel().setValue('var x = (3 + (5-7)); y();');

        // position between brackets
        editor.setPosition(new Position(1, 16));
        removeBrackets();
        assertEquals('var x = (3 + 5-7); y();', editor.getModel().getValue());
        removeBrackets();
        assertEquals('var x = 3 + 5-7; y();', editor.getModel().getValue());
        removeBrackets();
        assertEquals('var x = 3 + 5-7; y();', editor.getModel().getValue());
    }

    // ---- Cityscape tests (the decorations of `_updateBrackets`)

    function bracketMatchRanges(editor:TestCodeEditor):String {
        final result:Array<String> = [];
        for (d in editor.getModel().getAllDecorations()) {
            if (d.options.className == 'bracket-match') {
                result.push(Range.lift(d.range).toString() + (d.options.overviewRuler != null ? '+ruler' : ''));
            }
        }
        result.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return result.join(' ');
    }

    function testCityscapeDecorationsOfTheMatchingBrackets() {
        final editor = createCodeEditorWithBrackets('var x = (3 + (5-7)); y();');
        editor.getViewModel().setHasFocus(true);
        final controller = controllerOf(editor);

        // on a bracket: both brackets, with an overview ruler mark
        editor.setPosition(new Position(1, 9));
        controller._flushPendingUpdate();
        assertEquals('[1,19 -> 1,20]+ruler [1,9 -> 1,10]+ruler', bracketMatchRanges(editor));

        // inside brackets ('always'): the enclosing brackets, without a mark
        editor.setPosition(new Position(1, 16));
        controller._flushPendingUpdate();
        assertEquals('[1,14 -> 1,15] [1,18 -> 1,19]', bracketMatchRanges(editor));

        // 'near': only on a bracket
        editor.updateOptions({matchBrackets: 'near'});
        editor.setPosition(new Position(1, 16));
        controller._flushPendingUpdate();
        assertEquals('', bracketMatchRanges(editor));

        // 'never'
        editor.updateOptions({matchBrackets: 'never'});
        editor.setPosition(new Position(1, 9));
        controller._flushPendingUpdate();
        assertEquals('', bracketMatchRanges(editor));
    }

    function testCityscapeNoDecorationsWithoutFocus() {
        final editor = createCodeEditorWithBrackets('(a)');
        editor.getViewModel().setHasFocus(false);
        final controller = controllerOf(editor);
        editor.setPosition(new Position(1, 1));
        controller._flushPendingUpdate();
        assertEquals('', bracketMatchRanges(editor));
    }

    function testCityscapeActionsAreRegistered() {
        final context = new Cityscape();
        final ids = [for (a in context.editorExtensions.getEditorActions()) a.id];
        assertTrue(ids.indexOf('editor.action.jumpToBracket') != -1);
        assertTrue(ids.indexOf('editor.action.selectToBracket') != -1);
        assertTrue(ids.indexOf('editor.action.removeBrackets') != -1);
        assertEquals(1, [for (c in context.editorExtensions.getEditorContributions()) if (c.id == BracketMatchingController.ID) c].length);
    }

}
