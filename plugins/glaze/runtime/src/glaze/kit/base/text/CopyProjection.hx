// Ported from gpui-kit 0.8.1: crates/base/src/text/selection_adapter.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Point;
import glaze.kit.base.text.BlockState.CustomBlockSelectionProjection;
import glaze.kit.base.text.Inline.InlineSelectionProjection;
import glaze.kit.base.text.InlineObject.InlineObjectSelectionProjection;

/** What one painted piece of a view projects a selection onto, for copy. */
enum CopyProjection {
    Text(projection:InlineSelectionProjection);
    InlineObject(projection:InlineObjectSelectionProjection);
    CustomBlock(projection:CustomBlockSelectionProjection);
}

class CopyProjectionTools {

    public static function reset(self:CopyProjection):Void {
        switch self {
            case Text(projection): projection.reset();
            case _:
        }
    }

    public static function project(self:CopyProjection, start:Point, end:Point):Void {
        switch self {
            case Text(projection): projection.project(start, end);
            case InlineObject(projection): projection.project(start, end);
            case CustomBlock(projection): projection.project(start, end);
        }
    }

    /** Selects nothing: the selection started in a table cell this is not in. */
    public static function deselect(self:CopyProjection):Void {
        switch self {
            case Text(projection): projection.reset();
            case InlineObject(projection): projection.deselect();
            case CustomBlock(projection): projection.deselect();
        }
    }

}
