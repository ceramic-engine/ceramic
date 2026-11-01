// Ported from gpui-kit 0.8.1: crates/base/src/touch_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Bounds;
import gpui.Point;

/**
 * Maps a finger to the text position a handle drag selects.
 *
 * The knob a finger holds sits above or below the line, so the finger
 * itself is never over the text it moves. The offset from the finger to
 * the caret box is captured when the drag begins and kept for the rest of
 * it; the mapped point then picks lines exactly as a pointer does.
 */
class EdgeDrag {

    var _edge:SelectionEdge;

    final offset:Point;

    function new(edge:SelectionEdge, offset:Point) {
        _edge = edge;
        this.offset = offset;
    }

    public static function begin(edge:SelectionEdge, caret:Bounds, finger:Point):EdgeDrag {
        return new EdgeDrag(edge, caret.center().sub(finger));
    }

    public inline function edge():SelectionEdge {
        return _edge;
    }

    /** The finger dragged its end past the other one; it now holds that one. */
    public inline function setEdge(edge:SelectionEdge):Void {
        _edge = edge;
    }

    /** The text position the finger points at. */
    public function textPosition(finger:Point):Point {
        return new Point(finger.x + offset.x, finger.y + offset.y);
    }

}
