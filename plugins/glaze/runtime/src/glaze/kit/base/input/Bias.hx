// Ported from gpui-pre-sum-tree 0.3.10: src/sum_tree.rs (Bias only, the only part of sum_tree gpui-kit uses)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Which side of a position to attach to when it falls inside something
 * indivisible (a multi-byte character, a fold, a token).
 */
enum abstract Bias(Int) {

    /** Attach to the character on the left (the default). */
    var Left = 0;

    /** Attach to the character on the right. */
    var Right = 1;

    public inline function invert():Bias {
        return this == 0 ? Right : Left;
    }

}
