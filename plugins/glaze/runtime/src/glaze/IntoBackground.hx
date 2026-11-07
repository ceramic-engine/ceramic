// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Haxe counterpart of Rust's `impl Into<Background>` arguments: accepts a
 * `Background`, an `Hsla` or an `Rgba` (converted implicitly to a solid background).
 */
@:forward
abstract IntoBackground(Background) from Background to Background {

    @:from static inline function fromHsla(color:Hsla):IntoBackground {

        return Background.fromHsla(color);

    }

    @:from static inline function fromRgba(color:Rgba):IntoBackground {

        return Background.fromRgba(color);

    }

}
