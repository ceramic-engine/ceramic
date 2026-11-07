// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The value of the visibility property, similar to the CSS property `visibility`.
 */
enum abstract Visibility(Int) {

    /** The element should be drawn as normal. */
    var Visible = 0;

    /** The element should not be drawn, but should still take up space in the layout. */
    var Hidden = 1;

}
