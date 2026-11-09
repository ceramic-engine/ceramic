// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/smallImmutableSet.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;

import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import testing.TestCase;

/**
 * suite('Bracket Pair Colorizer - ImmutableSet')
 */
class SmallImmutableSetTest extends TestCase {

    function testBasic() {
        final keyProvider = new DenseKeyProvider<String>();

        final empty = SmallImmutableSet.getEmpty();
        final items1 = empty.add('item1', keyProvider);
        final items12 = items1.add('item2', keyProvider);
        final items2 = empty.add('item2', keyProvider);
        final items21 = items2.add('item1', keyProvider);

        final items3 = empty.add('item3', keyProvider);

        assertEquals(items12.intersects(items1), true);
        assertEquals(items12.has('item1', keyProvider), true);

        assertEquals(items12.intersects(items3), false);
        assertEquals(items12.has('item3', keyProvider), false);

        assertEquals(items21.equals(items12), true);
        assertEquals(items21.equals(items2), false);
    }

    function testManyElements() {
        final keyProvider = new DenseKeyProvider<String>();

        var set:SmallImmutableSet<String> = SmallImmutableSet.getEmpty();

        for (i in 0...100) {
            keyProvider.getKey('item' + i);
            if (i % 2 == 0) {
                set = set.add('item' + i, keyProvider);
            }
        }

        for (i in 0...100) {
            assertEquals(set.has('item' + i, keyProvider), i % 2 == 0);
        }
    }

}
