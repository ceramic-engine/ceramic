// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The content of the editor's completion and code action menus.
 */
class ContextMenuContent {

    public var completion:CompletionMenuState = new CompletionMenuState();

    public var codeAction:CodeActionMenuState = new CodeActionMenuState();

    public function new() {}

}
