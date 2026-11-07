// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Bounds;
import glaze.Point;

/** Rust `BlockSelection`. */
enum abstract BlockSelection(Int) {
    var Empty = 0;
    var Full = 1;
}

/**
 * Retained block interaction state, shared with its rendered element.
 *
 * Opaque: build one with `new BlockState()` for a `BlockNode.Custom`.
 * Rust shares it through an `Arc` on clone: in Haxe a clone of a node keeps
 * the same instance.
 */
class BlockState {

    // null is unobserved, allowing virtualized copy to include enclosed blocks.
    var selection_:Null<BlockSelection> = null;

    public function new() {}

    @:allow(glaze.kit.base.text)
    function selection():Null<BlockSelection> {
        return selection_;
    }

    @:allow(glaze.kit.base.text)
    function setSelection(value:Null<BlockSelection>):Void {
        selection_ = value;
    }

    @:allow(glaze.kit.base.text)
    function isSelected():Bool {
        return selection_ == Full;
    }

    @:allow(glaze.kit.base.text)
    function hasSelectionObservation():Bool {
        return selection_ != null;
    }

    @:allow(glaze.kit.base.text)
    function clearSelection():Void {
        setSelection(null);
    }

    /** Runtime selection does not change parsed document identity. */
    public function equals(other:Null<BlockState>):Bool {
        return other != null;
    }

    /**
     * The selection of a custom block the gesture from `start` to `end`
     * covers (Rust free `custom_block_selection`).
     */
    @:allow(glaze.kit.base.text)
    static function customBlockSelection(bounds:Bounds, start:Point, end:Point):Null<BlockSelection> {
        if (bounds.size.width <= 0 || bounds.size.height <= 0 || bounds.bottom() <= Math.min(start.y, end.y)
            || bounds.top() > Math.max(start.y, end.y)) {
            return null;
        }
        return customBlockIsSelected(bounds, start, end) ? Full : Empty;
    }

    /**
     * A block is atomic: the selection takes it whole once it crosses the
     * block's edge, and never from a gesture that stays inside it. A press
     * and release within one block is a click on its content (often an
     * interactive card) and the pointer commonly travels a few pixels during
     * a quick click, so counting that travel as a drag would paint the whole
     * block as selected.
     */
    @:allow(glaze.kit.base.text)
    static function customBlockIsSelected(bounds:Bounds, start:Point, end:Point):Bool {
        final startInside = bounds.contains(start);
        final endInside = bounds.contains(end);
        return !start.equals(end) && !(startInside && endInside)
            && (startInside || endInside || Inline.pointInTextSelection(bounds.origin, bounds.size.width, start, end, bounds.size.height));
    }

}

/**
 * Projects a gesture onto a custom block for copy (Rust
 * `CustomBlockSelectionProjection`).
 */
class CustomBlockSelectionProjection {

    final state:BlockState;
    final bounds:Bounds;

    @:allow(glaze.kit.base.text)
    function new(state:BlockState, bounds:Bounds) {
        this.state = state;
        this.bounds = bounds;
    }

    public function project(start:Point, end:Point):Void {
        state.setSelection(BlockState.customBlockSelection(bounds, start, end));
    }

    public function deselect():Void {
        state.setSelection(null);
    }

}
