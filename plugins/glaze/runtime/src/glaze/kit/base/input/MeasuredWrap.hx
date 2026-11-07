// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper/wrap_width.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.LineWrapper.Boundary;

/**
 * The exact upstream break sequence plus the range over which its measured decisions hold.
 */
class MeasuredWrap {

    /** Byte offsets and continuation indentation, unchanged from the original algorithm. */
    public final boundaries:Array<Boundary>;

    /** Valid only for the same text, font, wrapping policy and inline geometry. */
    public final validWidths:WidthRange;

    public inline function new(boundaries:Array<Boundary>, validWidths:WidthRange) {
        this.boundaries = boundaries;
        this.validWidths = validWidths;
    }

    /** Preserve a result for which no measured reuse interval is available. */
    public static inline function uncached(boundaries:Array<Boundary>):MeasuredWrap {
        return new MeasuredWrap(boundaries, WidthRange.empty());
    }

}
