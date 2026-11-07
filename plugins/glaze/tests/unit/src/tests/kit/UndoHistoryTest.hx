// Ported from gpui-kit 0.8.1: crates/base/src/undo_history.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.UndoHistory;
import testing.TestCase;

/**
 * Tests of `gpui.base.UndoHistory` (Rust `undo_history.rs`). Transactions are
 * compared as joined strings, `null` standing for Rust's `None`.
 */
class UndoHistoryTest extends TestCase {

    static function str(changes:Null<Array<Int>>):Null<String> {
        return changes == null ? null : changes.join(',');
    }

    function testExplicitGroupingUndoesNewestFirstAndRedoesOldestFirst() {
        final history = new UndoHistory<Int>();
        history.startGrouping();
        history.push(1);
        history.push(2);
        history.push(3);
        history.endGrouping();

        assertEquals('3,2,1', str(history.undo()));
        assertEquals('1,2,3', str(history.redo()));
    }

    function testUngroupedPushesFormSeparateTransactions() {
        final history = new UndoHistory<Int>();
        history.push(1);
        history.push(2);

        assertEquals('2', str(history.undo()));
        assertEquals('1', str(history.undo()));
    }

    function testGroupIntervalCombinesImmediatePushes() {
        final history = new UndoHistory<Int>().groupInterval(60);
        history.push(1);
        history.push(2);

        assertEquals('2,1', str(history.undo()));
    }

    function testUndoBreaksTimedGroupingAcrossTheBranchBoundary() {
        var history = new UndoHistory<Int>();
        history.push(1);
        history.push(2);
        history = history.groupInterval(60);
        assertEquals('2', str(history.undo()));

        history.push(3);

        assertEquals('3', str(history.undo()));
        assertEquals('1', str(history.undo()));
    }

    function testRedoBreaksTimedGroupingAcrossTheBranchBoundary() {
        var history = new UndoHistory<Int>();
        history.push(1);
        history.push(2);
        assertEquals('2', str(history.undo()));
        assertEquals('2', str(history.redo()));
        history = history.groupInterval(60);

        history.push(3);

        assertEquals('3', str(history.undo()));
        assertEquals('2', str(history.undo()));
        assertEquals('1', str(history.undo()));
    }

    function testExplicitGroupingStillAppendsAfterUndo() {
        final history = new UndoHistory<Int>();
        history.push(1);
        history.push(2);
        assertEquals('2', str(history.undo()));

        history.startGrouping();
        history.push(3);
        history.endGrouping();

        assertEquals('3,1', str(history.undo()));
    }

    function testANewPushClearsRedo() {
        final history = new UndoHistory<Int>();
        history.push(1);
        history.push(2);
        assertEquals('2', str(history.undo()));

        history.push(3);

        assertFalse(history.canRedo());
        assertEquals(null, str(history.redo()));
    }

    function testIgnoringDropsPushes() {
        final history = new UndoHistory<Int>();
        history.setIgnoring(true);
        history.push(1);

        assertTrue(history.isIgnoring());
        assertFalse(history.canUndo());
        assertEquals(null, str(history.undo()));
    }

    function testClearClearsBothDirections() {
        final history = new UndoHistory<Int>();
        history.push(1);
        history.undo();

        history.clear();

        assertFalse(history.canUndo());
        assertFalse(history.canRedo());
    }

    function testMaxUndosEvictsTheOldestTransaction() {
        final history = new UndoHistory<Int>().maxUndos(2);
        history.push(1);
        history.push(2);
        history.push(3);

        assertEquals('3', str(history.undo()));
        assertEquals('2', str(history.undo()));
        assertEquals(null, str(history.undo()));
    }

    function testLoweringMaxUndosEvictsOldestPopulatedTransactionsImmediately() {
        var history = new UndoHistory<Int>();
        history.push(1);
        history.push(2);
        history.push(3);

        history = history.maxUndos(2);

        assertEquals('3', str(history.undo()));
        assertEquals('2', str(history.undo()));
        assertEquals(null, str(history.undo()));
    }

    function testRedoAfterLoweringMaxUndosPreservesTheCap() {
        var history = new UndoHistory<Int>();
        history.push(1);
        history.push(2);
        history.push(3);
        assertEquals('3', str(history.undo()));

        history = history.maxUndos(1);
        assertEquals('3', str(history.redo()));

        assertEquals('3', str(history.undo()));
        assertEquals(null, str(history.undo()));
    }

    function testRedoAtZeroMaxUndosKeepsTheTransactionAvailable() {
        var history = new UndoHistory<Int>();
        history.push(1);
        assertEquals('1', str(history.undo()));

        history = history.maxUndos(0);

        assertEquals(null, str(history.redo()));
        assertTrue(history.canRedo());
        history = history.maxUndos(1);
        assertEquals('1', str(history.redo()));
    }

    function testZeroMaxUndosRetainsNoTransactions() {
        final history = new UndoHistory<Int>().maxUndos(0);
        history.push(1);

        assertFalse(history.canUndo());
        assertEquals(null, str(history.undo()));
    }

}
