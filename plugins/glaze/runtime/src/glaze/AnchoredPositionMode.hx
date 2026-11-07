// Ported from gpui-pre 0.3.10: src/elements/anchored.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Which algorithm to use when positioning the anchored element.
 * Qualify the values (`AnchoredPositionMode.Window`): `Window` is also a type.
 */
enum abstract AnchoredPositionMode(Int) {

    /** Position the anchored element relative to the window. */
    var Window = 0;

    /** Position the anchored element relative to its parent. */
    var Local = 1;

}
