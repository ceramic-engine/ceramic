// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Geometric presentation for an editor range decoration.
 */
enum abstract RangeDecorationStyle(Int) {

    /** Fill the continuous visual range. */
    var Fill = 0;

    /** Draw a continuous one-pixel frame around the visual range (the default). */
    var Frame = 1;

    public static inline function defaultValue():RangeDecorationStyle {
        return Frame;
    }

}
