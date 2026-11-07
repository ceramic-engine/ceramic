// Ported from gpui-pre 0.3.10: src/geometry.rs (`impl Into<Length>` arguments)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Haxe counterpart of Rust's `impl Into<Length>` arguments: accepts a
 * `Length`, a `DefiniteLength`, an `AbsoluteLength`, `Pixels` or `Rems`.
 * Plain numbers are taken as pixels.
 */
abstract IntoLength(Length) from Length to Length {

    @:from static inline function fromPixels(value:Pixels):IntoLength {
        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(value)));
    }

    @:from static inline function fromRems(value:Rems):IntoLength {
        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(value)));
    }

    @:from static inline function fromAbsoluteLength(value:AbsoluteLength):IntoLength {
        return Length.Definite(DefiniteLength.Absolute(value));
    }

    @:from static inline function fromDefiniteLength(value:DefiniteLength):IntoLength {
        return Length.Definite(value);
    }

}
