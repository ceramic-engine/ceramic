// Ported from gpui-kit 0.8.1: crates/base/src/input/base/undo_manager.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.input.Change;
import gpui.base.input.Selection;
import gpui.base.input.UndoManager;
import gpui.util.Utf8;
import testing.TestCase;

/**
 * Tests of `gpui.base.input.UndoManager` (Rust `undo_manager.rs`).
 */
class InputUndoManagerTest extends TestCase {

    static function typingChange(offset:Int, text:String):Change {
        final end = offset + Utf8.byteLength(text);
        return new Change(new Selection(offset, offset), "", new Selection(offset, end), text);
    }

    static function same(expected:Array<Change>, actual:Array<Change>):Bool {
        if (expected.length != actual.length) return false;
        for (i in 0...expected.length) if (!expected[i].equals(actual[i])) return false;
        return true;
    }

    static function repeat(s:String, n:Int):String {
        final buf = new StringBuf();
        for (_ in 0...n) buf.add(s);
        return buf.toString();
    }

    function testAdjacentTypingTransactionsCoalesce() {
        final manager = new UndoManager();
        manager.recordTransaction(typingChange(0, "a"), Typing);
        manager.recordTransaction(typingChange(1, "b"), Typing);

        // The run is kept as one insertion, so undo replays a single change.
        assertTrue(same([typingChange(0, "ab")], manager.undo().changes));
        assertNull(manager.undo());
    }

    function testExplicitTransactionCollectsMultipleChanges() {
        final manager = new UndoManager();
        manager.beginTransaction();
        manager.recordTransaction(typingChange(0, "a"), Typing);
        manager.recordTransaction(typingChange(1, "b"), Typing);
        manager.commitTransaction();

        // One undo entry that replays its changes in reverse application order.
        final transaction = manager.undo().changes;
        assertEquals(2, transaction.length);
        assertEquals("b", transaction[0].newText);
        assertEquals("a", transaction[1].newText);
        assertNull(manager.undo());
    }

    function testNestedTransactionsCommitAsOneEntry() {
        final manager = new UndoManager();
        manager.beginTransaction();
        manager.recordTransaction(typingChange(0, "a"), Typing);
        manager.beginTransaction();
        manager.recordTransaction(typingChange(1, "b"), Typing);
        manager.commitTransaction();
        // The inner bracket does not close the transaction.
        assertFalse(manager.hasUndos());
        manager.recordTransaction(typingChange(2, "c"), Typing);
        manager.commitTransaction();

        assertEquals(3, manager.undo().changes.length);
        assertNull(manager.undo());
    }

    function testBatchesOfTheSameShapeAndIntentCoalesce() {
        final manager = new UndoManager();

        // Two cursors typing "a" then "b", as a multi-cursor keystroke burst.
        // A batch applies from the highest offset down, and the second burst
        // sees the offsets the first one left behind.
        manager.beginTransactionWith(Typing);
        manager.recordTransaction(typingChange(5, "a"), Typing);
        manager.recordTransaction(typingChange(0, "a"), Typing);
        manager.commitTransaction();
        manager.beginTransactionWith(Typing);
        manager.recordTransaction(typingChange(7, "b"), Typing);
        manager.recordTransaction(typingChange(1, "b"), Typing);
        manager.commitTransaction();

        assertEquals(4, manager.undo().changes.length);
        assertNull(manager.undo());
    }

    function testABatchDoesNotCoalesceIntoADifferentlyShapedOne() {
        final manager = new UndoManager();

        manager.beginTransactionWith(Typing);
        manager.recordTransaction(typingChange(5, "a"), Typing);
        manager.recordTransaction(typingChange(0, "a"), Typing);
        manager.commitTransaction();
        // One cursor left: a single change cannot continue a two-cursor batch.
        manager.recordTransaction(typingChange(1, "b"), Typing);

        assertEquals(1, manager.undo().changes.length);
        assertEquals(2, manager.undo().changes.length);
    }

    function testAnAtomicBatchNeverCoalesces() {
        final manager = new UndoManager();

        manager.beginTransaction();
        manager.recordTransaction(typingChange(0, "a"), Typing);
        manager.commitTransaction();
        manager.recordTransaction(typingChange(1, "b"), Typing);

        assertEquals(1, manager.undo().changes.length);
        assertEquals(1, manager.undo().changes.length);
    }

    function testLimitsTheNumberOfRetainedTransactions() {
        final manager = new UndoManager();

        for (offset in 0...1100) {
            manager.recordTransaction(typingChange(offset, "a"), Atomic);
        }

        for (_ in 0...UndoManager.MAX_UNDO_TRANSACTIONS) {
            assertTrue(manager.undo() != null);
        }
        assertNull(manager.undo());
    }

    function testSplitsACoalescedTransactionBeforeItsChangeListGrowsTooLarge() {
        final manager = new UndoManager();

        for (offset in 0...1100) {
            manager.recordTransaction(typingChange(offset, "a"), Typing);
        }

        // Each run is merged into one insertion, but the split still happens
        // after the same number of keystrokes.
        assertTrue(same([typingChange(UndoManager.MAX_CHANGES_PER_TRANSACTION, repeat("a", 100))], manager.undo().changes));
        assertTrue(same([typingChange(0, repeat("a", UndoManager.MAX_CHANGES_PER_TRANSACTION))], manager.undo().changes));
        assertNull(manager.undo());
    }

}
