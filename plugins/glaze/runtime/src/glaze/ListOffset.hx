// Ported from gpui-pre 0.3.10: src/elements/list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An offset into the list's items, in terms of the item index and the number
 * of pixels off the top left of the item.
 *
 * Immutable (Rust mutates its `Copy` value in place: here a new one is built).
 */
class ListOffset {

    /** The index of an item in the list. */
    public final itemIx:Int;

    /** The number of pixels to offset from the item index. */
    public final offsetInItem:Float;

    public inline function new(itemIx:Int = 0, offsetInItem:Float = 0.0) {
        this.itemIx = itemIx;
        this.offsetInItem = offsetInItem;
    }

    public inline function equals(other:ListOffset):Bool {
        return other != null && itemIx == other.itemIx && offsetInItem == other.offsetInItem;
    }

    public function toString():String {
        return 'ListOffset(itemIx: ' + itemIx + ', offsetInItem: ' + offsetInItem + ')';
    }

}
