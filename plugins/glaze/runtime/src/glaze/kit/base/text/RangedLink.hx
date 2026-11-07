// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;

/**
 * A link over a byte range (Rust tuple `(Range<usize>, LinkMark)`).
 */
class RangedLink {

    public final range:Range;

    public final link:LinkMark;

    public inline function new(range:Range, link:LinkMark) {
        this.range = range;
        this.link = link;
    }

}
