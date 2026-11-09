// Ported from vscode src/vs/editor/test/common/viewModel/prefixSumComputer.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.viewModel;

import cityscape.common.model.PrefixSumComputer;
import testing.TestCase;

/**
 * suite('Editor ViewModel - PrefixSumComputer')
 *
 * `toUint32Array([...])` is the array itself (`PrefixSumComputer` takes
 * an `Array<Int>`).
 */
class PrefixSumComputerTest extends TestCase {

    function testPrefixSumComputer() {
        var indexOfResult:PrefixSumIndexOfResult;

        final psc = new PrefixSumComputer([1, 1, 2, 1, 3]);
        assertEquals(psc.getTotalSum(), 8);
        assertEquals(psc.getPrefixSum(-1), 0);
        assertEquals(psc.getPrefixSum(0), 1);
        assertEquals(psc.getPrefixSum(1), 2);
        assertEquals(psc.getPrefixSum(2), 4);
        assertEquals(psc.getPrefixSum(3), 5);
        assertEquals(psc.getPrefixSum(4), 8);
        indexOfResult = psc.getIndexOf(0);
        assertEquals(indexOfResult.index, 0);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(1);
        assertEquals(indexOfResult.index, 1);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(2);
        assertEquals(indexOfResult.index, 2);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(3);
        assertEquals(indexOfResult.index, 2);
        assertEquals(indexOfResult.remainder, 1);
        indexOfResult = psc.getIndexOf(4);
        assertEquals(indexOfResult.index, 3);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(5);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(6);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 1);
        indexOfResult = psc.getIndexOf(7);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 2);
        indexOfResult = psc.getIndexOf(8);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 3);

        // [1, 2, 2, 1, 3]
        psc.setValue(1, 2);
        assertEquals(psc.getTotalSum(), 9);
        assertEquals(psc.getPrefixSum(0), 1);
        assertEquals(psc.getPrefixSum(1), 3);
        assertEquals(psc.getPrefixSum(2), 5);
        assertEquals(psc.getPrefixSum(3), 6);
        assertEquals(psc.getPrefixSum(4), 9);

        // [1, 0, 2, 1, 3]
        psc.setValue(1, 0);
        assertEquals(psc.getTotalSum(), 7);
        assertEquals(psc.getPrefixSum(0), 1);
        assertEquals(psc.getPrefixSum(1), 1);
        assertEquals(psc.getPrefixSum(2), 3);
        assertEquals(psc.getPrefixSum(3), 4);
        assertEquals(psc.getPrefixSum(4), 7);
        indexOfResult = psc.getIndexOf(0);
        assertEquals(indexOfResult.index, 0);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(1);
        assertEquals(indexOfResult.index, 2);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(2);
        assertEquals(indexOfResult.index, 2);
        assertEquals(indexOfResult.remainder, 1);
        indexOfResult = psc.getIndexOf(3);
        assertEquals(indexOfResult.index, 3);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(4);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(5);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 1);
        indexOfResult = psc.getIndexOf(6);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 2);
        indexOfResult = psc.getIndexOf(7);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 3);

        // [1, 0, 0, 1, 3]
        psc.setValue(2, 0);
        assertEquals(psc.getTotalSum(), 5);
        assertEquals(psc.getPrefixSum(0), 1);
        assertEquals(psc.getPrefixSum(1), 1);
        assertEquals(psc.getPrefixSum(2), 1);
        assertEquals(psc.getPrefixSum(3), 2);
        assertEquals(psc.getPrefixSum(4), 5);
        indexOfResult = psc.getIndexOf(0);
        assertEquals(indexOfResult.index, 0);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(1);
        assertEquals(indexOfResult.index, 3);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(2);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(3);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 1);
        indexOfResult = psc.getIndexOf(4);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 2);
        indexOfResult = psc.getIndexOf(5);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 3);

        // [1, 0, 0, 0, 3]
        psc.setValue(3, 0);
        assertEquals(psc.getTotalSum(), 4);
        assertEquals(psc.getPrefixSum(0), 1);
        assertEquals(psc.getPrefixSum(1), 1);
        assertEquals(psc.getPrefixSum(2), 1);
        assertEquals(psc.getPrefixSum(3), 1);
        assertEquals(psc.getPrefixSum(4), 4);
        indexOfResult = psc.getIndexOf(0);
        assertEquals(indexOfResult.index, 0);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(1);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(2);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 1);
        indexOfResult = psc.getIndexOf(3);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 2);
        indexOfResult = psc.getIndexOf(4);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 3);

        // [1, 1, 0, 1, 1]
        psc.setValue(1, 1);
        psc.setValue(3, 1);
        psc.setValue(4, 1);
        assertEquals(psc.getTotalSum(), 4);
        assertEquals(psc.getPrefixSum(0), 1);
        assertEquals(psc.getPrefixSum(1), 2);
        assertEquals(psc.getPrefixSum(2), 2);
        assertEquals(psc.getPrefixSum(3), 3);
        assertEquals(psc.getPrefixSum(4), 4);
        indexOfResult = psc.getIndexOf(0);
        assertEquals(indexOfResult.index, 0);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(1);
        assertEquals(indexOfResult.index, 1);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(2);
        assertEquals(indexOfResult.index, 3);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(3);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 0);
        indexOfResult = psc.getIndexOf(4);
        assertEquals(indexOfResult.index, 4);
        assertEquals(indexOfResult.remainder, 1);
    }

}
