// Ported from vscode src/vs/editor/test/common/model/textModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - TextModelDataFromStringTest
// - EditorModelTextModelTest
// - TextModelMightContainRTLTest
// - TextModelCreateSnapshotTest

import cityscape.Cityscape;
import cityscape.base.common.Strings;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

/**
 * suite('TextModelData.fromString')
 */
class TextModelDataFromStringTest extends TestCase {

    function _testTextModelDataFromString(text:String, expected:{EOL:String, lines:Array<String>, containsRTL:Bool, isBasicASCII:Bool}):Void {
        final created = TextModel.createTextBuffer(text, TextModel.DEFAULT_CREATION_OPTIONS.defaultEOL);
        final textBuffer = created.textBuffer;
        final disposable = created.disposable;
        final actual = {
            EOL: textBuffer.getEOL(),
            lines: textBuffer.getLinesContent(),
            containsRTL: textBuffer.mightContainRTL(),
            isBasicASCII: !textBuffer.mightContainNonBasicASCII()
        };
        assertDeepEquals(actual, expected);
        disposable.dispose();
    }

    function testOneLineText() {
        _testTextModelDataFromString('Hello world!', {
            EOL: '\n',
            lines: [
                'Hello world!'
            ],
            containsRTL: false,
            isBasicASCII: true
        });
    }

    function testMultilineText() {
        _testTextModelDataFromString('Hello,\r\ndear friend\nHow\rare\r\nyou?', {
            EOL: '\r\n',
            lines: [
                'Hello,',
                'dear friend',
                'How',
                'are',
                'you?'
            ],
            containsRTL: false,
            isBasicASCII: true
        });
    }

    function testNonBasicASCII1() {
        _testTextModelDataFromString('Hello,\nZürich', {
            EOL: '\n',
            lines: [
                'Hello,',
                'Zürich'
            ],
            containsRTL: false,
            isBasicASCII: false
        });
    }

    function testContainsRTL1() {
        _testTextModelDataFromString('Hello,\nזוהי עובדה מבוססת שדעתו', {
            EOL: '\n',
            lines: [
                'Hello,',
                'זוהי עובדה מבוססת שדעתו'
            ],
            containsRTL: true,
            isBasicASCII: false
        });
    }

    function testContainsRTL2() {
        _testTextModelDataFromString('Hello,\nهناك حقيقة مثبتة منذ زمن طويل', {
            EOL: '\n',
            lines: [
                'Hello,',
                'هناك حقيقة مثبتة منذ زمن طويل'
            ],
            containsRTL: true,
            isBasicASCII: false
        });
    }

}

/**
 * suite('Editor Model - TextModel')
 *
 * Not ported: test('validatePosition handle NaN.'): Position takes Int coordinates in Cityscape, NaN cannot be passed.
 * Not ported: test('issue #71480: validatePosition handle floats'): Position takes Int coordinates in Cityscape, floats cannot be passed.
 * Not ported: test('issue #71480: validateRange handle floats'): Range takes Int coordinates in Cityscape, floats cannot be passed.
 * Not ported: test('#50471. getValueInRange with invalid range'): Range takes Int coordinates in Cityscape, NaN cannot be passed.
 *
 * In test('validatePosition') and test('validatePosition around high-low surrogate pairs 1'), the assertions with
 * float, `Number.MIN_VALUE` and `Number.MAX_VALUE` coordinates are not ported for the same reason; the other
 * assertions are kept.
 */
class EditorModelTextModelTest extends TestCase {

    function _testGuessIndentation(defaultInsertSpaces:Bool, defaultTabSize:Int, expectedInsertSpaces:Bool, expectedTabSize:Int, text:Array<String>, ?msg:String):Void {
        final m = createTextModel(
            text.join('\n'),
            null,
            {
                tabSize: defaultTabSize,
                insertSpaces: defaultInsertSpaces,
                detectIndentation: true
            }
        );
        final r = m.getOptions();
        m.dispose();

        assertEquals(r.insertSpaces, expectedInsertSpaces, msg);
        assertEquals(r.tabSize, expectedTabSize, msg);
    }

    /**
     * `expectedTabSize` is null, an Int, or an array of one Int (`[number]`).
     */
    function assertGuess(expectedInsertSpaces:Null<Bool>, expectedTabSize:Any, text:Array<String>, ?msg:String):Void {
        if (expectedInsertSpaces == null) {
            // cannot guess insertSpaces
            if (expectedTabSize == null) {
                // cannot guess tabSize
                _testGuessIndentation(true, 13370, true, 13370, text, msg);
                _testGuessIndentation(false, 13371, false, 13371, text, msg);
            }
            else if (Std.isOfType(expectedTabSize, Int)) {
                // can guess tabSize
                final expectedTabSize:Int = cast expectedTabSize;
                _testGuessIndentation(true, 13370, true, expectedTabSize, text, msg);
                _testGuessIndentation(false, 13371, false, expectedTabSize, text, msg);
            }
            else {
                // can only guess tabSize when insertSpaces is true
                final expectedTabSize:Array<Int> = cast expectedTabSize;
                _testGuessIndentation(true, 13370, true, expectedTabSize[0], text, msg);
                _testGuessIndentation(false, 13371, false, 13371, text, msg);
            }
        }
        else {
            final expectedInsertSpaces:Bool = expectedInsertSpaces;
            // can guess insertSpaces
            if (expectedTabSize == null) {
                // cannot guess tabSize
                _testGuessIndentation(true, 13370, expectedInsertSpaces, 13370, text, msg);
                _testGuessIndentation(false, 13371, expectedInsertSpaces, 13371, text, msg);
            }
            else if (Std.isOfType(expectedTabSize, Int)) {
                // can guess tabSize
                final expectedTabSize:Int = cast expectedTabSize;
                _testGuessIndentation(true, 13370, expectedInsertSpaces, expectedTabSize, text, msg);
                _testGuessIndentation(false, 13371, expectedInsertSpaces, expectedTabSize, text, msg);
            }
            else {
                // can only guess tabSize when insertSpaces is true
                final expectedTabSize:Array<Int> = cast expectedTabSize;
                if (expectedInsertSpaces == true) {
                    _testGuessIndentation(true, 13370, expectedInsertSpaces, expectedTabSize[0], text, msg);
                    _testGuessIndentation(false, 13371, expectedInsertSpaces, expectedTabSize[0], text, msg);
                }
                else {
                    _testGuessIndentation(true, 13370, expectedInsertSpaces, 13370, text, msg);
                    _testGuessIndentation(false, 13371, expectedInsertSpaces, 13371, text, msg);
                }
            }
        }
    }

    function testTextModelDoesNotUseEventsInternally() {
        // Make sure that all model parts receive text model events explicitly
        // to avoid that by any chance an outside listener receives events before
        // the parts and thus are able to access the text model in an inconsistent state.
        //
        // We simply check that there are no listeners attached to text model
        // after instantiation
        // (vscode's model services are a new `Cityscape` context here; 'plaintext' is PLAINTEXT_LANGUAGE_ID)
        final textModel = new TextModel('', 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, new Cityscape());
        assertEquals(textModel._hasListeners(), false);
        textModel.dispose();
    }

    function testGetValueLengthInRange() {

        var m = createTextModel('My First Line\r\nMy Second Line\r\nMy Third Line');
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1, 1)), ''.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1, 2)), 'M'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 1, 3)), 'y'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1, 14)), 'My First Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1)), 'My First Line\r\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 2, 1)), 'y First Line\r\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 2, 2)), 'y First Line\r\nM'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 2, 1000)), 'y First Line\r\nMy Second Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 3, 1)), 'y First Line\r\nMy Second Line\r\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 3, 1000)), 'y First Line\r\nMy Second Line\r\nMy Third Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000)), 'My First Line\r\nMy Second Line\r\nMy Third Line'.length);
        m.dispose();

        m = createTextModel('My First Line\nMy Second Line\nMy Third Line');
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1, 1)), ''.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1, 2)), 'M'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 1, 3)), 'y'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1, 14)), 'My First Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1)), 'My First Line\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 2, 1)), 'y First Line\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 2, 2)), 'y First Line\nM'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 2, 1000)), 'y First Line\nMy Second Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 3, 1)), 'y First Line\nMy Second Line\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 2, 3, 1000)), 'y First Line\nMy Second Line\nMy Third Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000)), 'My First Line\nMy Second Line\nMy Third Line'.length);
        m.dispose();
    }

    function testGetValueLengthInRangeDifferentEOL() {

        var m = createTextModel('My First Line\r\nMy Second Line\r\nMy Third Line');
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1), EndOfLinePreference.TextDefined), 'My First Line\r\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1), EndOfLinePreference.CRLF), 'My First Line\r\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1), EndOfLinePreference.LF), 'My First Line\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000), EndOfLinePreference.TextDefined), 'My First Line\r\nMy Second Line\r\nMy Third Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000), EndOfLinePreference.CRLF), 'My First Line\r\nMy Second Line\r\nMy Third Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000), EndOfLinePreference.LF), 'My First Line\nMy Second Line\nMy Third Line'.length);
        m.dispose();

        m = createTextModel('My First Line\nMy Second Line\nMy Third Line');
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1), EndOfLinePreference.TextDefined), 'My First Line\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1), EndOfLinePreference.LF), 'My First Line\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 2, 1), EndOfLinePreference.CRLF), 'My First Line\r\n'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000), EndOfLinePreference.TextDefined), 'My First Line\nMy Second Line\nMy Third Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000), EndOfLinePreference.LF), 'My First Line\nMy Second Line\nMy Third Line'.length);
        assertEquals(m.getValueLengthInRange(new Range(1, 1, 1000, 1000), EndOfLinePreference.CRLF), 'My First Line\r\nMy Second Line\r\nMy Third Line'.length);
        m.dispose();
    }

    function testGuessIndentation1() {

        assertGuess(null, null, [
            'x',
            'x',
            'x',
            'x',
            'x',
            'x',
            'x'
        ], 'no clues');

        assertGuess(false, null, [
            '\tx',
            'x',
            'x',
            'x',
            'x',
            'x',
            'x'
        ], 'no spaces, 1xTAB');

        assertGuess(true, 2, [
            '  x',
            'x',
            'x',
            'x',
            'x',
            'x',
            'x'
        ], '1x2');

        assertGuess(false, null, [
            '\tx',
            '\tx',
            '\tx',
            '\tx',
            '\tx',
            '\tx',
            '\tx'
        ], '7xTAB');

        assertGuess(null, [2], [
            '\tx',
            '  x',
            '\tx',
            '  x',
            '\tx',
            '  x',
            '\tx',
            '  x',
        ], '4x2, 4xTAB');
        assertGuess(false, null, [
            '\tx',
            ' x',
            '\tx',
            ' x',
            '\tx',
            ' x',
            '\tx',
            ' x'
        ], '4x1, 4xTAB');
        assertGuess(false, null, [
            '\tx',
            '\tx',
            '  x',
            '\tx',
            '  x',
            '\tx',
            '  x',
            '\tx',
            '  x',
        ], '4x2, 5xTAB');
        assertGuess(false, null, [
            '\tx',
            '\tx',
            'x',
            '\tx',
            'x',
            '\tx',
            'x',
            '\tx',
            '  x',
        ], '1x2, 5xTAB');
        assertGuess(false, null, [
            '\tx',
            '\tx',
            'x',
            '\tx',
            'x',
            '\tx',
            'x',
            '\tx',
            '    x',
        ], '1x4, 5xTAB');
        assertGuess(false, null, [
            '\tx',
            '\tx',
            'x',
            '\tx',
            'x',
            '\tx',
            '  x',
            '\tx',
            '    x',
        ], '1x2, 1x4, 5xTAB');

        assertGuess(null, null, [
            'x',
            ' x',
            ' x',
            ' x',
            ' x',
            ' x',
            ' x',
            ' x'
        ], '7x1 - 1 space is never guessed as an indentation');
        assertGuess(true, null, [
            'x',
            '          x',
            ' x',
            ' x',
            ' x',
            ' x',
            ' x',
            ' x'
        ], '1x10, 6x1');
        assertGuess(null, null, [
            '',
            '  ',
            '    ',
            '      ',
            '        ',
            '          ',
            '            ',
            '              ',
        ], 'whitespace lines don\'t count');
        assertGuess(true, 3, [
            'x',
            '   x',
            '   x',
            '    x',
            'x',
            '   x',
            '   x',
            '    x',
            'x',
            '   x',
            '   x',
            '    x',
        ], '6x3, 3x4');
        assertGuess(true, 5, [
            'x',
            '     x',
            '     x',
            '    x',
            'x',
            '     x',
            '     x',
            '    x',
            'x',
            '     x',
            '     x',
            '    x',
        ], '6x5, 3x4');
        assertGuess(true, 7, [
            'x',
            '       x',
            '       x',
            '     x',
            'x',
            '       x',
            '       x',
            '    x',
            'x',
            '       x',
            '       x',
            '    x',
        ], '6x7, 1x5, 2x4');
        assertGuess(true, 2, [
            'x',
            '  x',
            '  x',
            '  x',
            '  x',
            'x',
            '  x',
            '  x',
            '  x',
            '  x',
        ], '8x2');

        assertGuess(true, 2, [
            'x',
            '  x',
            '  x',
            'x',
            '  x',
            '  x',
            'x',
            '  x',
            '  x',
            'x',
            '  x',
            '  x',
        ], '8x2');
        assertGuess(true, 2, [
            'x',
            '  x',
            '    x',
            'x',
            '  x',
            '    x',
            'x',
            '  x',
            '    x',
            'x',
            '  x',
            '    x',
        ], '4x2, 4x4');
        assertGuess(true, 2, [
            'x',
            '  x',
            '  x',
            '    x',
            'x',
            '  x',
            '  x',
            '    x',
            'x',
            '  x',
            '  x',
            '    x',
        ], '6x2, 3x4');
        assertGuess(true, 2, [
            'x',
            '  x',
            '  x',
            '    x',
            '    x',
            'x',
            '  x',
            '  x',
            '    x',
            '    x',
        ], '4x2, 4x4');
        assertGuess(true, 2, [
            'x',
            '  x',
            '    x',
            '    x',
            'x',
            '  x',
            '    x',
            '    x',
        ], '2x2, 4x4');
        assertGuess(true, 4, [
            'x',
            '    x',
            '    x',
            'x',
            '    x',
            '    x',
            'x',
            '    x',
            '    x',
            'x',
            '    x',
            '    x',
        ], '8x4');
        assertGuess(true, 2, [
            'x',
            '  x',
            '    x',
            '    x',
            '      x',
            'x',
            '  x',
            '    x',
            '    x',
            '      x',
        ], '2x2, 4x4, 2x6');
        assertGuess(true, 2, [
            'x',
            '  x',
            '    x',
            '    x',
            '      x',
            '      x',
            '        x',
        ], '1x2, 2x4, 2x6, 1x8');
        assertGuess(true, 4, [
            'x',
            '    x',
            '    x',
            '    x',
            '     x',
            '        x',
            'x',
            '    x',
            '    x',
            '    x',
            '     x',
            '        x',
        ], '6x4, 2x5, 2x8');
        assertGuess(true, 4, [
            'x',
            '    x',
            '    x',
            '    x',
            '     x',
            '        x',
            '        x',
        ], '3x4, 1x5, 2x8');
        assertGuess(true, 4, [
            'x',
            'x',
            '    x',
            '    x',
            '     x',
            '        x',
            '        x',
            'x',
            'x',
            '    x',
            '    x',
            '     x',
            '        x',
            '        x',
        ], '6x4, 2x5, 4x8');
        assertGuess(true, 3, [
            'x',
            ' x',
            ' x',
            ' x',
            ' x',
            ' x',
            'x',
            '   x',
            '    x',
            '    x',
        ], '5x1, 2x0, 1x3, 2x4');
        assertGuess(false, null, [
            '\t x',
            ' \t x',
            '\tx'
        ], 'mixed whitespace 1');
        assertGuess(false, null, [
            '\tx',
            '\t    x'
        ], 'mixed whitespace 2');
    }

    function testIssue44991WrongIndentationSizeAutoDetection() {
        assertGuess(true, 4, [
            'a = 10             # 0 space indent',
            'b = 5              # 0 space indent',
            'if a > 10:         # 0 space indent',
            '    a += 1         # 4 space indent      delta 4 spaces',
            '    if b > 5:      # 4 space indent',
            '        b += 1     # 8 space indent      delta 4 spaces',
            '        b += 1     # 8 space indent',
            '        b += 1     # 8 space indent',
            '# comment line 1   # 0 space indent      delta 8 spaces',
            '# comment line 2   # 0 space indent',
            '# comment line 3   # 0 space indent',
            '        b += 1     # 8 space indent      delta 8 spaces',
            '        b += 1     # 8 space indent',
            '        b += 1     # 8 space indent',
        ]);
    }

    function testIssue55818BrokenIndentationDetection() {
        assertGuess(true, 2, [
            '',
            '/* REQUIRE */',
            '',
            'final foo = require ( \'foo\' ),',
            '      bar = require ( \'bar\' );',
            '',
            '/* MY FN */',
            '',
            'function myFn () {',
            '',
            '  final asd = 1,',
            '        dsa = 2;',
            '',
            '  return bar ( foo ( asd ) );',
            '',
            '}',
            '',
            '/* EXPORT */',
            '',
            'module.exports = myFn;',
            '',
        ]);
    }

    function testIssue70832BrokenIndentationDetection() {
        assertGuess(false, null, [
            'x',
            'x',
            'x',
            'x',
            '\tx',
            '\t\tx',
            '    x',
            '\t\tx',
            '\tx',
            '\t\tx',
            '\tx',
            '\tx',
            '\tx',
            '\tx',
            'x',
        ]);
    }

    function testIssue62143BrokenIndentationDetection() {
        // works before the fix
        assertGuess(true, 2, [
            'x',
            'x',
            '  x',
            '  x'
        ]);

        // works before the fix
        assertGuess(true, 2, [
            'x',
            '  - item2',
            '  - item3'
        ]);

        // works before the fix
        _testGuessIndentation(true, 2, true, 2, [
            'x x',
            '  x',
            '  x',
        ]);

        // fails before the fix
        // empty space inline breaks the indentation guess
        _testGuessIndentation(true, 2, true, 2, [
            'x x',
            '  x',
            '  x',
            '    x'
        ]);

        _testGuessIndentation(true, 2, true, 2, [
            '<!--test1.md -->',
            '- item1',
            '  - item2',
            '    - item3'
        ]);
    }

    function testIssue84217BrokenIndentationDetection() {
        assertGuess(true, 4, [
            'def main():',
            '    print(\'hello\')',
        ]);
        assertGuess(true, 4, [
            'def main():',
            '    with open(\'foo\') as fp:',
            '        print(fp.read())',
        ]);
    }

    function testValidatePosition() {

        final m = createTextModel('line one\nline two');

        assertDeepEquals(m.validatePosition(new Position(0, 0)), new Position(1, 1));
        assertDeepEquals(m.validatePosition(new Position(0, 1)), new Position(1, 1));

        assertDeepEquals(m.validatePosition(new Position(1, 1)), new Position(1, 1));
        assertDeepEquals(m.validatePosition(new Position(1, 2)), new Position(1, 2));
        assertDeepEquals(m.validatePosition(new Position(1, 30)), new Position(1, 9));

        assertDeepEquals(m.validatePosition(new Position(2, 0)), new Position(2, 1));
        assertDeepEquals(m.validatePosition(new Position(2, 1)), new Position(2, 1));
        assertDeepEquals(m.validatePosition(new Position(2, 2)), new Position(2, 2));
        assertDeepEquals(m.validatePosition(new Position(2, 30)), new Position(2, 9));

        assertDeepEquals(m.validatePosition(new Position(3, 0)), new Position(2, 9));
        assertDeepEquals(m.validatePosition(new Position(3, 1)), new Position(2, 9));
        assertDeepEquals(m.validatePosition(new Position(3, 30)), new Position(2, 9));

        assertDeepEquals(m.validatePosition(new Position(30, 30)), new Position(2, 9));

        // Not ported: the lines with float, Number.MIN_VALUE and Number.MAX_VALUE coordinates
        // (Position and Range take Int coordinates in Cityscape).


        m.dispose();
    }

    function testValidatePositionAroundHighLowSurrogatePairs1() {

        final m = createTextModel('a\u{1F4DA}b');

        assertDeepEquals(m.validatePosition(new Position(0, 0)), new Position(1, 1));
        assertDeepEquals(m.validatePosition(new Position(0, 1)), new Position(1, 1));
        assertDeepEquals(m.validatePosition(new Position(0, 7)), new Position(1, 1));

        assertDeepEquals(m.validatePosition(new Position(1, 1)), new Position(1, 1));
        assertDeepEquals(m.validatePosition(new Position(1, 2)), new Position(1, 2));
        assertDeepEquals(m.validatePosition(new Position(1, 3)), new Position(1, 2));
        assertDeepEquals(m.validatePosition(new Position(1, 4)), new Position(1, 4));
        assertDeepEquals(m.validatePosition(new Position(1, 5)), new Position(1, 5));
        assertDeepEquals(m.validatePosition(new Position(1, 30)), new Position(1, 5));

        assertDeepEquals(m.validatePosition(new Position(2, 0)), new Position(1, 5));
        assertDeepEquals(m.validatePosition(new Position(2, 1)), new Position(1, 5));
        assertDeepEquals(m.validatePosition(new Position(2, 2)), new Position(1, 5));
        assertDeepEquals(m.validatePosition(new Position(2, 30)), new Position(1, 5));

        // Not ported: the lines with float, Number.MIN_VALUE and Number.MAX_VALUE coordinates
        // (Position and Range take Int coordinates in Cityscape).


        m.dispose();
    }

    function testValidatePositionAroundHighLowSurrogatePairs2() {

        final m = createTextModel('a\u{1F4DA}\u{1F4DA}b');

        assertDeepEquals(m.validatePosition(new Position(1, 1)), new Position(1, 1));
        assertDeepEquals(m.validatePosition(new Position(1, 2)), new Position(1, 2));
        assertDeepEquals(m.validatePosition(new Position(1, 3)), new Position(1, 2));
        assertDeepEquals(m.validatePosition(new Position(1, 4)), new Position(1, 4));
        assertDeepEquals(m.validatePosition(new Position(1, 5)), new Position(1, 4));
        assertDeepEquals(m.validatePosition(new Position(1, 6)), new Position(1, 6));
        assertDeepEquals(m.validatePosition(new Position(1, 7)), new Position(1, 7));

        m.dispose();

    }

    function testValidateRangeAroundHighLowSurrogatePairs1() {

        final m = createTextModel('a\u{1F4DA}b');

        assertDeepEquals(m.validateRange(new Range(0, 0, 0, 1)), new Range(1, 1, 1, 1));
        assertDeepEquals(m.validateRange(new Range(0, 0, 0, 7)), new Range(1, 1, 1, 1));

        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 1)), new Range(1, 1, 1, 1));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 2)), new Range(1, 1, 1, 2));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 3)), new Range(1, 1, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 4)), new Range(1, 1, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 5)), new Range(1, 1, 1, 5));

        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 2)), new Range(1, 2, 1, 2));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 3)), new Range(1, 2, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 4)), new Range(1, 2, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 5)), new Range(1, 2, 1, 5));

        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 3)), new Range(1, 2, 1, 2));
        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 4)), new Range(1, 2, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 5)), new Range(1, 2, 1, 5));

        assertDeepEquals(m.validateRange(new Range(1, 4, 1, 4)), new Range(1, 4, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 4, 1, 5)), new Range(1, 4, 1, 5));

        assertDeepEquals(m.validateRange(new Range(1, 5, 1, 5)), new Range(1, 5, 1, 5));

        m.dispose();
    }

    function testValidateRangeAroundHighLowSurrogatePairs2() {

        final m = createTextModel('a\u{1F4DA}\u{1F4DA}b');

        assertDeepEquals(m.validateRange(new Range(0, 0, 0, 1)), new Range(1, 1, 1, 1));
        assertDeepEquals(m.validateRange(new Range(0, 0, 0, 7)), new Range(1, 1, 1, 1));

        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 1)), new Range(1, 1, 1, 1));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 2)), new Range(1, 1, 1, 2));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 3)), new Range(1, 1, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 4)), new Range(1, 1, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 5)), new Range(1, 1, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 6)), new Range(1, 1, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 1, 1, 7)), new Range(1, 1, 1, 7));

        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 2)), new Range(1, 2, 1, 2));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 3)), new Range(1, 2, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 4)), new Range(1, 2, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 5)), new Range(1, 2, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 6)), new Range(1, 2, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 2, 1, 7)), new Range(1, 2, 1, 7));

        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 3)), new Range(1, 2, 1, 2));
        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 4)), new Range(1, 2, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 5)), new Range(1, 2, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 6)), new Range(1, 2, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 3, 1, 7)), new Range(1, 2, 1, 7));

        assertDeepEquals(m.validateRange(new Range(1, 4, 1, 4)), new Range(1, 4, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 4, 1, 5)), new Range(1, 4, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 4, 1, 6)), new Range(1, 4, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 4, 1, 7)), new Range(1, 4, 1, 7));

        assertDeepEquals(m.validateRange(new Range(1, 5, 1, 5)), new Range(1, 4, 1, 4));
        assertDeepEquals(m.validateRange(new Range(1, 5, 1, 6)), new Range(1, 4, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 5, 1, 7)), new Range(1, 4, 1, 7));

        assertDeepEquals(m.validateRange(new Range(1, 6, 1, 6)), new Range(1, 6, 1, 6));
        assertDeepEquals(m.validateRange(new Range(1, 6, 1, 7)), new Range(1, 6, 1, 7));

        assertDeepEquals(m.validateRange(new Range(1, 7, 1, 7)), new Range(1, 7, 1, 7));

        m.dispose();
    }

    function testModifyPosition() {

        final m = createTextModel('line one\nline two');
        assertDeepEquals(m.modifyPosition(new Position(1, 1), 0), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(0, 0), 0), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(30, 1), 0), new Position(2, 9));

        assertDeepEquals(m.modifyPosition(new Position(1, 1), 17), new Position(2, 9));
        assertDeepEquals(m.modifyPosition(new Position(1, 1), 1), new Position(1, 2));
        assertDeepEquals(m.modifyPosition(new Position(1, 1), 3), new Position(1, 4));
        assertDeepEquals(m.modifyPosition(new Position(1, 2), 10), new Position(2, 3));
        assertDeepEquals(m.modifyPosition(new Position(1, 5), 13), new Position(2, 9));
        assertDeepEquals(m.modifyPosition(new Position(1, 2), 16), new Position(2, 9));

        assertDeepEquals(m.modifyPosition(new Position(2, 9), -17), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(1, 2), -1), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(1, 4), -3), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(2, 3), -10), new Position(1, 2));
        assertDeepEquals(m.modifyPosition(new Position(2, 9), -13), new Position(1, 5));
        assertDeepEquals(m.modifyPosition(new Position(2, 9), -16), new Position(1, 2));

        assertDeepEquals(m.modifyPosition(new Position(1, 2), 17), new Position(2, 9));
        assertDeepEquals(m.modifyPosition(new Position(1, 2), 100), new Position(2, 9));

        assertDeepEquals(m.modifyPosition(new Position(1, 2), -2), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(1, 2), -100), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(2, 2), -100), new Position(1, 1));
        assertDeepEquals(m.modifyPosition(new Position(2, 9), -18), new Position(1, 1));

        m.dispose();
    }

    function testNormalizeIndentation1() {
        final model = createTextModel('',
            null,
            {
                insertSpaces: false
            }
        );

        assertEquals(model.normalizeIndentation('\t'), '\t');
        assertEquals(model.normalizeIndentation('    '), '\t');
        assertEquals(model.normalizeIndentation('   '), '   ');
        assertEquals(model.normalizeIndentation('  '), '  ');
        assertEquals(model.normalizeIndentation(' '), ' ');
        assertEquals(model.normalizeIndentation(''), '');
        assertEquals(model.normalizeIndentation(' \t    '), '\t\t');
        assertEquals(model.normalizeIndentation(' \t   '), '\t   ');
        assertEquals(model.normalizeIndentation(' \t  '), '\t  ');
        assertEquals(model.normalizeIndentation(' \t '), '\t ');
        assertEquals(model.normalizeIndentation(' \t'), '\t');

        assertEquals(model.normalizeIndentation('\ta'), '\ta');
        assertEquals(model.normalizeIndentation('    a'), '\ta');
        assertEquals(model.normalizeIndentation('   a'), '   a');
        assertEquals(model.normalizeIndentation('  a'), '  a');
        assertEquals(model.normalizeIndentation(' a'), ' a');
        assertEquals(model.normalizeIndentation('a'), 'a');
        assertEquals(model.normalizeIndentation(' \t    a'), '\t\ta');
        assertEquals(model.normalizeIndentation(' \t   a'), '\t   a');
        assertEquals(model.normalizeIndentation(' \t  a'), '\t  a');
        assertEquals(model.normalizeIndentation(' \t a'), '\t a');
        assertEquals(model.normalizeIndentation(' \ta'), '\ta');

        model.dispose();
    }

    function testNormalizeIndentation2() {
        final model = createTextModel('');

        assertEquals(model.normalizeIndentation('\ta'), '    a');
        assertEquals(model.normalizeIndentation('    a'), '    a');
        assertEquals(model.normalizeIndentation('   a'), '   a');
        assertEquals(model.normalizeIndentation('  a'), '  a');
        assertEquals(model.normalizeIndentation(' a'), ' a');
        assertEquals(model.normalizeIndentation('a'), 'a');
        assertEquals(model.normalizeIndentation(' \t    a'), '        a');
        assertEquals(model.normalizeIndentation(' \t   a'), '       a');
        assertEquals(model.normalizeIndentation(' \t  a'), '      a');
        assertEquals(model.normalizeIndentation(' \t a'), '     a');
        assertEquals(model.normalizeIndentation(' \ta'), '    a');

        model.dispose();
    }

    function testGetLineFirstNonWhitespaceColumn() {
        final model = createTextModel([
            'asd',
            ' asd',
            '\tasd',
            '  asd',
            '\t\tasd',
            ' ',
            '  ',
            '\t',
            '\t\t',
            '  \tasd',
            '',
            ''
        ].join('\n'));

        assertEquals(model.getLineFirstNonWhitespaceColumn(1), 1, '1');
        assertEquals(model.getLineFirstNonWhitespaceColumn(2), 2, '2');
        assertEquals(model.getLineFirstNonWhitespaceColumn(3), 2, '3');
        assertEquals(model.getLineFirstNonWhitespaceColumn(4), 3, '4');
        assertEquals(model.getLineFirstNonWhitespaceColumn(5), 3, '5');
        assertEquals(model.getLineFirstNonWhitespaceColumn(6), 0, '6');
        assertEquals(model.getLineFirstNonWhitespaceColumn(7), 0, '7');
        assertEquals(model.getLineFirstNonWhitespaceColumn(8), 0, '8');
        assertEquals(model.getLineFirstNonWhitespaceColumn(9), 0, '9');
        assertEquals(model.getLineFirstNonWhitespaceColumn(10), 4, '10');
        assertEquals(model.getLineFirstNonWhitespaceColumn(11), 0, '11');
        assertEquals(model.getLineFirstNonWhitespaceColumn(12), 0, '12');

        model.dispose();
    }

    function testGetLineLastNonWhitespaceColumn() {
        final model = createTextModel([
            'asd',
            'asd ',
            'asd\t',
            'asd  ',
            'asd\t\t',
            ' ',
            '  ',
            '\t',
            '\t\t',
            'asd  \t',
            '',
            ''
        ].join('\n'));

        assertEquals(model.getLineLastNonWhitespaceColumn(1), 4, '1');
        assertEquals(model.getLineLastNonWhitespaceColumn(2), 4, '2');
        assertEquals(model.getLineLastNonWhitespaceColumn(3), 4, '3');
        assertEquals(model.getLineLastNonWhitespaceColumn(4), 4, '4');
        assertEquals(model.getLineLastNonWhitespaceColumn(5), 4, '5');
        assertEquals(model.getLineLastNonWhitespaceColumn(6), 0, '6');
        assertEquals(model.getLineLastNonWhitespaceColumn(7), 0, '7');
        assertEquals(model.getLineLastNonWhitespaceColumn(8), 0, '8');
        assertEquals(model.getLineLastNonWhitespaceColumn(9), 0, '9');
        assertEquals(model.getLineLastNonWhitespaceColumn(10), 4, '10');
        assertEquals(model.getLineLastNonWhitespaceColumn(11), 0, '11');
        assertEquals(model.getLineLastNonWhitespaceColumn(12), 0, '12');

        model.dispose();
    }

    function testIssue168836UpdatingTabSizeShouldAlsoUpdateIndentSizeWhenIndentSizeIsSetToTabSize() {
        final m = createTextModel('some text', null, {
            tabSize: 2,
            indentSize: 'tabSize'
        });
        assertEquals(m.getOptions().tabSize, 2);
        assertEquals(m.getOptions().indentSize, 2);
        assertEquals((m.getOptions().originalIndentSize : Any), ('tabSize' : Any));
        m.updateOptions({
            tabSize: 4
        });
        assertEquals(m.getOptions().tabSize, 4);
        assertEquals(m.getOptions().indentSize, 4);
        assertEquals((m.getOptions().originalIndentSize : Any), ('tabSize' : Any));
        m.dispose();
    }

}

/**
 * suite('TextModel.mightContainRTL')
 */
class TextModelMightContainRTLTest extends TestCase {

    function testNope() {
        final model = createTextModel('hello world!');
        assertEquals(model.mightContainRTL(), false);
        model.dispose();
    }

    function testYes() {
        final model = createTextModel('Hello,\nזוהי עובדה מבוססת שדעתו');
        assertEquals(model.mightContainRTL(), true);
        model.dispose();
    }

    function testSetValueResets1() {
        final model = createTextModel('hello world!');
        assertEquals(model.mightContainRTL(), false);
        model.setValue('Hello,\nזוהי עובדה מבוססת שדעתו');
        assertEquals(model.mightContainRTL(), true);
        model.dispose();
    }

    function testSetValueResets2() {
        final model = createTextModel('Hello,\nهناك حقيقة مثبتة منذ زمن طويل');
        assertEquals(model.mightContainRTL(), true);
        model.setValue('hello world!');
        assertEquals(model.mightContainRTL(), false);
        model.dispose();
    }

}

/**
 * suite('TextModel.createSnapshot')
 *
 * Not ported: test('issue #119632: invalid range'): Range takes Int coordinates in Cityscape, `undefined` cannot be passed.
 */
class TextModelCreateSnapshotTest extends TestCase {

    function testEmptyFile() {
        final model = createTextModel('');
        final snapshot = model.createSnapshot();
        assertEquals(snapshot.read(), null);
        model.dispose();
    }

    function testFileWithBOM() {
        final model = createTextModel(Strings.UTF8_BOM_CHARACTER + 'Hello');
        assertEquals(model.getLineContent(1), 'Hello');
        final snapshot = model.createSnapshot(true);
        assertEquals(snapshot.read(), Strings.UTF8_BOM_CHARACTER + 'Hello');
        assertEquals(snapshot.read(), null);
        model.dispose();
    }

    function testRegularFile() {
        final model = createTextModel('My First Line\n\t\tMy Second Line\n    Third Line\n\n1');
        final snapshot = model.createSnapshot();
        assertEquals(snapshot.read(), 'My First Line\n\t\tMy Second Line\n    Third Line\n\n1');
        assertEquals(snapshot.read(), null);
        model.dispose();
    }

    function testLargeFile() {
        final lines:Array<String> = [];
        for (i in 0...1000) {
            lines[i] = 'Just some text that is a bit long such that it can consume some memory';
        }
        final text = lines.join('\n');

        final model = createTextModel(text);
        final snapshot = model.createSnapshot();
        var actual = '';

        // 70999 length => at most 2 read calls are necessary
        final tmp1 = snapshot.read();
        assertTrue(tmp1 != null && tmp1 != '');
        actual += tmp1;

        final tmp2 = snapshot.read();
        if (tmp2 == null) {
            // all good
        }
        else {
            actual += tmp2;
            assertEquals(snapshot.read(), null);
        }

        assertEquals(actual, text);

        model.dispose();
    }

}
