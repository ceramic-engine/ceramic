// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Range;

/**
 * A text mark over a byte range (Rust tuple `(Range<usize>, TextMark)`).
 */
class RangedMark {

    public final range:Range;

    public final mark:TextMark;

    public inline function new(range:Range, mark:TextMark) {
        this.range = range;
        this.mark = mark;
    }

}
