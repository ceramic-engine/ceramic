// Ported from gpui-pre 0.3.10: src/geometry.rs (`impl Into<AbsoluteLength>` arguments)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Haxe counterpart of Rust's `impl Into<AbsoluteLength>` arguments: accepts
 * an `AbsoluteLength`, `Pixels` or `Rems`. Plain numbers are taken as pixels.
 */
abstract IntoAbsoluteLength(AbsoluteLength) from AbsoluteLength to AbsoluteLength {

    @:from static inline function fromPixels(value:Pixels):IntoAbsoluteLength {
        return AbsoluteLength.Pixels(value);
    }

    @:from static inline function fromRems(value:Rems):IntoAbsoluteLength {
        return AbsoluteLength.Rems(value);
    }

}
