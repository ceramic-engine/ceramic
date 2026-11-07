// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * A color space for color interpolation.
 *
 * References:
 * - https://developer.mozilla.org/en-US/docs/Web/CSS/color-interpolation-method
 * - https://www.w3.org/TR/css-color-4/#typedef-color-space
 */
enum abstract ColorSpace(Int) to Int {

    /**
     * The sRGB color space (default).
     */
    var Srgb = 0;

    /**
     * The Oklab color space.
     */
    var Oklab = 1;

    public function toString():String {

        return this == Oklab ? 'Oklab' : 'sRGB';

    }

}
