// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/code_actions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A code action with the provider that supplied it.
 */
class CodeActionItem {

    public var providerId:String;

    public var action:LspCodeAction;

    public function new(providerId:String, action:LspCodeAction) {
        this.providerId = providerId;
        this.action = action;
    }

}
