package tests;

import ceramic.GenericIntMap;
import testing.TestCase;

/**
 * Tests of `ceramic.GenericIntMap`, the `@:generic` integer map used by
 * Glaze's glyph cache: same answers as `haxe.ds.IntMap` for every operation,
 * key 0 and negative keys included, through growth and removals.
 */
class CeramicGenericIntMapTest extends TestCase {

    function testGetSetExistsRemove() {

        final map = new GenericIntMap<GenericIntMapValue>();
        final a = new GenericIntMapValue(1);
        final b = new GenericIntMapValue(2);
        assertEquals(0, map.size);
        assertEquals(null, map.get(5));
        assertFalse(map.exists(5));
        map.set(5, a);
        map.set(-7, b);
        assertEquals(2, map.size);
        assertEquals(a, map.get(5));
        assertEquals(b, map.get(-7));
        assertTrue(map.exists(-7));
        map.set(5, b);
        assertEquals(2, map.size, 'replacing a value keeps the size');
        assertEquals(b, map.get(5));
        assertTrue(map.remove(5));
        assertFalse(map.remove(5));
        assertEquals(1, map.size);
        assertEquals(null, map.get(5));
        assertFalse(map.exists(5));
        assertEquals(b, map.get(-7));

    }

    function testKeyZero() {

        final map = new GenericIntMap<GenericIntMapValue>();
        final a = new GenericIntMapValue(1);
        assertFalse(map.exists(0));
        assertEquals(null, map.get(0));
        map.set(0, a);
        assertTrue(map.exists(0));
        assertEquals(a, map.get(0));
        assertEquals(1, map.size);
        assertEquals(1, map.keysArray().length);
        assertTrue(map.remove(0));
        assertFalse(map.remove(0));
        assertFalse(map.exists(0));
        assertEquals(0, map.size);

    }

    function testNullValues() {

        final map = new GenericIntMap<GenericIntMapValue>();
        map.set(3, null);
        map.set(0, null);
        assertTrue(map.exists(3));
        assertTrue(map.exists(0));
        assertEquals(null, map.get(3));
        assertEquals(2, map.size);
        assertTrue(map.remove(3));
        assertEquals(1, map.size);

    }

    function testSameAnswersAsIntMapThroughGrowthAndRemovals() {

        final map = new GenericIntMap<GenericIntMapValue>(2);
        final reference = new haxe.ds.IntMap<GenericIntMapValue>();
        var referenceSize = 0;
        var seed = 12345;
        inline function next():Int {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            return seed;
        }
        for (step in 0...20000) {
            final r = next();
            // Keys collide a lot (small range, negative ones, 0, and keys
            // equal modulo powers of two) so that probing and the backward
            // shift on removal are exercised.
            final key = ((r >> 4) % 600 - 300) * ((r & 1) == 0 ? 1 : 1024);
            if ((r & 6) != 0) {
                final value = new GenericIntMapValue(step);
                if (!reference.exists(key))
                    referenceSize++;
                reference.set(key, value);
                map.set(key, value);
            }
            else {
                final removed = reference.remove(key);
                if (removed)
                    referenceSize--;
                assertEquals(removed, map.remove(key));
            }
            if (step % 1000 == 0) {
                for (k in -300...300) {
                    assertEquals(reference.get(k), map.get(k));
                    assertEquals(reference.get(k * 1024), map.get(k * 1024));
                    assertEquals(reference.exists(k), map.exists(k));
                }
            }
        }
        assertEquals(referenceSize, map.size);
        var count = 0;
        for (k in reference.keys()) {
            assertEquals(reference.get(k), map.get(k));
            count++;
        }
        assertEquals(count, map.keysArray().length);

    }

    function testClearAndCopy() {

        final map = new GenericIntMap<GenericIntMapValue>();
        final a = new GenericIntMapValue(1);
        for (i in 0...100)
            map.set(i * 3, a);
        map.set(0, a);
        final copy = map.copy();
        map.clear();
        assertEquals(0, map.size);
        assertFalse(map.exists(0));
        assertFalse(map.exists(3));
        assertEquals(null, map.get(3));
        assertEquals(100, copy.size);
        assertEquals(a, copy.get(297));
        assertEquals(a, copy.get(0));
        map.set(3, a);
        assertFalse(copy.exists(1), 'the copy does not share its table');
        assertEquals(1, map.size);

    }

    function testIteration() {

        final map = new GenericIntMap<String>();
        map.set(4, 'four');
        map.set(0, 'zero');
        map.set(-2, 'minus two');
        final keys = map.keysArray();
        keys.sort((a, b) -> a - b);
        assertEquals('-2,0,4', keys.join(','));
        final values = [for (v in map) v];
        values.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        assertEquals('four,minus two,zero', values.join(','));
        var sum = 0;
        for (k => v in map) {
            assertEquals(map.get(k), v);
            sum += k;
        }
        assertEquals(2, sum);
        var keyCount = 0;
        for (_ in map.keys())
            keyCount++;
        assertEquals(3, keyCount);

    }

    function testBasicValueType() {

        final map = new GenericIntMap<Int>();
        map.set(1, 10);
        map.set(2, 0);
        assertEquals(10, map.get(1));
        assertEquals(0, map.get(2));
        assertEquals(null, map.get(3));
        assertTrue(map.exists(2));

    }

}

private class GenericIntMapValue {

    public final id:Int;

    public function new(id:Int) {
        this.id = id;
    }

}
