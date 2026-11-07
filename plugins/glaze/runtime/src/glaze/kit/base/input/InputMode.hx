// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A single-line text field: the mode of `InputState`.
 *
 * A single-line field needs nothing beyond the shared engine. Masking,
 * validation and number stepping live there: together they are small and
 * their access sites sit inside the shared edit path.
 */
class InputMode extends InputModeKindBase {

    public static final instance:InputMode = new InputMode();

    public function multiLine():Bool {
        return false;
    }

}
