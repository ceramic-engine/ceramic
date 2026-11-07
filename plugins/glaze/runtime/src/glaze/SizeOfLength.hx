// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Methods that Rust defines on `Size<Length>`.
 */
class SizeOfLength {

    /**
     * A size with both width and height set to fill the available space (100%).
     */
    public static inline function full():SizeOf<Length> {

        return new SizeOf<Length>(
            Length.Definite(DefiniteLength.Fraction(1.0)),
            Length.Definite(DefiniteLength.Fraction(1.0))
        );

    }

    /**
     * A size with both width and height set to `auto`.
     */
    public static inline function auto():SizeOf<Length> {

        return new SizeOf<Length>(Length.Auto, Length.Auto);

    }

}
