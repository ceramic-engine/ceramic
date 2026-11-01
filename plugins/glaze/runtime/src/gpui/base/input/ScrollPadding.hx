// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (`ScrollPadding`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Vertical clearance to retain when revealing a text position.
 */
enum abstract ScrollPadding(Int) {
    var Minimal = 0;
    var SurroundingLines = 1;
}
