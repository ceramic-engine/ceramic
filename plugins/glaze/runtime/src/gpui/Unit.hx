// Ported from gpui-pre 0.3.10: src/executor.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The value of a task that produces nothing (Rust: `()`, as in `Task<()>`).
 *
 * Never use `Task<Void>`: hxcpp cannot compile a callback taking a `Void`
 * argument, so `Task<Void>.then(_ -> ...)` would only fail on native targets.
 *
 * The value is `Unit.unit` (lower case: `Unit.Unit` would resolve to the type).
 */
enum abstract Unit(Int) {

    var unit = 0;

}
