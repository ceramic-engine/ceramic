// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The base of the mode markers (`InputMode`, `TextareaMode`).
 */
abstract class InputModeKindBase implements InputModeKind {

    function new() {}

    public abstract function multiLine():Bool;

}
