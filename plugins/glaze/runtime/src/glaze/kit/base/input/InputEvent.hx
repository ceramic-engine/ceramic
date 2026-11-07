// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (`InputEvent`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The events an input state emits (subscribe with
 * `cx.subscribe(state, InputEvent, ...)`).
 */
enum InputEvent {
    Change;
    PressEnter(secondary:Bool, shift:Bool);
    Focus;
    Blur;
}
