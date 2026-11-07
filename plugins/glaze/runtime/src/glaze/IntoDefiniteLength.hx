// Ported from gpui-pre 0.3.10: src/geometry.rs (`impl Into<DefiniteLength>` arguments)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Haxe counterpart of Rust's `impl Into<DefiniteLength>` arguments: accepts a
 * `DefiniteLength`, an `AbsoluteLength`, `Pixels` or `Rems`.
 * Plain numbers are taken as pixels.
 */
abstract IntoDefiniteLength(DefiniteLength) from DefiniteLength to DefiniteLength {

    @:from static inline function fromPixels(value:Pixels):IntoDefiniteLength {
        return DefiniteLength.Absolute(AbsoluteLength.Pixels(value));
    }

    @:from static inline function fromRems(value:Rems):IntoDefiniteLength {
        return DefiniteLength.Absolute(AbsoluteLength.Rems(value));
    }

    @:from static inline function fromAbsoluteLength(value:AbsoluteLength):IntoDefiniteLength {
        return DefiniteLength.Absolute(value);
    }

}
