// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * Methods that Rust defines on `Edges<Length>`.
 */
class EdgesOfLength {

    /**
     * Edges set to `auto` on every side.
     */
    public static inline function auto():EdgesOf<Length> {

        return EdgesOf.all(Length.Auto);

    }

    /**
     * Edges set to zero pixels on every side.
     */
    public static inline function zero():EdgesOf<Length> {

        return EdgesOf.all(Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(0.0))));

    }

}
