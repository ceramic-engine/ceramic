// Ported from vscode src/vs/editor/test/common/model/textChange.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes: TextChangeCompressorTest, TextChangeTest

import cityscape.common.core.TextChange;
import testing.TestCase;

typedef IGeneratedEdit = {
    var offset:Int;
    var length:Int;
    var text:String;
}

/**
 * suite('TextChangeCompressor')
 *
 * GENERATE_TESTS is false in vscode: the random test generator (which
 * only prints new cases) is not ported.
 */
class TextChangeCompressorTest extends TestCase {

    static function getResultingContent(initialContent:String, edits:Array<IGeneratedEdit>):String {
        var content = initialContent;
        var i = edits.length - 1;
        while (i >= 0) {
            content = (
                content.substring(0, edits[i].offset)
                + edits[i].text
                + content.substring(edits[i].offset + edits[i].length)
            );
            i--;
        }
        return content;
    }

    static function getTextChanges(initialContent:String, edits:Array<IGeneratedEdit>):Array<TextChange> {
        var content = initialContent;
        final changes:Array<TextChange> = [];
        var deltaOffset = 0;

        for (i in 0...edits.length) {
            final edit = edits[i];

            final position = edit.offset + deltaOffset;
            final length = edit.length;
            final text = edit.text;

            final oldText = content.substr(position, length);

            content = (
                content.substr(0, position)
                + text
                + content.substr(position + length)
            );

            changes[i] = new TextChange(edit.offset, oldText, position, text);

            deltaOffset += text.length - length;
        }

        return changes;
    }

    function assertCompression(initialText:String, edit1:Array<IGeneratedEdit>, edit2:Array<IGeneratedEdit>):Void {

        final tmpText = getResultingContent(initialText, edit1);
        final chg1 = getTextChanges(initialText, edit1);

        final finalText = getResultingContent(tmpText, edit2);
        final chg2 = getTextChanges(tmpText, edit2);

        final compressedTextChanges = TextChange.compressConsecutiveTextChanges(chg1, chg2);

        // Check that the compression was correct
        final compressedDoTextEdits:Array<IGeneratedEdit> = compressedTextChanges.map((change) -> {
            offset: change.oldPosition,
            length: change.oldLength,
            text: change.newText
        });
        final actualDoResult = getResultingContent(initialText, compressedDoTextEdits);
        assertEquals(actualDoResult, finalText);

        final compressedUndoTextEdits:Array<IGeneratedEdit> = compressedTextChanges.map((change) -> {
            offset: change.newPosition,
            length: change.newLength,
            text: change.oldText
        });
        final actualUndoResult = getResultingContent(finalText, compressedUndoTextEdits);
        assertEquals(actualUndoResult, initialText);
    }

    function testSimple1() {
        assertCompression(
            '',
            [{offset: 0, length: 0, text: 'h'}],
            [{offset: 1, length: 0, text: 'e'}]
        );
    }

    function testSimple2() {
        assertCompression(
            '|',
            [{offset: 0, length: 0, text: 'h'}],
            [{offset: 2, length: 0, text: 'e'}]
        );
    }

    function testComplex1() {
        assertCompression(
            'abcdefghij',
            [
                {offset: 0, length: 3, text: 'qh'},
                {offset: 5, length: 0, text: '1'},
                {offset: 8, length: 2, text: 'X'}
            ],
            [
                {offset: 1, length: 0, text: 'Z'},
                {offset: 3, length: 3, text: 'Y'},
            ]
        );
    }

    function testGen1() {
        assertCompression(
            'kxm',
            [{offset: 0, length: 1, text: 'tod_neu'}],
            [{offset: 1, length: 2, text: 'sag_e'}]
        );
    }

    function testGen2() {
        assertCompression(
            'kpb_r_v',
            [{offset: 5, length: 2, text: 'a_jvf_l'}],
            [{offset: 10, length: 2, text: 'w'}]
        );
    }

    function testGen3() {
        assertCompression(
            'slu_w',
            [{offset: 4, length: 1, text: '_wfw'}],
            [{offset: 3, length: 5, text: ''}]
        );
    }

    function testGen4() {
        assertCompression(
            '_e',
            [{offset: 2, length: 0, text: 'zo_b'}],
            [{offset: 1, length: 3, text: 'tra'}]
        );
    }

    function testGen5() {
        assertCompression(
            'ssn_',
            [{offset: 0, length: 2, text: 'tat_nwe'}],
            [{offset: 2, length: 6, text: 'jm'}]
        );
    }

    function testGen6() {
        assertCompression(
            'kl_nru',
            [{offset: 4, length: 1, text: ''}],
            [{offset: 1, length: 4, text: '__ut'}]
        );
    }

}

/**
 * suite('TextChange')
 */
class TextChangeTest extends TestCase {

    function testIssue118041UnicodeCharacterUndoBug() {
        final textChange = new TextChange(428, '\u{FEFF}', 428, '');
        final buff = haxe.io.Bytes.alloc(textChange.writeSize());
        textChange.write(buff, 0);
        final actual:Array<TextChange> = [];
        TextChange.read(buff, 0, actual);
        assertDeepEquals(actual[0], textChange);
    }

}
