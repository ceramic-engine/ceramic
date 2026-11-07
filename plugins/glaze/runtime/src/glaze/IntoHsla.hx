// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * Haxe counterpart of Rust's `impl Into<Hsla>` arguments: accepts an `Hsla`
 * or an `Rgba` (converted implicitly).
 */
@:forward
abstract IntoHsla(Hsla) from Hsla to Hsla {

    @:from static inline function fromRgba(color:Rgba):IntoHsla {

        return Hsla.fromRgba(color);

    }

}
