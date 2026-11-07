// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * How to align text within the element.
 */
enum abstract TextAlign(Int) {

    /** Align the text to the left of the element */
    var Left = 0;

    /** Center the text within the element */
    var Center = 1;

    /** Align the text to the right of the element */
    var Right = 2;

}
