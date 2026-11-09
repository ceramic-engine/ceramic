// Ported from vscode src/vs/editor/test/common/model/editStack.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.common.Model.EndOfLineSequence;
import cityscape.common.core.Selection;
import cityscape.common.core.TextChange;
import cityscape.common.model.EditStack.SingleModelEditStackData;
import testing.TestCase;

/**
 * suite('EditStack')
 */
class EditStackTest extends TestCase {

    function testIssue118041UnicodeCharacterUndoBug() {
        final stackData = new SingleModelEditStackData(
            1,
            2,
            EndOfLineSequence.LF,
            EndOfLineSequence.LF,
            [new Selection(10, 2, 10, 2)],
            [new Selection(10, 1, 10, 1)],
            [new TextChange(428, '\u{FEFF}', 428, '')]
        );

        final buff = stackData.serialize();
        final actual = SingleModelEditStackData.deserialize(buff);

        assertDeepEquals(actual, stackData);
    }

}
