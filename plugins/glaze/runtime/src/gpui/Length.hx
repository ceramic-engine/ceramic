// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * A length that can be defined in pixels, rems, percent of parent, or auto.
 *
 * Methods are provided by `LengthTools` (attached with `@:using`).
 */
@:using(gpui.LengthTools)
enum Length {

    /**
     * A definite length specified either in pixels, rems, or as a fraction of the parent's size.
     */
    Definite(length:DefiniteLength);

    /**
     * An automatic length that is determined by the context in which it is used.
     */
    Auto;

}
