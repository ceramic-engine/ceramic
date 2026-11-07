// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The style of a font.
 */
enum abstract FontStyle(Int) {

    /** A face that is neither italic not obliqued. */
    var Normal = 0;

    /** A form that is generally cursive in nature. */
    var Italic = 1;

    /** A typically-sloped version of the regular face. */
    var Oblique = 2;

}
