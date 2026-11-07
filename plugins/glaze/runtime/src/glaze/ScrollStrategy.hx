// Ported from gpui-pre 0.3.10: src/elements/uniform_list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Where to place the element scrolled to (`UniformListScrollHandle.scrollToItem`).
 */
enum abstract ScrollStrategy(Int) {

    /** Place the element at the top of the list's viewport. */
    var Top = 0;

    /**
     * Attempt to place the element in the middle of the list's viewport.
     * May not be possible if there's not enough list items above the item scrolled to:
     * in this case, the element will be placed at the closest possible position.
     */
    var Center = 1;

    /**
     * Attempt to place the element at the bottom of the list's viewport.
     * May not be possible if there's not enough list items above the item scrolled to:
     * in this case, the element will be placed at the closest possible position.
     */
    var Bottom = 2;

    /**
     * If the element is not visible attempt to place it at:
     * - the top of the list's viewport if the target element is above currently visible elements;
     * - the bottom of the list's viewport if the target element is below currently visible elements.
     */
    var Nearest = 3;

}
