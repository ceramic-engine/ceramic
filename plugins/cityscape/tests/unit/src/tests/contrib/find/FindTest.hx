// Ported from vscode src/vs/editor/contrib/find/test/browser/find.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.find;

import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.find.view.FindController.FindControllerUtils;
import testing.TestCase;
import testing.TestCodeEditor;

/**
 * suite('Find')
 */
class FindTest extends TestCase {

    static function withFindEditor(text:Array<String>, callback:(editor:TestCodeEditor) -> Void):Void {
        TestCodeEditor.withTestCodeEditor(text, {}, (editor, _) -> callback(editor));
    }

    function testSearchStringAtPosition() {
        withFindEditor([
            'ABC DEF',
            '0123 456'
        ], (editor) -> {

            // The cursor is at the very top, of the file, at the first ABC
            final searchStringAtTop = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals('ABC', searchStringAtTop);

            // Move cursor to the end of ABC
            editor.setPosition(new Position(1, 3));
            final searchStringAfterABC = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals('ABC', searchStringAfterABC);

            // Move cursor to DEF
            editor.setPosition(new Position(1, 5));
            final searchStringInsideDEF = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals('DEF', searchStringInsideDEF);

        });
    }

    function testSearchStringWithSelection() {
        withFindEditor([
            'ABC DEF',
            '0123 456'
        ], (editor) -> {

            // Select A of ABC
            editor.setSelection(new Range(1, 1, 1, 2));
            final searchStringSelectionA = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals('A', searchStringSelectionA);

            // Select BC of ABC
            editor.setSelection(new Range(1, 2, 1, 4));
            final searchStringSelectionBC = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals('BC', searchStringSelectionBC);

            // Select BC DE
            editor.setSelection(new Range(1, 2, 1, 7));
            final searchStringSelectionBCDE = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals('BC DE', searchStringSelectionBCDE);

        });
    }

    function testSearchStringWithMultilineSelection() {
        withFindEditor([
            'ABC DEF',
            '0123 456'
        ], (editor) -> {

            // Select first line and newline
            editor.setSelection(new Range(1, 1, 2, 1));
            final searchStringSelectionWholeLine = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals(null, searchStringSelectionWholeLine);

            // Select first line and chunk of second
            editor.setSelection(new Range(1, 1, 2, 4));
            final searchStringSelectionTwoLines = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals(null, searchStringSelectionTwoLines);

            // Select end of first line newline and chunk of second
            editor.setSelection(new Range(1, 7, 2, 4));
            final searchStringSelectionSpanLines = FindControllerUtils.getSelectionSearchString(editor);
            assertEquals(null, searchStringSelectionSpanLines);

        });
    }

}
