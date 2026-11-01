// Ported from gpui-kit 0.8.1: crates/base/src/history.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.History;
import testing.TestCase;

/**
 * Tests of `gpui.base.History` (Rust `history.rs`).
 */
class HistoryTest extends TestCase {

    static function list(values:Iterable<Int>):String {
        return [for (value in values) value].join(',');
    }

    static function reversed(values:Iterable<Int>):String {
        final result = [for (value in values) value];
        result.reverse();
        return result.join(',');
    }

    function testNavigationMovesBetweenEntriesWithoutBackingPastTheRoot() {
        final history = new History<Int>().maxEntries(3);
        history.push(1);
        history.push(2);
        history.push(3);

        assertEquals(3, history.current());
        assertEquals(2, history.back());
        assertEquals(1, history.back());
        assertEquals(null, history.back());
        assertEquals(2, history.forward());
        assertEquals('1,2', list(history.entries()));
        assertEquals('2,1', reversed(history.entries()));
        assertEquals('3', list(history.forwardEntries()));
        assertTrue(history.canBack());
        assertTrue(history.canForward());
    }

    function testPushingAfterBackTruncatesTheForwardBranch() {
        final history = new History<Int>();
        history.push(1);
        history.push(2);
        history.push(3);
        assertEquals(2, history.back());

        history.push(4);

        assertEquals('1,2,4', list(history.entries()));
        assertFalse(history.canForward());
        assertEquals(null, history.forward());
    }

    function testRepeatedEntriesPreserveEveryNavigationStep() {
        final history = new History<Int>();
        history.push(1);
        history.push(2);
        history.push(1);

        assertEquals('1,2,1', list(history.entries()));
        assertEquals(2, history.back());
        assertEquals(1, history.back());
    }

    function testMaxEntriesEvictsTheOldestEntry() {
        final history = new History<Int>().maxEntries(2);
        history.push(1);
        history.push(2);
        history.push(3);

        assertEquals('2,3', list(history.entries()));
        assertEquals(2, history.back());
        assertEquals(null, history.back());
    }

    function testLoweringMaxEntriesTruncatesPopulatedEntriesAndCapsForwardRestores() {
        var history = new History<Int>();
        history.push(1);
        history.push(2);
        history.push(3);
        assertEquals(2, history.back());

        history = history.maxEntries(1);

        assertEquals('2', list(history.entries()));
        assertEquals(3, history.forward());
        assertEquals('3', list(history.entries()));
        assertEquals(null, history.back());
    }

    function testZeroMaxEntriesRetainsNothing() {
        final history = new History<Int>().maxEntries(0);
        history.push(1);

        assertEquals(null, history.current());
        assertEquals(0, history.entries().length);
        assertFalse(history.canBack());
        assertFalse(history.canForward());
    }

    function testReplaceCurrentUpdatesInPlaceAndPushesWhenEmpty() {
        final history = new History<Int>();
        history.replaceCurrent(1);
        history.push(2);
        history.replaceCurrent(3);

        assertEquals('1,3', list(history.entries()));
    }

    function testRemoveCurrentPreservesForwardEntries() {
        final history = new History<Int>();
        history.push(1);
        history.push(2);
        history.push(3);
        assertEquals(2, history.back());

        assertEquals(2, history.removeCurrent());

        assertEquals(1, history.current());
        assertEquals('3', list(history.forwardEntries()));
        assertEquals(3, history.forward());
    }

    function testRetainFiltersBackAndForwardEntriesWithoutReordering() {
        final history = new History<Int>();
        for (entry in 1...9) {
            history.push(entry);
        }
        history.back();
        history.back();
        history.back();
        history.back();

        history.retain(entry -> entry % 2 == 0);

        assertEquals('2,4', list(history.entries()));
        assertEquals('6,8', list(history.forwardEntries()));
        assertEquals(6, history.forward());
        assertEquals(8, history.forward());
    }

    function testClearRemovesBackAndForwardEntries() {
        final history = new History<Int>();
        history.push(1);
        history.push(2);
        history.back();

        history.clear();

        assertEquals(null, history.current());
        assertEquals(0, history.entries().length);
        assertEquals(0, history.forwardEntries().length);
        assertFalse(history.canBack());
        assertFalse(history.canForward());
    }

}
