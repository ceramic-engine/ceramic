// Ported from gpui-kit 0.8.1: crates/base/src/number_input.rs (`StepAction`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

/**
 * The direction of a number input step.
 */
enum abstract StepAction(Int) {
    var Decrement = 0;
    var Increment = 1;
}
