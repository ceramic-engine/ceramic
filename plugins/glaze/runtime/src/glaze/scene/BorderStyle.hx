// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package gpui.scene;

/**
 * Style of a quad border.
 */
enum abstract BorderStyle(Int) from Int to Int {

    var Solid = 0;

    var Dashed = 1;

}
