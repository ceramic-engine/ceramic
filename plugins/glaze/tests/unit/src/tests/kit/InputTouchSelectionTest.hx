// Ported from gpui-kit 0.8.1: crates/base/src/touch_selection.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Bounds;
import glaze.Point;
import glaze.Size;
import glaze.kit.base.input.EdgeDrag;
import glaze.kit.base.input.SelectionEdge;
import glaze.kit.base.input.TouchSelectionSnapshot;
import testing.TestCase;

/**
 * Tests of the touch selection geometry (Rust `touch_selection.rs`), which
 * the input engine's touch selection uses.
 */
class InputTouchSelectionTest extends TestCase {

    function testSnapshotReportsBoundsAndEdges() {
        final start = TouchSelectionSnapshot.caretLineBox(new Point(10., 20.), 16.);
        final end = TouchSelectionSnapshot.caretLineBox(new Point(80., 52.), 16.);
        final snapshot = TouchSelectionSnapshot.create(start, end).withMenuOpen(true).withDragging(SelectionEdge.End);

        assertTrue(start.equals(snapshot.edge(SelectionEdge.Start)));
        assertTrue(end.equals(snapshot.edge(SelectionEdge.End)));
        assertFalse(snapshot.isEmpty());
        assertTrue(snapshot.isMenuOpen());
        assertEquals(SelectionEdge.End, snapshot.dragging());
        assertTrue(Bounds.fromCorners(new Point(10., 20.), new Point(80., 68.)).equals(snapshot.bounds()));

        final caret = TouchSelectionSnapshot.create(start, start);
        assertTrue(caret.isEmpty());
    }

    function testAScrolledAwayEndKeepsItsGeometryButNoHandle() {
        final start = TouchSelectionSnapshot.caretLineBox(new Point(10., -30.), 16.);
        final end = TouchSelectionSnapshot.caretLineBox(new Point(80., 52.), 16.);
        final viewport = new Bounds(new Point(0., 0.), new Size(200., 100.));
        assertFalse(TouchSelectionSnapshot.caretInView(start, viewport));
        assertTrue(TouchSelectionSnapshot.caretInView(end, viewport));

        final snapshot = TouchSelectionSnapshot.create(start, end).withEdgeVisible(SelectionEdge.Start, false);
        assertFalse(snapshot.isEdgeVisible(SelectionEdge.Start));
        assertTrue(start.equals(snapshot.edge(SelectionEdge.Start)));
        assertTrue(end.equals(snapshot.bounds()));

        final gone = snapshot.withEdgeVisible(SelectionEdge.End, false);
        assertNull(gone.bounds());
    }

    function testEdgeDragKeepsTheFingerOffset() {
        final caret = TouchSelectionSnapshot.caretLineBox(new Point(100., 40.), 20.);
        final drag = EdgeDrag.begin(SelectionEdge.End, caret, new Point(102., 72.));
        assertEquals(SelectionEdge.End, drag.edge());
        // The finger started 22px below the caret's center; it stays there.
        assertTrue(new Point(148., 68.).equals(drag.textPosition(new Point(150., 90.))));
    }

}
