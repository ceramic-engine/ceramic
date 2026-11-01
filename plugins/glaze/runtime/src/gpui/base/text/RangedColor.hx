// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Hsla;
import gpui.Range;

/**
 * A background color over a byte range (Rust tuple `(Range<usize>, Hsla)`).
 */
class RangedColor {

    public final range:Range;

    public final color:Hsla;

    public inline function new(range:Range, color:Hsla) {
        this.range = range;
        this.color = color;
    }

}
