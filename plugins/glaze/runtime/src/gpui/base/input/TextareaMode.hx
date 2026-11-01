// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Ordinary multi-line text: the mode of `TextareaState`. It needs nothing
 * beyond the shared engine.
 */
class TextareaMode extends InputModeKindBase implements MultiLineMode {

    public static final instance:TextareaMode = new TextareaMode();

    public function multiLine():Bool {
        return true;
    }

}
