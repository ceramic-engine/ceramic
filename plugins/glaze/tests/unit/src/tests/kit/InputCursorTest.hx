// Ported from gpui-kit 0.8.1: crates/base/src/input/base/cursor.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.input.ColumnAnchor;
import gpui.base.input.CursorId;
import gpui.base.input.CursorSelection;
import gpui.base.input.LspPosition;
import gpui.base.input.Selection;
import gpui.base.input.Selections;
import testing.TestCase;

/**
 * Tests of `Selection`, `CursorSelection` and `Selections` (Rust `cursor.rs`).
 */
class InputCursorTest extends TestCase {

    function testSelectionKeepsItsPublicRangeApi() {
        // `assert_eq::<Selection>()` only checks the Eq trait: `equals` here.
        final selection = new Selection(2, 5);
        assertTrue(selection.equals(new Selection(2, 5)));
        assertEquals("2..5", selection.toRange().toString());
    }

    function testLineColumnFromTo() {
        final position = new LspPosition(1, 2);
        assertEquals(1, position.line);
        assertEquals(2, position.character);
    }

    function testCursorOffsetReversed() {
        final sel = new CursorSelection(new CursorId(0), 5, 10);
        assertEquals(10, sel.cursorOffset());
        sel.reversed = true;
        assertEquals(5, sel.cursorOffset());
    }

    function testPlaceAt() {
        final sel = new CursorSelection(new CursorId(0), 5, 10);
        sel.reversed = true;
        sel.placeAt(7, new ColumnAnchor(12., 3));
        assertEquals(7, sel.start);
        assertEquals(7, sel.end);
        assertTrue(sel.isCollapsed());
        assertFalse(sel.reversed);
        assertTrue(new ColumnAnchor(12., 3).equals(sel.columnAnchor));
    }

    function testSelectionsNeverEmpty() {
        final selections = new Selections();
        assertEquals(1, selections.len());
        assertTrue(selections.active().id == new CursorId(0));

        final defaultSelections = Selections.defaultValue();
        assertEquals(1, defaultSelections.len());
    }

    function testSelectionsActiveMut() {
        final selections = new Selections();
        selections.activeMut().placeAt(4, null);
        assertEquals(4, selections.active().cursorOffset());
    }

    function testSelectionsMergeOverlapping() {
        final selections = new Selections();

        final id1 = selections.generateId();
        final id2 = selections.generateId();
        final id3 = selections.generateId();

        // id1 is the active selection (index 0).
        selections.replaceAll([
            new CursorSelection(id1, 0, 10),
            new CursorSelection(id2, 5, 15), // Overlaps with the first.
            new CursorSelection(id3, 20, 30), // Non-overlapping.
        ]);

        selections.mergeOverlapping();

        // After merge: (0, 15) and (20, 30).
        assertEquals(2, selections.len());
        // The active selection stays at index 0 and carries its id.
        assertTrue(selections.active().id == id1);
        assertEquals(0, selections.active().start);
        assertEquals(15, selections.active().end);

        final ranges = [for (s in selections.iter()) s.start + ',' + s.end];
        assertTrue(ranges.indexOf('0,15') != -1);
        assertTrue(ranges.indexOf('20,30') != -1);
    }

    function testMergingPreservesTheActiveSelectionDirection() {
        final selections = new Selections();
        final activeId = selections.generateId();
        final otherId = selections.generateId();
        final active = new CursorSelection(activeId, 5, 15);
        active.reversed = true;
        final other = new CursorSelection(otherId, 0, 10);
        selections.replaceAll([active, other]);

        selections.mergeOverlapping();

        assertTrue(selections.active().id == activeId);
        assertTrue(selections.active().reversed);
    }

}
