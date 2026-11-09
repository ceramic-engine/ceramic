// Ported from vscode src/vs/editor/test/common/model/model.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - EditorModelModelTest
// - EditorModelModelLineSeparatorsTest
// - EditorModelWordsTest

import cityscape.common.TextModelEvents;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

// --------- utils

private class ModelTestLines {

    public static final LINE1 = 'My First Line';
    public static final LINE2 = '\t\tMy Second Line';
    public static final LINE3 = '    Third Line';
    public static final LINE4 = '';
    public static final LINE5 = '1';

}

/**
 * suite('Editor Model - Model')
 */
class EditorModelModelTest extends TestCase {

    var thisModel:TextModel;

    override function setup():Void {
        final text =
            ModelTestLines.LINE1 + '\r\n' +
            ModelTestLines.LINE2 + '\n' +
            ModelTestLines.LINE3 + '\n' +
            ModelTestLines.LINE4 + '\r\n' +
            ModelTestLines.LINE5;
        thisModel = createTextModel(text);
    }

    override function teardown():Void {
        thisModel.dispose();
    }

    // --------- insert text


    function testModelGetValue() {
        assertEquals(thisModel.getValue(), 'My First Line\n\t\tMy Second Line\n    Third Line\n\n1');
    }

    function testModelInsertEmptyText() {
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), '')]);
        assertEquals(thisModel.getLineCount(), 5);
        assertEquals(thisModel.getLineContent(1), 'My First Line');
    }

    function testModelInsertTextWithoutNewline1() {
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'foo ')]);
        assertEquals(thisModel.getLineCount(), 5);
        assertEquals(thisModel.getLineContent(1), 'foo My First Line');
    }

    function testModelInsertTextWithoutNewline2() {
        thisModel.applyEdits([EditOperation.insert(new Position(1, 3), ' foo')]);
        assertEquals(thisModel.getLineCount(), 5);
        assertEquals(thisModel.getLineContent(1), 'My foo First Line');
    }

    function testModelInsertTextWithOneNewline() {
        thisModel.applyEdits([EditOperation.insert(new Position(1, 3), ' new line\nNo longer')]);
        assertEquals(thisModel.getLineCount(), 6);
        assertEquals(thisModel.getLineContent(1), 'My new line');
        assertEquals(thisModel.getLineContent(2), 'No longer First Line');
    }

    function testModelInsertTextWithTwoNewlines() {
        thisModel.applyEdits([EditOperation.insert(new Position(1, 3), ' new line\nOne more line in the middle\nNo longer')]);
        assertEquals(thisModel.getLineCount(), 7);
        assertEquals(thisModel.getLineContent(1), 'My new line');
        assertEquals(thisModel.getLineContent(2), 'One more line in the middle');
        assertEquals(thisModel.getLineContent(3), 'No longer First Line');
    }

    function testModelInsertTextWithManyNewlines() {
        thisModel.applyEdits([EditOperation.insert(new Position(1, 3), '\n\n\n\n')]);
        assertEquals(thisModel.getLineCount(), 9);
        assertEquals(thisModel.getLineContent(1), 'My');
        assertEquals(thisModel.getLineContent(2), '');
        assertEquals(thisModel.getLineContent(3), '');
        assertEquals(thisModel.getLineContent(4), '');
        assertEquals(thisModel.getLineContent(5), ' First Line');
    }


    // --------- insert text eventing

    function testModelInsertEmptyTextDoesNotTriggerEventing() {
        final disposable = thisModel.onDidChangeContentOrInjectedText((e) -> {
            assertTrue(false, 'was not expecting event');
        });
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), '')]);
        disposable.dispose();
    }

    function testModelInsertTextWithoutNewlineEventing() {
        var e:Null<ModelRawContentChangedEvent> = null;
        final disposable = thisModel.onDidChangeContentOrInjectedText((_e) -> {
            if (e != null || !Std.isOfType(_e, InternalModelContentChangeEvent)) {
                fail('Unexpected assertion error');
                return;
            }
            e = (cast _e : InternalModelContentChangeEvent).rawContentChangedEvent;
        });
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'foo ')]);
        assertDeepEquals(e, new ModelRawContentChangedEvent(
            [
                new ModelRawLineChanged(1, 'foo My First Line', null)
            ],
            2,
            false,
            false
        ));
        disposable.dispose();
    }

    function testModelInsertTextWithOneNewlineEventing() {
        var e:Null<ModelRawContentChangedEvent> = null;
        final disposable = thisModel.onDidChangeContentOrInjectedText((_e) -> {
            if (e != null || !Std.isOfType(_e, InternalModelContentChangeEvent)) {
                fail('Unexpected assertion error');
                return;
            }
            e = (cast _e : InternalModelContentChangeEvent).rawContentChangedEvent;
        });
        thisModel.applyEdits([EditOperation.insert(new Position(1, 3), ' new line\nNo longer')]);
        assertDeepEquals(e, new ModelRawContentChangedEvent(
            [
                new ModelRawLineChanged(1, 'My new line', null),
                new ModelRawLinesInserted(2, 2, ['No longer First Line'], [null]),
            ],
            2,
            false,
            false
        ));
        disposable.dispose();
    }


    // --------- delete text

    function testModelDeleteEmptyText() {
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 1))]);
        assertEquals(thisModel.getLineCount(), 5);
        assertEquals(thisModel.getLineContent(1), 'My First Line');
    }

    function testModelDeleteTextFromOneLine() {
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 2))]);
        assertEquals(thisModel.getLineCount(), 5);
        assertEquals(thisModel.getLineContent(1), 'y First Line');
    }

    function testModelDeleteTextFromOneLine2() {
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'a')]);
        assertEquals(thisModel.getLineContent(1), 'aMy First Line');

        thisModel.applyEdits([EditOperation.delete(new Range(1, 2, 1, 4))]);
        assertEquals(thisModel.getLineCount(), 5);
        assertEquals(thisModel.getLineContent(1), 'a First Line');
    }

    function testModelDeleteAllTextFromALine() {
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 14))]);
        assertEquals(thisModel.getLineCount(), 5);
        assertEquals(thisModel.getLineContent(1), '');
    }

    function testModelDeleteTextFromTwoLines() {
        thisModel.applyEdits([EditOperation.delete(new Range(1, 4, 2, 6))]);
        assertEquals(thisModel.getLineCount(), 4);
        assertEquals(thisModel.getLineContent(1), 'My Second Line');
    }

    function testModelDeleteTextFromManyLines() {
        thisModel.applyEdits([EditOperation.delete(new Range(1, 4, 3, 5))]);
        assertEquals(thisModel.getLineCount(), 3);
        assertEquals(thisModel.getLineContent(1), 'My Third Line');
    }

    function testModelDeleteEverything() {
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 5, 2))]);
        assertEquals(thisModel.getLineCount(), 1);
        assertEquals(thisModel.getLineContent(1), '');
    }

    // --------- delete text eventing

    function testModelDeleteEmptyTextDoesNotTriggerEventing() {
        final disposable = thisModel.onDidChangeContentOrInjectedText((e) -> {
            assertTrue(false, 'was not expecting event');
        });
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 1))]);
        disposable.dispose();
    }

    function testModelDeleteTextFromOneLineEventing() {
        var e:Null<ModelRawContentChangedEvent> = null;
        final disposable = thisModel.onDidChangeContentOrInjectedText((_e) -> {
            if (e != null || !Std.isOfType(_e, InternalModelContentChangeEvent)) {
                fail('Unexpected assertion error');
                return;
            }
            e = (cast _e : InternalModelContentChangeEvent).rawContentChangedEvent;
        });
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 2))]);
        assertDeepEquals(e, new ModelRawContentChangedEvent(
            [
                new ModelRawLineChanged(1, 'y First Line', null),
            ],
            2,
            false,
            false
        ));
        disposable.dispose();
    }

    function testModelDeleteAllTextFromALineEventing() {
        var e:Null<ModelRawContentChangedEvent> = null;
        final disposable = thisModel.onDidChangeContentOrInjectedText((_e) -> {
            if (e != null || !Std.isOfType(_e, InternalModelContentChangeEvent)) {
                fail('Unexpected assertion error');
                return;
            }
            e = (cast _e : InternalModelContentChangeEvent).rawContentChangedEvent;
        });
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 14))]);
        assertDeepEquals(e, new ModelRawContentChangedEvent(
            [
                new ModelRawLineChanged(1, '', null),
            ],
            2,
            false,
            false
        ));
        disposable.dispose();
    }

    function testModelDeleteTextFromTwoLinesEventing() {
        var e:Null<ModelRawContentChangedEvent> = null;
        final disposable = thisModel.onDidChangeContentOrInjectedText((_e) -> {
            if (e != null || !Std.isOfType(_e, InternalModelContentChangeEvent)) {
                fail('Unexpected assertion error');
                return;
            }
            e = (cast _e : InternalModelContentChangeEvent).rawContentChangedEvent;
        });
        thisModel.applyEdits([EditOperation.delete(new Range(1, 4, 2, 6))]);
        assertDeepEquals(e, new ModelRawContentChangedEvent(
            [
                new ModelRawLineChanged(1, 'My Second Line', null),
                new ModelRawLinesDeleted(2, 2),
            ],
            2,
            false,
            false
        ));
        disposable.dispose();
    }

    function testModelDeleteTextFromManyLinesEventing() {
        var e:Null<ModelRawContentChangedEvent> = null;
        final disposable = thisModel.onDidChangeContentOrInjectedText((_e) -> {
            if (e != null || !Std.isOfType(_e, InternalModelContentChangeEvent)) {
                fail('Unexpected assertion error');
                return;
            }
            e = (cast _e : InternalModelContentChangeEvent).rawContentChangedEvent;
        });
        thisModel.applyEdits([EditOperation.delete(new Range(1, 4, 3, 5))]);
        assertDeepEquals(e, new ModelRawContentChangedEvent(
            [
                new ModelRawLineChanged(1, 'My Third Line', null),
                new ModelRawLinesDeleted(2, 3),
            ],
            2,
            false,
            false
        ));
        disposable.dispose();
    }

    // --------- getValueInRange

    function testGetValueInRange() {
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 1, 1)), '');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 1, 2)), 'M');
        assertEquals(thisModel.getValueInRange(new Range(1, 2, 1, 3)), 'y');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 1, 14)), 'My First Line');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 2, 1)), 'My First Line\n');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 2, 2)), 'My First Line\n\t');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 2, 3)), 'My First Line\n\t\t');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 2, 17)), 'My First Line\n\t\tMy Second Line');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 3, 1)), 'My First Line\n\t\tMy Second Line\n');
        assertEquals(thisModel.getValueInRange(new Range(1, 1, 4, 1)), 'My First Line\n\t\tMy Second Line\n    Third Line\n');
    }

    // --------- getValueLengthInRange

    function testGetValueLengthInRange() {
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 1, 1)), ''.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 1, 2)), 'M'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 2, 1, 3)), 'y'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 1, 14)), 'My First Line'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 2, 1)), 'My First Line\n'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 2, 2)), 'My First Line\n\t'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 2, 3)), 'My First Line\n\t\t'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 2, 17)), 'My First Line\n\t\tMy Second Line'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 3, 1)), 'My First Line\n\t\tMy Second Line\n'.length);
        assertEquals(thisModel.getValueLengthInRange(new Range(1, 1, 4, 1)), 'My First Line\n\t\tMy Second Line\n    Third Line\n'.length);
    }

    // --------- setValue
    function testSetValueEventing() {
        var e:Null<ModelRawContentChangedEvent> = null;
        final disposable = thisModel.onDidChangeContentOrInjectedText((_e) -> {
            if (e != null || !Std.isOfType(_e, InternalModelContentChangeEvent)) {
                fail('Unexpected assertion error');
                return;
            }
            e = (cast _e : InternalModelContentChangeEvent).rawContentChangedEvent;
        });
        thisModel.setValue('new value');
        assertDeepEquals(e, new ModelRawContentChangedEvent(
            [
                new ModelRawFlush()
            ],
            2,
            false,
            false
        ));
        disposable.dispose();
    }

    function testIssue46342MaintainEditOperationOrderInApplyEdits() {
        final res = thisModel.applyEdits([
            { range: new Range(2, 1, 2, 1), text: 'a' },
            { range: new Range(1, 1, 1, 1), text: 'b' },
        ], true);

        assertDeepEquals(res[0].range, new Range(2, 1, 2, 2));
        assertDeepEquals(res[1].range, new Range(1, 1, 1, 2));
    }

}

// --------- Special Unicode LINE SEPARATOR character

/**
 * suite('Editor Model - Model Line Separators')
 */
class EditorModelModelLineSeparatorsTest extends TestCase {

    var thisModel:TextModel;

    override function setup():Void {
        final text =
            ModelTestLines.LINE1 + '\u{2028}' +
            ModelTestLines.LINE2 + '\n' +
            ModelTestLines.LINE3 + '\u{2028}' +
            ModelTestLines.LINE4 + '\r\n' +
            ModelTestLines.LINE5;
        thisModel = createTextModel(text);
    }

    override function teardown():Void {
        thisModel.dispose();
    }

    function testModelGetValue() {
        assertEquals(thisModel.getValue(), 'My First Line\u{2028}\t\tMy Second Line\n    Third Line\u{2028}\n1');
    }

    function testModelLines() {
        assertEquals(thisModel.getLineCount(), 3);
    }

    function testBug13333ModelShouldLineBreakOnLonelyCRToo() {
        final model = createTextModel('Hello\rWorld!\r\nAnother line');
        assertEquals(model.getLineCount(), 3);
        assertEquals(model.getValue(), 'Hello\r\nWorld!\r\nAnother line');
        model.dispose();
    }

}

// --------- Words

/**
 * suite('Editor Model - Words')
 *
 * Not ported: test('getWordAtPosition at embedded language boundaries'): needs registered languages and a tokenization support
 * (the OuterMode/InnerMode helpers of the suite, not ported either).
 * Not ported: test('issue #61296: VS code freezes when editing CSS file with emoji'): needs a registered language with a
 * word pattern from a language configuration.
 */
class EditorModelWordsTest extends TestCase {

    var disposables:Array<TextModel> = [];

    override function setup():Void {
        disposables = [];
    }

    override function teardown():Void {
        for (d in disposables) {
            d.dispose();
        }
        disposables = [];
    }

    function testGetWordAtPosition() {
        final text = ['This text has some  words. '];
        final thisModel = createTextModel(text.join('\n'));
        disposables.push(thisModel);

        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 1)), {word: 'This', startColumn: 1, endColumn: 5});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 2)), {word: 'This', startColumn: 1, endColumn: 5});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 4)), {word: 'This', startColumn: 1, endColumn: 5});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 5)), {word: 'This', startColumn: 1, endColumn: 5});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 6)), {word: 'text', startColumn: 6, endColumn: 10});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 19)), {word: 'some', startColumn: 15, endColumn: 19});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 20)), null);
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 21)), {word: 'words', startColumn: 21, endColumn: 26});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 26)), {word: 'words', startColumn: 21, endColumn: 26});
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 27)), null);
        assertDeepEquals(thisModel.getWordAtPosition(new Position(1, 28)), null);
    }

}
