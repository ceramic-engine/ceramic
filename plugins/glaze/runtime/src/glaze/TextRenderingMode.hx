// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * How glyphs are rasterized (Rust `TextRenderingMode`, defined in `platform.rs`).
 * The Ceramic text system always recommends `Grayscale`: subpixel (LCD)
 * rendering is not supported by the scene renderer.
 */
enum abstract TextRenderingMode(Int) {

    /** Use the platform's default rendering mode. */
    var PlatformDefault = 0;

    /** Use subpixel (ClearType-style) anti-aliasing. */
    var Subpixel = 1;

    /** Use grayscale anti-aliasing. */
    var Grayscale = 2;

}
