// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * How to handle whitespace in text.
 */
enum abstract WhiteSpace(Int) {

    /** Normal line wrapping when text overflows the width of the element */
    var Normal = 0;

    /** No line wrapping, text will overflow the width of the element */
    var Nowrap = 1;

}
