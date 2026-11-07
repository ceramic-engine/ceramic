// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/state.rs (the `(IndexPath, D::Item)` selection pairs)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.searchablelist;

import glaze.kit.base.IndexPath;

/**
 * One entry of a searchable list selection: the Rust tuple
 * `(IndexPath, D::Item)` of `SearchableListState.selection`.
 */
class SelectedItem<I> {

    public final index:IndexPath;

    public final item:I;

    public inline function new(index:IndexPath, item:I) {
        this.index = index;
        this.item = item;
    }

    /**
     * Rust tuple equality: same index path and same item (by value for the
     * items of `SearchableListItems.itemEquals`).
     */
    public function equals(other:SelectedItem<I>):Bool {
        return other != null && index.equals(other.index) && SearchableListItems.itemEquals(item, other.item);
    }

    public function toString():String {
        return '(' + index.toString() + ', ' + Std.string(item) + ')';
    }

}
