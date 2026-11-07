// Ported from gpui-pre 0.3.10: src/colors.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * The appearance of the base GPUI colors, used to style GPUI elements.
 */
enum abstract DefaultAppearance(Int) {

    /**
     * Use the set of colors for light appearances (default).
     */
    var Light = 0;

    /**
     * Use the set of colors for dark appearances.
     */
    var Dark = 1;

}
