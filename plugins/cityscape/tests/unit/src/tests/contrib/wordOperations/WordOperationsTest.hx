// Ported from vscode src/vs/editor/contrib/wordOperations/test/browser/wordOperations.test.ts
// and wordTestUtils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.wordOperations;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.contrib.wordOperations.view.WordOperations;
import cityscape.view.CoreCommands;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

/**
 * suite('WordOperations')
 */
class WordOperationsTest extends TestCase {

    final _cursorWordStartLeft = new CursorWordStartLeft();
    final _cursorWordEndLeft = new CursorWordEndLeft();
    final _cursorWordLeft = new CursorWordLeft();
    final _cursorWordStartLeftSelect = new CursorWordStartLeftSelect();
    final _cursorWordEndLeftSelect = new CursorWordEndLeftSelect();
    final _cursorWordLeftSelect = new CursorWordLeftSelect();
    final _cursorWordStartRight = new CursorWordStartRight();
    final _cursorWordEndRight = new CursorWordEndRight();
    final _cursorWordRight = new CursorWordRight();
    final _cursorWordStartRightSelect = new CursorWordStartRightSelect();
    final _cursorWordEndRightSelect = new CursorWordEndRightSelect();
    final _cursorWordRightSelect = new CursorWordRightSelect();
    final _cursorWordAccessibilityLeft = new CursorWordAccessibilityLeft();
    final _cursorWordAccessibilityLeftSelect = new CursorWordAccessibilityLeftSelect();
    final _cursorWordAccessibilityRight = new CursorWordAccessibilityRight();
    final _cursorWordAccessibilityRightSelect = new CursorWordAccessibilityRightSelect();
    final _deleteWordLeft = new DeleteWordLeft();
    final _deleteWordStartLeft = new DeleteWordStartLeft();
    final _deleteWordEndLeft = new DeleteWordEndLeft();
    final _deleteWordRight = new DeleteWordRight();
    final _deleteWordStartRight = new DeleteWordStartRight();
    final _deleteWordEndRight = new DeleteWordEndRight();
    final _deleteInsideWord = new DeleteInsideWord();

    var disposables:DisposableStore;
    var instantiationService:Cityscape;
    var languageConfigurationService:cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
    var languageService:cityscape.common.services.LanguageService;

    override function setup():Void {
        disposables = new DisposableStore();
        instantiationService = new Cityscape();
        languageConfigurationService = instantiationService.languageConfigurationService;
        languageService = instantiationService.languageService;
    }

    override function teardown():Void {
        disposables.dispose();
    }

    // ---- wordTestUtils.ts

    static function deserializePipePositions(text:String):{text:String, positions:Array<Position>} {
        var resultText = '';
        var lineNumber = 1;
        var charIndex = 0;
        final positions:Array<Position> = [];
        for (i in 0...text.length) {
            final chr = text.charAt(i);
            if (chr == '\n') {
                resultText += chr;
                lineNumber++;
                charIndex = 0;
                continue;
            }
            if (chr == '|') {
                positions.push(new Position(lineNumber, charIndex + 1));
            }
            else {
                resultText += chr;
                charIndex++;
            }
        }
        return {text: resultText, positions: positions};
    }

    static function serializePipePositions(text:String, positions:Array<Position>):String {
        haxe.ds.ArraySort.sort(positions, Position.compare);
        var resultText = '';
        var lineNumber = 1;
        var charIndex = 0;
        for (i in 0...text.length) {
            final chr = text.charAt(i);
            if (positions.length > 0 && positions[0].lineNumber == lineNumber && positions[0].column == charIndex + 1) {
                resultText += '|';
                positions.shift();
            }
            resultText += chr;
            if (chr == '\n') {
                lineNumber++;
                charIndex = 0;
            }
            else {
                charIndex++;
            }
        }
        if (positions.length > 0 && positions[0].lineNumber == lineNumber && positions[0].column == charIndex + 1) {
            resultText += '|';
            positions.shift();
        }
        if (positions.length > 0) {
            throw 'Unexpected left over positions!!!';
        }
        return resultText;
    }

    function repeatedActionAndExtractPositions(text:String, initialPosition:Position, action:(editor:TestCodeEditor) -> Void, record:(editor:TestCodeEditor) -> Position, stopCondition:(editor:TestCodeEditor) -> Bool, ?options:cityscape.common.config.EditorOptions.IEditorOptions):Array<Position> {
        final actualStops:Array<Position> = [];
        withTestCodeEditor(text, options != null ? options : {}, (editor, _) -> {
            editor.setPosition(initialPosition);
            while (true) {
                action(editor);
                actualStops.push(record(editor));
                if (stopCondition(editor)) {
                    break;
                }

                if (actualStops.length > 1000) {
                    throw 'Endless loop detected involving position ${editor.getPosition()}!';
                }
            }
        });
        return actualStops;
    }

    function withTestCodeEditor(text:Dynamic, options:cityscape.common.config.EditorOptions.IEditorOptions, callback:(editor:TestCodeEditor, viewModel:ViewModel) -> Void):Void {
        TestCodeEditor.withTestCodeEditor(text, options, callback);
    }

    // ---- the suite's helpers

    function runEditorCommand(editor:TestCodeEditor, command:EditorCommand):Void {
        command.runEditorCommand(instantiationService, editor, null);
    }
    function cursorWordLeft(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordLeftSelect : _cursorWordLeft);
    }
    function cursorWordAccessibilityLeft(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordAccessibilityLeft : _cursorWordAccessibilityLeftSelect);
    }
    function cursorWordAccessibilityRight(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordAccessibilityRightSelect : _cursorWordAccessibilityRight);
    }
    function cursorWordStartLeft(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordStartLeftSelect : _cursorWordStartLeft);
    }
    function cursorWordEndLeft(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordEndLeftSelect : _cursorWordEndLeft);
    }
    function cursorWordRight(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordRightSelect : _cursorWordRight);
    }
    function moveWordEndRight(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordEndRightSelect : _cursorWordEndRight);
    }
    function moveWordStartRight(editor:TestCodeEditor, inSelectionMode:Bool = false):Void {
        runEditorCommand(editor, inSelectionMode ? _cursorWordStartRightSelect : _cursorWordStartRight);
    }
    function deleteWordLeft(editor:TestCodeEditor):Void {
        runEditorCommand(editor, _deleteWordLeft);
    }
    function deleteWordStartLeft(editor:TestCodeEditor):Void {
        runEditorCommand(editor, _deleteWordStartLeft);
    }
    function deleteWordEndLeft(editor:TestCodeEditor):Void {
        runEditorCommand(editor, _deleteWordEndLeft);
    }
    function deleteWordRight(editor:TestCodeEditor):Void {
        runEditorCommand(editor, _deleteWordRight);
    }
    function deleteWordStartRight(editor:TestCodeEditor):Void {
        runEditorCommand(editor, _deleteWordStartRight);
    }
    function deleteWordEndRight(editor:TestCodeEditor):Void {
        runEditorCommand(editor, _deleteWordEndRight);
    }
    function deleteInsideWord(editor:TestCodeEditor):Void {
        _deleteInsideWord.run(null, editor, null);
    }

    /**
     * test('cursorWordLeft - simple')
     */
    function testCursorWordLeftSimple() {
        final EXPECTED = [
            '|    \t|My |First |Line\t ',
            '|\t|My |Second |Line',
            '|    |Third |Line🐶',
            '|',
            '|1',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordLeft - with selection')
     */
    function testCursorWordLeftWithSelection() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            editor.setPosition(new Position(5, 2));
            cursorWordLeft(editor, true);
            assertDeepEquals(editor.getSelection(), new Selection(5, 2, 5, 1));
        });
    }

    /**
     * test('cursorWordLeft - issue #832')
     */
    function testCursorWordLeftIssue832() {
        final EXPECTED = ['|   |/* |Just |some   |more   |text |a|+= |3 |+|5-|3 |+ |7 |*/  '].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordLeft - issue #48046: Word selection doesn\'t work as usual')
     */
    function testCursorWordLeftIssue48046WordSelectionDoesnTWorkAsUsual() {
        final EXPECTED = [
            '|deep.|object.|property',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 21),
            ed -> cursorWordLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordLeft - Recognize words')
     */
    function testCursorWordLeftRecognizeWords() {
        // vscode skips this test on Firefox (https://github.com/microsoft/vscode/issues/219843).
        // Cityscape: the words come from `Intl.Segmenter` on JavaScript only,
        // UAX #29 elsewhere (DEVIATIONS.md, "Word segmentation"); see
        // testCityscapeRecognizeWordsUax29.
        #if !js
        return;
        #end
        final EXPECTED = [
            '|/* |これ|は|テスト|です |/*',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordLeft(ed, true),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1)),
            {
                wordSegmenterLocales: 'ja'
            }
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordLeft - Does not recognize words')
     */
    function testCursorWordLeftDoesNotRecognizeWords() {
        final EXPECTED = [
            '|/* |これはテストです |/*',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordLeft(ed, true),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1)),
            {
                wordSegmenterLocales: ''
            }
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordLeft - issue #169904: cursors out of sync')
     */
    function testCursorWordLeftIssue169904CursorsOutOfSync() {
        final text = [
            '.grid1 {',
            '  display: grid;',
            '  grid-template-columns:',
            '    [full-start] minmax(1em, 1fr)',
            '    [main-start] minmax(0, 40em) [main-end]',
            '    minmax(1em, 1fr) [full-end];',
            '}',
            '.grid2 {',
            '  display: grid;',
            '  grid-template-columns:',
            '    [full-start] minmax(1em, 1fr)',
            '    [main-start] minmax(0, 40em) [main-end] minmax(1em, 1fr) [full-end];',
            '}',
        ];
        withTestCodeEditor(text, {}, (editor, _) -> {
            editor.setSelections([
                new Selection(5, 44, 5, 44),
                new Selection(6, 32, 6, 32),
                new Selection(12, 44, 12, 44),
                new Selection(12, 72, 12, 72),
            ]);
            cursorWordLeft(editor, false);
            assertDeepEquals(editor.getSelections(), [
                new Selection(5, 43, 5, 43),
                new Selection(6, 31, 6, 31),
                new Selection(12, 43, 12, 43),
                new Selection(12, 71, 12, 71),
            ]);

        });
    }

    /**
     * test('cursorWordLeftSelect - issue #74369: cursorWordLeft and cursorWordLeftSelect do not behave consistently')
     */
    function testCursorWordLeftSelectIssue74369CursorWordLeftAndCursorWordLeftSelectDoNotBehaveConsistently() {
        final EXPECTED = [
            '|this.|is.|a.|test',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 15),
            ed -> cursorWordLeft(ed, true),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordStartLeft')
     */
    function testCursorWordStartLeft() {
        // This is the behaviour observed in Visual Studio, please do not touch test
        final EXPECTED = ['|   |/* |Just |some   |more   |text |a|+= |3 |+|5|-|3 |+ |7 |*/  '].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordStartLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordStartLeft - issue #51119: regression makes VS compatibility impossible')
     */
    function testCursorWordStartLeftIssue51119RegressionMakesVSCompatibilityImpossible() {
        // This is the behaviour observed in Visual Studio, please do not touch test
        final EXPECTED = ['|this|.|is|.|a|.|test'].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordStartLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('issue #51275 - cursorWordStartLeft does not push undo/redo stack element')
     */
    function testIssue51275CursorWordStartLeftDoesNotPushUndoRedoStackElement() {
        function type(viewModel:ViewModel, text:String) {
            for (i in 0...text.length) {
                viewModel.type(text.charAt(i), 'keyboard');
            }
        }

        withTestCodeEditor('', {}, (editor, viewModel) -> {
            type(viewModel, 'foo bar baz');
            assertEquals(editor.getValue(), 'foo bar baz');

            cursorWordStartLeft(editor);
            cursorWordStartLeft(editor);
            type(viewModel, 'q');

            assertEquals(editor.getValue(), 'foo qbar baz');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(editor.getValue(), 'foo bar baz');
        });
    }

    /**
     * test('cursorWordEndLeft')
     */
    function testCursorWordEndLeft() {
        final EXPECTED = ['|   /*| Just| some|   more|   text| a|+=| 3| +|5|-|3| +| 7| */|  '].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordEndLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordRight - simple')
     */
    function testCursorWordRightSimple() {
        final EXPECTED = [
            '    \tMy| First| Line|\t |',
            '\tMy| Second| Line|',
            '    Third| Line🐶|',
            '|',
            '1|',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> cursorWordRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(5, 2))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordRight - selection')
     */
    function testCursorWordRightSelection() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            editor.setPosition(new Position(1, 1));
            cursorWordRight(editor, true);
            assertDeepEquals(editor.getSelection(), new Selection(1, 1, 1, 8));
        });
    }

    /**
     * test('cursorWordRight - issue #832')
     */
    function testCursorWordRightIssue832() {
        final EXPECTED = [
            '   /*| Just| some|   more|   text| a|+=| 3| +5|-3| +| 7| */|  |',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> cursorWordRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 50))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordRight - issue #41199')
     */
    function testCursorWordRightIssue41199() {
        final EXPECTED = [
            'console|.log|(err|)|',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> cursorWordRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 17))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordRight - Recognize words')
     */
    function testCursorWordRightRecognizeWords() {
        // vscode skips this test on Firefox (https://github.com/microsoft/vscode/issues/219843).
        // Cityscape: the words come from `Intl.Segmenter` on JavaScript only,
        // UAX #29 elsewhere (DEVIATIONS.md, "Word segmentation"); see
        // testCityscapeRecognizeWordsUax29.
        #if !js
        return;
        #end
        final EXPECTED = [
            '/*| これ|は|テスト|です|/*|',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> cursorWordRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 14)),
            {
                wordSegmenterLocales: 'ja'
            }
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordRight - Does not recognize words')
     */
    function testCursorWordRightDoesNotRecognizeWords() {
        final EXPECTED = [
            '/*| これはテストです|/*|',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> cursorWordRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 14)),
            {
                wordSegmenterLocales: ''
            }
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('moveWordEndRight')
     */
    function testMoveWordEndRight() {
        final EXPECTED = [
            '   /*| Just| some|   more|   text| a|+=| 3| +5|-3| +| 7| */|  |',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> moveWordEndRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 50))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('moveWordStartRight')
     */
    function testMoveWordStartRight() {
        // This is the behaviour observed in Visual Studio, please do not touch test
        final EXPECTED = [
            '   |/* |Just |some   |more   |text |a|+= |3 |+|5|-|3 |+ |7 |*/  |',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> moveWordStartRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 50))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('issue #51119: cursorWordStartRight regression makes VS compatibility impossible')
     */
    function testIssue51119CursorWordStartRightRegressionMakesVSCompatibilityImpossible() {
        // This is the behaviour observed in Visual Studio, please do not touch test
        final EXPECTED = ['this|.|is|.|a|.|test|'].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> moveWordStartRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 15))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('issue #64810: cursorWordStartRight skips first word after newline')
     */
    function testIssue64810CursorWordStartRightSkipsFirstWordAfterNewline() {
        // This is the behaviour observed in Visual Studio, please do not touch test
        final EXPECTED = ['Hello |World|', '|Hei |mailman|'].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> moveWordStartRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(2, 12))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordAccessibilityLeft')
     */
    function testCursorWordAccessibilityLeft() {
        final EXPECTED = ['|   /* |Just |some   |more   |text |a+= |3 +|5-|3 + |7 */  '].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 1000),
            ed -> cursorWordAccessibilityLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 1))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('cursorWordAccessibilityRight')
     */
    function testCursorWordAccessibilityRight() {
        final EXPECTED = ['   /* |Just |some   |more   |text |a+= |3 +|5-|3 + |7 */  |'].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> cursorWordAccessibilityRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 50))
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('deleteWordLeft for non-empty selection')
     */
    function testDeleteWordLeftForNonEmptySelection() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setSelection(new Selection(3, 7, 3, 9));
            deleteWordLeft(editor);
            assertEquals(model.getLineContent(3), '    Thd Line🐶');
            assertDeepEquals(editor.getPosition(), new Position(3, 7));
        });
    }

    /**
     * test('deleteWordLeft for cursor at beginning of document')
     */
    function testDeleteWordLeftForCursorAtBeginningOfDocument() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 1));
            deleteWordLeft(editor);
            assertEquals(model.getLineContent(1), '    \tMy First Line\t ');
            assertDeepEquals(editor.getPosition(), new Position(1, 1));
        });
    }

    /**
     * test('deleteWordLeft for cursor at end of whitespace')
     */
    function testDeleteWordLeftForCursorAtEndOfWhitespace() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(3, 11));
            deleteWordLeft(editor);
            assertEquals(model.getLineContent(3), '    Line🐶');
            assertDeepEquals(editor.getPosition(), new Position(3, 5));
        });
    }

    /**
     * test('deleteWordLeft for cursor just behind a word')
     */
    function testDeleteWordLeftForCursorJustBehindAWord() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(2, 11));
            deleteWordLeft(editor);
            assertEquals(model.getLineContent(2), '\tMy  Line');
            assertDeepEquals(editor.getPosition(), new Position(2, 5));
        });
    }

    /**
     * test('deleteWordLeft for cursor inside of a word')
     */
    function testDeleteWordLeftForCursorInsideOfAWord() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 12));
            deleteWordLeft(editor);
            assertEquals(model.getLineContent(1), '    \tMy st Line\t ');
            assertDeepEquals(editor.getPosition(), new Position(1, 9));
        });
    }

    /**
     * test('deleteWordRight for non-empty selection')
     */
    function testDeleteWordRightForNonEmptySelection() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setSelection(new Selection(3, 7, 3, 9));
            deleteWordRight(editor);
            assertEquals(model.getLineContent(3), '    Thd Line🐶');
            assertDeepEquals(editor.getPosition(), new Position(3, 7));
        });
    }

    /**
     * test('deleteWordRight for cursor at end of document')
     */
    function testDeleteWordRightForCursorAtEndOfDocument() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(5, 3));
            deleteWordRight(editor);
            assertEquals(model.getLineContent(5), '1');
            assertDeepEquals(editor.getPosition(), new Position(5, 2));
        });
    }

    /**
     * test('deleteWordRight for cursor at beggining of whitespace')
     */
    function testDeleteWordRightForCursorAtBegginingOfWhitespace() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(3, 1));
            deleteWordRight(editor);
            assertEquals(model.getLineContent(3), 'Third Line🐶');
            assertDeepEquals(editor.getPosition(), new Position(3, 1));
        });
    }

    /**
     * test('deleteWordRight for cursor just before a word')
     */
    function testDeleteWordRightForCursorJustBeforeAWord() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(2, 5));
            deleteWordRight(editor);
            assertEquals(model.getLineContent(2), '\tMy  Line');
            assertDeepEquals(editor.getPosition(), new Position(2, 5));
        });
    }

    /**
     * test('deleteWordRight for cursor inside of a word')
     */
    function testDeleteWordRightForCursorInsideOfAWord() {
        withTestCodeEditor([
            '    \tMy First Line\t ',
            '\tMy Second Line',
            '    Third Line🐶',
            '',
            '1',
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 11));
            deleteWordRight(editor);
            assertEquals(model.getLineContent(1), '    \tMy Fi Line\t ');
            assertDeepEquals(editor.getPosition(), new Position(1, 11));
        });
    }

    /**
     * test('deleteWordLeft - issue #832')
     */
    function testDeleteWordLeftIssue832() {
        final EXPECTED = [
            '|   |/* |Just |some |text |a|+= |3 |+|5 |*/|  ',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 10000),
            ed -> deleteWordLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getValue().length == 0
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('deleteWordStartLeft')
     */
    function testDeleteWordStartLeft() {
        final EXPECTED = [
            '|   |/* |Just |some |text |a|+= |3 |+|5 |*/  ',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 10000),
            ed -> deleteWordStartLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getValue().length == 0
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('deleteWordEndLeft')
     */
    function testDeleteWordEndLeft() {
        final EXPECTED = [
            '|   /*| Just| some| text| a|+=| 3| +|5| */|  ',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1000, 10000),
            ed -> deleteWordEndLeft(ed),
            ed -> ed.getPosition(),
            ed -> ed.getValue().length == 0
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('deleteWordLeft - issue #24947')
     */
    function testDeleteWordLeftIssue24947() {
        withTestCodeEditor([
            '{',
            '}'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(2, 1));
            deleteWordLeft(editor); assertEquals(model.getLineContent(1), '{}');
        });

        withTestCodeEditor([
            '{',
            '}'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(2, 1));
            deleteWordStartLeft(editor); assertEquals(model.getLineContent(1), '{}');
        });

        withTestCodeEditor([
            '{',
            '}'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(2, 1));
            deleteWordEndLeft(editor); assertEquals(model.getLineContent(1), '{}');
        });
    }

    /**
     * test('deleteWordRight - issue #832')
     */
    function testDeleteWordRightIssue832() {
        final EXPECTED = '   |/*| Just| some| text| a|+=| 3| +|5|-|3| */|  |';
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> deleteWordRight(ed),
            ed -> new Position(1, text.length - ed.getValue().length + 1),
            ed -> ed.getValue().length == 0
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('deleteWordRight - issue #3882')
     */
    function testDeleteWordRightIssue3882() {
        withTestCodeEditor([
            'public void Add( int x,',
            '                 int y )'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 24));
            deleteWordRight(editor); assertEquals(model.getLineContent(1), 'public void Add( int x,int y )', '001');
        });
    }

    /**
     * test('deleteWordStartRight - issue #3882')
     */
    function testDeleteWordStartRightIssue3882() {
        withTestCodeEditor([
            'public void Add( int x,',
            '                 int y )'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 24));
            deleteWordStartRight(editor); assertEquals(model.getLineContent(1), 'public void Add( int x,int y )', '001');
        });
    }

    /**
     * test('deleteWordEndRight - issue #3882')
     */
    function testDeleteWordEndRightIssue3882() {
        withTestCodeEditor([
            'public void Add( int x,',
            '                 int y )'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 24));
            deleteWordEndRight(editor); assertEquals(model.getLineContent(1), 'public void Add( int x,int y )', '001');
        });
    }

    /**
     * test('deleteWordStartRight')
     */
    function testDeleteWordStartRight() {
        final EXPECTED = '   |/* |Just |some |text |a|+= |3 |+|5|-|3 |*/  |';
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> deleteWordStartRight(ed),
            ed -> new Position(1, text.length - ed.getValue().length + 1),
            ed -> ed.getValue().length == 0
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('deleteWordEndRight')
     */
    function testDeleteWordEndRight() {
        final EXPECTED = '   /*| Just| some| text| a|+=| 3| +|5|-|3| */|  |';
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> deleteWordEndRight(ed),
            ed -> new Position(1, text.length - ed.getValue().length + 1),
            ed -> ed.getValue().length == 0
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(actual, EXPECTED);
    }

    /**
     * test('deleteWordRight - issue #3882 (1): Ctrl+Delete removing entire line when used at the end of line')
     */
    function testDeleteWordRightIssue38821CtrlDeleteRemovingEntireLineWhenUsedAtTheEndOfLine() {
        withTestCodeEditor([
            'A line with text.',
            '   And another one'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 18));
            deleteWordRight(editor); assertEquals(model.getLineContent(1), 'A line with text.And another one', '001');
        });
    }

    /**
     * test('deleteWordLeft - issue #3882 (2): Ctrl+Delete removing entire line when used at the end of line')
     */
    function testDeleteWordLeftIssue38822CtrlDeleteRemovingEntireLineWhenUsedAtTheEndOfLine() {
        withTestCodeEditor([
            'A line with text.',
            '   And another one'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(2, 1));
            deleteWordLeft(editor); assertEquals(model.getLineContent(1), 'A line with text.   And another one', '001');
        });
    }

    /**
     * test('deleteWordLeft - issue #91855: Matching (quote, bracket, paren) doesn\'t get deleted when hitting Ctrl+Backspace')
     */
    function testDeleteWordLeftIssue91855MatchingQuoteBracketParenDoesnTGetDeletedWhenHittingCtrlBackspace() {
        final languageId = 'myTestMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            autoClosingPairs: [
                { open: '\"', close: '\"' }
            ]
        }));

        final model = TestTextModel.instantiateTextModel(instantiationService, 'a ""', languageId);
        final editor = new TestCodeEditor(instantiationService, model, { autoClosingDelete: 'always' });
        disposables.add(Lifecycle.toDisposable(() -> { editor.dispose(); model.dispose(); }));

        editor.setPosition(new Position(1, 4));
        deleteWordLeft(editor);
        assertEquals(model.getLineContent(1), 'a ');
    }

    /**
     * test('deleteInsideWord - empty line')
     */
    function testDeleteInsideWordEmptyLine() {
        withTestCodeEditor([
            'Line1',
            '',
            'Line2'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(2, 1));
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'Line1\nLine2');
        });
    }

    /**
     * test('deleteInsideWord - in whitespace 1')
     */
    function testDeleteInsideWordInWhitespace1() {
        withTestCodeEditor([
            'Just  some text.'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 6));
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'Justsome text.');
        });
    }

    /**
     * test('deleteInsideWord - in whitespace 2')
     */
    function testDeleteInsideWordInWhitespace2() {
        withTestCodeEditor([
            'Just     some text.'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 6));
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'Justsome text.');
        });
    }

    /**
     * test('deleteInsideWord - in whitespace 3')
     */
    function testDeleteInsideWordInWhitespace3() {
        withTestCodeEditor([
            'Just     "some text.'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 6));
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'Just"some text.');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '"some text.');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'some text.');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'text.');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '.');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
        });
    }

    /**
     * test('deleteInsideWord - in non-words')
     */
    function testDeleteInsideWordInNonWords() {
        withTestCodeEditor([
            'x=3+4+5+6'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 7));
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'x=3+45+6');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'x=3++6');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'x=36');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'x=');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'x');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
        });
    }

    /**
     * test('deleteInsideWord - in words 1')
     */
    function testDeleteInsideWordInWords1() {
        withTestCodeEditor([
            'This is interesting'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 7));
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'This interesting');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'This');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
        });
    }

    /**
     * test('deleteInsideWord - in words 2')
     */
    function testDeleteInsideWordInWords2() {
        withTestCodeEditor([
            'This  is  interesting'
        ], {}, (editor, _) -> {
            final model = editor.getModel();
            editor.setPosition(new Position(1, 7));
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'This  interesting');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), 'This');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
            deleteInsideWord(editor);
            assertEquals(model.getValue(), '');
        });
    }

    // Cityscape addition: the words of a line without `Intl.Segmenter`

    /**
     * Native targets segment with UAX #29 (DEVIATIONS.md, "Word
     * segmentation"): katakana runs stay together, each hiragana and
     * ideograph is a word (ICU's dictionary gives これ|は|テスト|です).
     */
    function testCityscapeRecognizeWordsUax29() {
        #if !js
        final EXPECTED = [
            '/*| こ|れ|は|テスト|で|す|/*|',
        ].join('\n');
        final text = deserializePipePositions(EXPECTED).text;
        final actualStops = repeatedActionAndExtractPositions(
            text,
            new Position(1, 1),
            ed -> cursorWordRight(ed),
            ed -> ed.getPosition(),
            ed -> ed.getPosition().equals(new Position(1, 14)),
            {
                wordSegmenterLocales: 'ja'
            }
        );
        final actual = serializePipePositions(text, actualStops);
        assertDeepEquals(EXPECTED, actual);
        #end
    }

}
