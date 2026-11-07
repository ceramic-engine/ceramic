// Ported from gpui-kit 0.8.1: crates/base/src/input/base/undo_manager.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * What kind of edit a change is, which decides what it coalesces with.
 */
enum abstract EditIntent(Int) {
    var Typing = 0;
    var Backspace = 1;
    var DeleteForward = 2;
    var Atomic = 3;
}
