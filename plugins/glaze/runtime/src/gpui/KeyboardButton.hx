// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An enum representing the keyboard button that was pressed for a click event.
 */
enum abstract KeyboardButton(Int) {

    /** Enter key was clicked */
    var Enter = 0;

    /** Space key was clicked */
    var Space = 1;

}
