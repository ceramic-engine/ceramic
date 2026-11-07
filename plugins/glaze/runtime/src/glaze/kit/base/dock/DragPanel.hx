// Ported from gpui-kit 0.8.1: crates/base/src/dock/drag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.Point;
import glaze.Size;

/**
 * A panel being dragged out of a tab group.
 *
 * The panel is carried as a `PanelId` rather than a view handle: the layout
 * algebra already addresses panels this way. A consumer resolves the id back
 * to a view through the dock area's panel map.
 *
 * Rust `Clone` shares the drag offset and the preview size cells
 * (`Rc<Cell<..>>`); `clone()` does the same. Rust also renders the value
 * itself as the drag view; here `DragPanelView` is that view.
 */
class DragPanel {

    static var NEXT_DRAG_SESSION_ID:Int = 1;

    final panelValue:PanelId;

    final sourceValue:NodeId;

    final cells:DragPanelCells;

    final dragSessionIdValue:Int;

    public function new(panel:PanelId, source:NodeId, ?shared:DragPanel) {
        this.panelValue = panel;
        this.sourceValue = source;
        this.cells = shared != null ? shared.cells : new DragPanelCells();
        this.dragSessionIdValue = shared != null ? shared.dragSessionIdValue : NEXT_DRAG_SESSION_ID++;
    }

    public function clone():DragPanel {
        return new DragPanel(panelValue, sourceValue, this);
    }

    public inline function panel():PanelId {
        return panelValue;
    }

    /**
     * The tab group this panel was dragged out of.
     */
    public inline function source():NodeId {
        return sourceValue;
    }

    public inline function dragOffset():Point {
        return cells.dragOffset;
    }

    /**
     * Records where inside the panel the drag started, so a preview can be
     * positioned relative to the cursor.
     */
    public inline function setDragOffset(offset:Point):Void {
        cells.dragOffset = offset;
    }

    /**
     * How large the drag preview is on screen.
     *
     * The dock reads it to decide where a drop placeholder flies in from,
     * which is hit geometry rather than styling; the skin that draws the
     * preview reports it here. Defaults to zero, which degrades to a
     * placeholder that grows out of the cursor rather than out of the preview.
     */
    public inline function previewSize():Size {
        return cells.previewSize;
    }

    public inline function setPreviewSize(size:Size):Void {
        cells.previewSize = size;
    }

    public inline function dragSessionId():Int {
        return dragSessionIdValue;
    }

}

private class DragPanelCells {

    public var dragOffset:Point = new Point(0, 0);

    public var previewSize:Size = new Size(0, 0);

    public function new() {}

}
