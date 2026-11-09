// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/length.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;

import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import testing.TestCase;

/**
 * suite('Bracket Pair Colorizer - Length')
 */
class LengthTest extends TestCase {

    function toStr(length:Length):String {
        return Length.lengthToObj(length).toString();
    }

    function testBasic() {
        final l1 = Length.toLength(100, 10);
        assertEquals(Length.lengthToObj(l1).lineCount, 100);
        assertEquals(Length.lengthToObj(l1).columnCount, 10);

        assertDeepEquals(toStr(Length.lengthAdd(l1, Length.toLength(100, 10))), '200,10');
        assertDeepEquals(toStr(Length.lengthAdd(l1, Length.toLength(0, 10))), '100,20');
    }

    function testLengthDiffNonNeg() {
        assertDeepEquals(
            toStr(
                Length.lengthDiffNonNegative(
                    Length.toLength(100, 10),
                    Length.toLength(100, 20))
            ),
            '0,10'
        );

        assertDeepEquals(
            toStr(
                Length.lengthDiffNonNegative(
                    Length.toLength(100, 10),
                    Length.toLength(101, 20))
            ),
            '1,20'
        );

        assertDeepEquals(
            toStr(
                Length.lengthDiffNonNegative(
                    Length.toLength(101, 30),
                    Length.toLength(101, 20))
            ),
            '0,0'
        );

        assertDeepEquals(
            toStr(
                Length.lengthDiffNonNegative(
                    Length.toLength(102, 10),
                    Length.toLength(101, 20))
            ),
            '0,0'
        );
    }

}
