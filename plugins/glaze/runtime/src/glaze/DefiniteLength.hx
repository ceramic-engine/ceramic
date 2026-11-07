// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * A non-auto length that can be defined in pixels, rems, or percent of parent.
 *
 * Methods are provided by `DefiniteLengthTools` (attached with `@:using`).
 */
@:using(glaze.DefiniteLengthTools)
enum DefiniteLength {

    /**
     * An absolute length specified in pixels or rems.
     */
    Absolute(length:AbsoluteLength);

    /**
     * A relative length specified as a fraction of the parent's size, between 0 and 1.
     */
    Fraction(fraction:Float);

}
