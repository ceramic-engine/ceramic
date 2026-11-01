// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;

/**
 * An inline highlight over a byte range (Rust tuple `(Range<usize>, InlineHighlight)`).
 */
class RangedHighlight {

    public final range:Range;

    public final highlight:InlineHighlight;

    public inline function new(range:Range, highlight:InlineHighlight) {
        this.range = range;
        this.highlight = highlight;
    }

}
