// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * An absolute length in pixels or rems.
 *
 * Methods are provided by `AbsoluteLengthTools` (attached with `@:using`).
 *
 * Note: the constructor names `Pixels` and `Rems` shadow the unit types
 * when this module is imported explicitly. Use `import glaze.*;` and
 * qualified constructors (`AbsoluteLength.Pixels(px(1))`) instead.
 */
@:using(glaze.AbsoluteLengthTools)
enum AbsoluteLength {

    /**
     * A length in pixels.
     */
    Pixels(pixels:glaze.Pixels);

    /**
     * A length in rems.
     */
    Rems(rems:glaze.Rems);

}
