// Ported from vscode src/vs/editor/test/common/model/editableTextModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.Model;
import cityscape.common.TextModelEvents;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Range;
import testing.TestCase;
import tests.TestTextModel.createTextModel;
import tests.model.EditableTextModelTestUtils.MirrorTextModel;
import tests.model.EditableTextModelTestUtils.assertSyncedModels;
import tests.model.EditableTextModelTestUtils.testApplyEditsWithSyncedModels;

// Classes of this module:
//   EditorModelEditableTextModelApplyEditsUpdatesMightContainRTLTest
//   EditorModelEditableTextModelApplyEditsUpdatesMightContainNonBasicASCIITest
//   EditorModelEditableTextModelApplyEditsTest

/** suite('EditorModel - EditableTextModel.applyEdits updates mightContainRTL') */
class EditorModelEditableTextModelApplyEditsUpdatesMightContainRTLTest extends TestCase {

    function _testApplyEdits(original:Array<String>, edits:Array<ISingleEditOperation>, before:Bool, after:Bool):Void {
        final model = createTextModel(original.join('\n'));
        model.setEOL(EndOfLineSequence.LF);

        assertEquals(model.mightContainRTL(), before);

        model.applyEdits(cast edits);
        assertEquals(model.mightContainRTL(), after);
        model.dispose();
    }

    static function editOp(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, text:Array<String>):ISingleEditOperation {
        return {
            range: new Range(startLineNumber, startColumn, endLineNumber, endColumn),
            text: text.join('\n')
        };
    }

    // test('start with RTL, insert LTR')
    function testStartWithRTLInsertLTR() {
        _testApplyEdits(['Hello,\nזוהי עובדה מבוססת שדעתו'], [editOp(1, 1, 1, 1, ['hello'])], true, true);
    }

    // test('start with RTL, delete RTL')
    function testStartWithRTLDeleteRTL() {
        _testApplyEdits(['Hello,\nזוהי עובדה מבוססת שדעתו'], [editOp(1, 1, 10, 10, [''])], true, true);
    }

    // test('start with RTL, insert RTL')
    function testStartWithRTLInsertRTL() {
        _testApplyEdits(['Hello,\nזוהי עובדה מבוססת שדעתו'], [editOp(1, 1, 1, 1, ['هناك حقيقة مثبتة منذ زمن طويل'])], true, true);
    }

    // test('start with LTR, insert LTR')
    function testStartWithLTRInsertLTR() {
        _testApplyEdits(['Hello,\nworld!'], [editOp(1, 1, 1, 1, ['hello'])], false, false);
    }

    // test('start with LTR, insert RTL 1')
    function testStartWithLTRInsertRTL1() {
        _testApplyEdits(['Hello,\nworld!'], [editOp(1, 1, 1, 1, ['هناك حقيقة مثبتة منذ زمن طويل'])], false, true);
    }

    // test('start with LTR, insert RTL 2')
    function testStartWithLTRInsertRTL2() {
        _testApplyEdits(['Hello,\nworld!'], [editOp(1, 1, 1, 1, ['זוהי עובדה מבוססת שדעתו'])], false, true);
    }
}

/** suite('EditorModel - EditableTextModel.applyEdits updates mightContainNonBasicASCII') */
class EditorModelEditableTextModelApplyEditsUpdatesMightContainNonBasicASCIITest extends TestCase {

    function _testApplyEdits(original:Array<String>, edits:Array<ISingleEditOperation>, before:Bool, after:Bool):Void {
        final model = createTextModel(original.join('\n'));
        model.setEOL(EndOfLineSequence.LF);

        assertEquals(model.mightContainNonBasicASCII(), before);

        model.applyEdits(cast edits);
        assertEquals(model.mightContainNonBasicASCII(), after);
        model.dispose();
    }

    static function editOp(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, text:Array<String>):ISingleEditOperation {
        return {
            range: new Range(startLineNumber, startColumn, endLineNumber, endColumn),
            text: text.join('\n')
        };
    }

    // test('start with NON-ASCII, insert ASCII')
    function testStartWithNONASCIIInsertASCII() {
        _testApplyEdits(['Hello,\nZürich'], [editOp(1, 1, 1, 1, ['hello', 'second line'])], true, true);
    }

    // test('start with NON-ASCII, delete NON-ASCII')
    function testStartWithNONASCIIDeleteNONASCII() {
        _testApplyEdits(['Hello,\nZürich'], [editOp(1, 1, 10, 10, [''])], true, true);
    }

    // test('start with NON-ASCII, insert NON-ASCII')
    function testStartWithNONASCIIInsertNONASCII() {
        _testApplyEdits(['Hello,\nZürich'], [editOp(1, 1, 1, 1, ['Zürich'])], true, true);
    }

    // test('start with ASCII, insert ASCII')
    function testStartWithASCIIInsertASCII() {
        _testApplyEdits(['Hello,\nworld!'], [editOp(1, 1, 1, 1, ['hello', 'second line'])], false, false);
    }

    // test('start with ASCII, insert NON-ASCII')
    function testStartWithASCIIInsertNONASCII() {
        _testApplyEdits(['Hello,\nworld!'], [editOp(1, 1, 1, 1, ['Zürich', 'Zürich'])], false, true);
    }
}

/** suite('EditorModel - EditableTextModel.applyEdits') */
class EditorModelEditableTextModelApplyEditsTest extends TestCase {

    static function editOp(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, text:Array<String>):ISingleEditOperation {
        return {
            range: new Range(startLineNumber, startColumn, endLineNumber, endColumn),
            text: text.join('\n'),
            forceMoveMarkers: false
        };
    }

    function _testApplyEditsFails(original:Array<String>, edits:Array<ISingleEditOperation>):Void {
        final model = createTextModel(original.join('\n'));

        var hasThrown = false;
        try {
            model.applyEdits(cast edits);
        }
        catch (err:Dynamic) {
            hasThrown = true;
        }
        assertTrue(hasThrown, 'expected model.applyEdits to fail.');

        model.dispose();
    }

    // test('high-low surrogates 1')
    function testHighLowSurrogates1() {
        testApplyEditsWithSyncedModels(this,
            [
                '📚some',
                'very nice',
                'text'
            ],
            [
                editOp(1, 2, 1, 2, ['a'])
            ],
            [
                'a📚some',
                'very nice',
                'text'
            ],
            /*inputEditsAreInvalid*/true
        );
    }

    // test('high-low surrogates 2')
    function testHighLowSurrogates2() {
        testApplyEditsWithSyncedModels(this,
            [
                '📚some',
                'very nice',
                'text'
            ],
            [
                editOp(1, 2, 1, 3, ['a'])
            ],
            [
                'asome',
                'very nice',
                'text'
            ],
            /*inputEditsAreInvalid*/true
        );
    }

    // test('high-low surrogates 3')
    function testHighLowSurrogates3() {
        testApplyEditsWithSyncedModels(this,
            [
                '📚some',
                'very nice',
                'text'
            ],
            [
                editOp(1, 1, 1, 2, ['a'])
            ],
            [
                'asome',
                'very nice',
                'text'
            ],
            /*inputEditsAreInvalid*/true
        );
    }

    // test('high-low surrogates 4')
    function testHighLowSurrogates4() {
        testApplyEditsWithSyncedModels(this,
            [
                '📚some',
                'very nice',
                'text'
            ],
            [
                editOp(1, 1, 1, 3, ['a'])
            ],
            [
                'asome',
                'very nice',
                'text'
            ],
            /*inputEditsAreInvalid*/true
        );
    }

    // test('Bug 19872: Undo is funky')
    function testBug19872UndoIsFunky() {
        testApplyEditsWithSyncedModels(this,
            [
                'something',
                ' A',
                '',
                ' B',
                'something else'
            ],
            [
                editOp(2, 1, 2, 2, ['']),
                editOp(3, 1, 4, 2, [''])
            ],
            [
                'something',
                'A',
                'B',
                'something else'
            ]
        );
    }

    // test('Bug 19872: Undo is funky (2)')
    function testBug19872UndoIsFunky2() {
        testApplyEditsWithSyncedModels(this,
            [
                'something',
                'A',
                'B',
                'something else'
            ],
            [
                editOp(2, 1, 2, 1, [' ']),
                editOp(3, 1, 3, 1, ['', ' '])
            ],
            [
                'something',
                ' A',
                '',
                ' B',
                'something else'
            ]
        );
    }

    // test('insert empty text')
    function testInsertEmptyText() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 1, 1, [''])
            ],
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('last op is no-op')
    function testLastOpIsNoOp() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 1, 2, ['']),
                editOp(4, 1, 4, 1, [''])
            ],
            [
                'y First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('insert text without newline 1')
    function testInsertTextWithoutNewline1() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 1, 1, ['foo '])
            ],
            [
                'foo My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('insert text without newline 2')
    function testInsertTextWithoutNewline2() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 3, 1, 3, [' foo'])
            ],
            [
                'My foo First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('insert one newline')
    function testInsertOneNewline() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 4, 1, 4, ['', ''])
            ],
            [
                'My ',
                'First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('insert text with one newline')
    function testInsertTextWithOneNewline() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 3, 1, 3, [' new line', 'No longer'])
            ],
            [
                'My new line',
                'No longer First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('insert text with two newlines')
    function testInsertTextWithTwoNewlines() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 3, 1, 3, [' new line', 'One more line in the middle', 'No longer'])
            ],
            [
                'My new line',
                'One more line in the middle',
                'No longer First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('insert text with many newlines')
    function testInsertTextWithManyNewlines() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 3, 1, 3, ['', '', '', '', ''])
            ],
            [
                'My',
                '',
                '',
                '',
                ' First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('insert multiple newlines')
    function testInsertMultipleNewlines() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 3, 1, 3, ['', '', '', '', '']),
                editOp(3, 15, 3, 15, ['a', 'b'])
            ],
            [
                'My',
                '',
                '',
                '',
                ' First Line',
                '\t\tMy Second Line',
                '    Third Linea',
                'b',
                '',
                '1'
            ]
        );
    }

    // test('delete empty text')
    function testDeleteEmptyText() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 1, 1, [''])
            ],
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('delete text from one line')
    function testDeleteTextFromOneLine() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 1, 2, [''])
            ],
            [
                'y First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('delete text from one line 2')
    function testDeleteTextFromOneLine2() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 1, 3, ['a'])
            ],
            [
                'a First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('delete all text from a line')
    function testDeleteAllTextFromALine() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 1, 14, [''])
            ],
            [
                '',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('delete text from two lines')
    function testDeleteTextFromTwoLines() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 4, 2, 6, [''])
            ],
            [
                'My Second Line',
                '    Third Line',
                '',
                '1'
            ]
        );
    }

    // test('delete text from many lines')
    function testDeleteTextFromManyLines() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 4, 3, 5, [''])
            ],
            [
                'My Third Line',
                '',
                '1'
            ]
        );
    }

    // test('delete everything')
    function testDeleteEverything() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ],
            [
                editOp(1, 1, 5, 2, [''])
            ],
            [
                ''
            ]
        );
    }

    // test('two unrelated edits')
    function testTwoUnrelatedEdits() {
        testApplyEditsWithSyncedModels(this,
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            [
                editOp(2, 1, 2, 3, ['\t']),
                editOp(3, 1, 3, 5, [''])
            ],
            [
                'My First Line',
                '\tMy Second Line',
                'Third Line',
                '',
                '123'
            ]
        );
    }

    // test('two edits on one line')
    function testTwoEditsOnOneLine() {
        testApplyEditsWithSyncedModels(this,
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            [
                editOp(5, 3, 5, 7, ['']),
                editOp(5, 12, 5, 16, [''])
            ],
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\tfifth\t\t'
            ]
        );
    }

    // test('many edits')
    function testManyEdits() {
        testApplyEditsWithSyncedModels(this,
            [
                '{"x" : 1}'
            ],
            [
                editOp(1, 2, 1, 2, ['\n  ']),
                editOp(1, 5, 1, 6, ['']),
                editOp(1, 9, 1, 9, ['\n'])
            ],
            [
                '{',
                '  "x": 1',
                '}'
            ]
        );
    }

    // test('many edits reversed')
    function testManyEditsReversed() {
        testApplyEditsWithSyncedModels(this,
            [
                '{',
                '  "x": 1',
                '}'
            ],
            [
                editOp(1, 2, 2, 3, ['']),
                editOp(2, 6, 2, 6, [' ']),
                editOp(2, 9, 3, 1, [''])
            ],
            [
                '{"x" : 1}'
            ]
        );
    }

    // test('replacing newlines 1')
    function testReplacingNewlines1() {
        testApplyEditsWithSyncedModels(this,
            [
                '{',
                '"a": true,',
                '',
                '"b": true',
                '}'
            ],
            [
                editOp(1, 2, 2, 1, ['', '\t']),
                editOp(2, 11, 4, 1, ['', '\t'])
            ],
            [
                '{',
                '\t"a": true,',
                '\t"b": true',
                '}'
            ]
        );
    }

    // test('replacing newlines 2')
    function testReplacingNewlines2() {
        testApplyEditsWithSyncedModels(this,
            [
                'some text',
                'some more text',
                'now comes an empty line',
                '',
                'after empty line',
                'and the last line'
            ],
            [
                editOp(1, 5, 3, 1, [' text', 'some more text', 'some more text']),
                editOp(3, 2, 4, 1, ['o more lines', 'asd', 'asd', 'asd']),
                editOp(5, 1, 5, 6, ['zzzzzzzz']),
                editOp(5, 11, 6, 16, ['1', '2', '3', '4'])
            ],
            [
                'some text',
                'some more text',
                'some more textno more lines',
                'asd',
                'asd',
                'asd',
                'zzzzzzzz empt1',
                '2',
                '3',
                '4ne'
            ]
        );
    }

    // test('advanced 1')
    function testAdvanced1() {
        testApplyEditsWithSyncedModels(this,
            [
                ' {       "d": [',
                '             null',
                '        ] /*comment*/',
                '        ,"e": /*comment*/ [null] }',
            ],
            [
                editOp(1, 1, 1, 2, ['']),
                editOp(1, 3, 1, 10, ['', '  ']),
                editOp(1, 16, 2, 14, ['', '    ']),
                editOp(2, 18, 3, 9, ['', '  ']),
                editOp(3, 22, 4, 9, ['']),
                editOp(4, 10, 4, 10, ['', '  ']),
                editOp(4, 28, 4, 28, ['', '    ']),
                editOp(4, 32, 4, 32, ['', '  ']),
                editOp(4, 33, 4, 34, ['', ''])
            ],
            [
                '{',
                '  "d": [',
                '    null',
                '  ] /*comment*/,',
                '  "e": /*comment*/ [',
                '    null',
                '  ]',
                '}',
            ]
        );
    }

    // test('advanced simplified')
    function testAdvancedSimplified() {
        testApplyEditsWithSyncedModels(this,
            [
                '   abc',
                ' ,def'
            ],
            [
                editOp(1, 1, 1, 4, ['']),
                editOp(1, 7, 2, 2, ['']),
                editOp(2, 3, 2, 3, ['', ''])
            ],
            [
                'abc,',
                'def'
            ]
        );
    }

    // test('issue #144')
    function testIssue144() {
        testApplyEditsWithSyncedModels(this,
            [
                'package caddy',
                '',
                'func main() {',
                '\tfmt.Println("Hello World! :)")',
                '}',
                ''
            ],
            [
                editOp(1, 1, 6, 1, [
                    'package caddy',
                    '',
                    'import "fmt"',
                    '',
                    'func main() {',
                    '\tfmt.Println("Hello World! :)")',
                    '}',
                    ''
                ])
            ],
            [
                'package caddy',
                '',
                'import "fmt"',
                '',
                'func main() {',
                '\tfmt.Println("Hello World! :)")',
                '}',
                ''
            ]
        );
    }

    // test('issue #2586 Replacing selected end-of-line with newline locks up the document')
    function testIssue2586ReplacingSelectedEndOfLineWithNewlineLocksUpTheDocument() {
        testApplyEditsWithSyncedModels(this,
            [
                'something',
                'interesting'
            ],
            [
                editOp(1, 10, 2, 1, ['', ''])
            ],
            [
                'something',
                'interesting'
            ]
        );
    }

    // test('issue #3980')
    function testIssue3980() {
        testApplyEditsWithSyncedModels(this,
            [
                'class A {',
                '    someProperty = false;',
                '    someMethod() {',
                '    this.someMethod();',
                '    }',
                '}',
            ],
            [
                editOp(1, 8, 1, 9, ['', '']),
                editOp(3, 17, 3, 18, ['', '']),
                editOp(3, 18, 3, 18, ['    ']),
                editOp(4, 5, 4, 5, ['    ']),
            ],
            [
                'class A',
                '{',
                '    someProperty = false;',
                '    someMethod()',
                '    {',
                '        this.someMethod();',
                '    }',
                '}',
            ]
        );
    }

    // test('touching edits: two inserts at the same position')
    function testTouchingEditsTwoInsertsAtTheSamePosition() {
        testApplyEditsWithSyncedModels(this,
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 1, ['a']),
                editOp(1, 1, 1, 1, ['b']),
            ],
            [
                'abhello world'
            ]
        );
    }

    // test('touching edits: insert and replace touching')
    function testTouchingEditsInsertAndReplaceTouching() {
        testApplyEditsWithSyncedModels(this,
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 1, ['b']),
                editOp(1, 1, 1, 3, ['ab']),
            ],
            [
                'babllo world'
            ]
        );
    }

    // test('overlapping edits: two overlapping replaces')
    function testOverlappingEditsTwoOverlappingReplaces() {
        _testApplyEditsFails(
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 2, ['b']),
                editOp(1, 1, 1, 3, ['ab']),
            ]
        );
    }

    // test('overlapping edits: two overlapping deletes')
    function testOverlappingEditsTwoOverlappingDeletes() {
        _testApplyEditsFails(
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 2, ['']),
                editOp(1, 1, 1, 3, ['']),
            ]
        );
    }

    // test('touching edits: two touching replaces')
    function testTouchingEditsTwoTouchingReplaces() {
        testApplyEditsWithSyncedModels(this,
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 2, ['H']),
                editOp(1, 2, 1, 3, ['E']),
            ],
            [
                'HEllo world'
            ]
        );
    }

    // test('touching edits: two touching deletes')
    function testTouchingEditsTwoTouchingDeletes() {
        testApplyEditsWithSyncedModels(this,
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 2, ['']),
                editOp(1, 2, 1, 3, ['']),
            ],
            [
                'llo world'
            ]
        );
    }

    // test('touching edits: insert and replace')
    function testTouchingEditsInsertAndReplace() {
        testApplyEditsWithSyncedModels(this,
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 1, ['H']),
                editOp(1, 1, 1, 3, ['e']),
            ],
            [
                'Hello world'
            ]
        );
    }

    // test('touching edits: replace and insert')
    function testTouchingEditsReplaceAndInsert() {
        testApplyEditsWithSyncedModels(this,
            [
                'hello world'
            ],
            [
                editOp(1, 1, 1, 3, ['H']),
                editOp(1, 3, 1, 3, ['e']),
            ],
            [
                'Hello world'
            ]
        );
    }

    // test('change while emitting events 1')
    function testChangeWhileEmittingEvents1() {
        var disposable:IDisposable = null;
        assertSyncedModels(this, 'Hello', (model, assertMirrorModels) -> {
            model.applyEdits([{
                range: new Range(1, 6, 1, 6),
                text: ' world!'
                // forceMoveMarkers: false
            }]);

            assertMirrorModels();

        }, (model) -> {
            var isFirstTime = true;
            disposable = model.onDidChangeContent((_) -> {
                if (!isFirstTime) {
                    return;
                }
                isFirstTime = false;

                model.applyEdits([{
                    range: new Range(1, 13, 1, 13),
                    text: ' How are you?'
                    // forceMoveMarkers: false
                }]);
            });
        });
        disposable.dispose();
    }

    // test('change while emitting events 2')
    function testChangeWhileEmittingEvents2() {
        var disposable:IDisposable = null;
        assertSyncedModels(this, 'Hello', (model, assertMirrorModels) -> {
            model.applyEdits([{
                range: new Range(1, 6, 1, 6),
                text: ' world!'
                // forceMoveMarkers: false
            }]);

            assertMirrorModels();

        }, (model) -> {
            var isFirstTime = true;
            disposable = model.onDidChangeContent((e:IModelContentChangedEvent) -> {
                if (!isFirstTime) {
                    return;
                }
                isFirstTime = false;

                model.applyEdits([{
                    range: new Range(1, 13, 1, 13),
                    text: ' How are you?'
                    // forceMoveMarkers: false
                }]);
            });
        });
        disposable.dispose();
    }

    // test('issue #1580: Changes in line endings are not correctly reflected in the extension host, leading to invalid offsets sent to external refactoring tools')
    function testIssue1580ChangesInLineEndingsAreNotCorrectlyReflectedInTheExtensionHostLeadingToInvalidOffsetsSentToExternalRefactoringTools() {
        final model = createTextModel('Hello\nWorld!');
        assertEquals(model.getEOL(), '\n');

        final mirrorModel2 = new MirrorTextModel(null, model.getLinesContent(), model.getEOL(), model.getVersionId());
        var mirrorModel2PrevVersionId = model.getVersionId();

        final disposable = model.onDidChangeContent((e:IModelContentChangedEvent) -> {
            final versionId = e.versionId;
            if (versionId < mirrorModel2PrevVersionId) {
                trace('Model version id did not advance between edits (2)');
            }
            mirrorModel2PrevVersionId = versionId;
            mirrorModel2.onEvents(e);
        });

        final assertMirrorModels = () -> {
            assertEquals(mirrorModel2.getText(), model.getValue(), 'mirror model 2 text OK');
            assertEquals(mirrorModel2.version, model.getVersionId(), 'mirror model 2 version OK');
        };

        model.setEOL(EndOfLineSequence.CRLF);
        assertMirrorModels();

        disposable.dispose();
        model.dispose();
        mirrorModel2.dispose();
    }

    // test('issue #47733: Undo mangles unicode characters')
    function testIssue47733UndoManglesUnicodeCharacters() {
        final model = createTextModel('\'👁\'');

        model.applyEdits([
            { range: new Range(1, 1, 1, 1), text: '"' },
            { range: new Range(1, 2, 1, 2), text: '"' },
        ]);

        assertEquals(model.getValue(EndOfLinePreference.LF), '"\'"👁\'');

        assertDeepEquals(model.validateRange(new Range(1, 3, 1, 4)), new Range(1, 3, 1, 4));

        model.applyEdits([
            { range: new Range(1, 1, 1, 2), text: null },
            { range: new Range(1, 3, 1, 4), text: null },
        ]);

        assertEquals(model.getValue(EndOfLinePreference.LF), '\'👁\'');

        model.dispose();
    }

    // test('issue #48741: Broken undo stack with move lines up with multiple cursors')
    function testIssue48741BrokenUndoStackWithMoveLinesUpWithMultipleCursors() {
        final model = createTextModel([
            'line1',
            'line2',
            'line3',
            '',
        ].join('\n'));

        final undoEdits = model.applyEdits([
            { range: new Range(4, 1, 4, 1), text: 'line3' },
            { range: new Range(3, 1, 3, 6), text: null },
            { range: new Range(2, 1, 3, 1), text: null },
            { range: new Range(3, 6, 3, 6), text: '\nline2' }
        ], true);

        model.applyEdits(cast undoEdits);

        assertDeepEquals(model.getValue(), 'line1\nline2\nline3\n');

        model.dispose();
    }
}
