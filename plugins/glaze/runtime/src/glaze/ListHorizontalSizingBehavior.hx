// Ported from gpui-pre 0.3.10: src/elements/list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The horizontal sizing behavior to apply during layout.
 */
enum abstract ListHorizontalSizingBehavior(Int) {

    /** List items' width can never exceed the width of the list (default). */
    var FitList = 0;

    /** List items' width may go over the width of the list, if any item is wider. */
    var Unconstrained = 1;

}
