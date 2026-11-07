// Ported from gpui-kit 0.8.1: crates/base/src/input/base/movement.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The direction of a vertical cursor move, for the reveal scroll.
 */
enum abstract MoveDirection(Int) {
    var Up = 0;
    var Down = 1;
}
