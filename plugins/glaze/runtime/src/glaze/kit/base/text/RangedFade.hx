// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;

/**
 * A fade-out factor over a byte range (Rust tuple `(Range<usize>, f32)`).
 */
class RangedFade {

    public final range:Range;

    public final fadeOut:Float;

    public inline function new(range:Range, fadeOut:Float) {
        this.range = range;
        this.fadeOut = fadeOut;
    }

}
