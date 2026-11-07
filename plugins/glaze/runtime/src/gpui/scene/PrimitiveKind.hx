// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package gpui.scene;

/**
 * Kinds of scene primitives. The integer values give the tie-break order
 * between kinds sharing the same draw order (same as the Rust enum order).
 */
enum abstract PrimitiveKind(Int) from Int to Int {

    var Shadow = 0;

    var Quad = 1;

    var Path = 2;

    var Underline = 3;

    var MonochromeSprite = 4;

    var SubpixelSprite = 5;

    var PolychromeSprite = 6;

    var Surface = 7;

}
