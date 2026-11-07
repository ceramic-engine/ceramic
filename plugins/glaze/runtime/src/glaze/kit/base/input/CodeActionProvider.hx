// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/code_actions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Entity;
import glaze.Range;
import glaze.Task;
import glaze.Window;

/**
 * A provider of code actions. The state is the editor's (Rust
 * `Entity<EditorState>`; the port has a single non-generic `InputBaseState`).
 */
interface CodeActionProvider {

    /** The id for this CodeAction. */
    function id():String;

    /** Fetches code actions for the specified range (`textDocument/codeAction`). */
    function codeActions(state:Entity<InputBaseState>, range:Range, window:Window, cx:App):Task<Array<LspCodeAction>>;

    /** Performs the specified code action. */
    function performCodeAction(state:Entity<InputBaseState>, action:LspCodeAction, pushToHistory:Bool, window:Window, cx:App):Task<glaze.Unit>;

}
