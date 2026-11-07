// Ported from gpui-pre 0.3.10: src/elements/list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The sizing behavior to apply during layout.
 */
enum abstract ListSizingBehavior(Int) {

    /** The list should calculate its size based on the size of its items. */
    var Infer = 0;

    /** The list should not calculate a fixed size (default). */
    var Auto = 1;

}
