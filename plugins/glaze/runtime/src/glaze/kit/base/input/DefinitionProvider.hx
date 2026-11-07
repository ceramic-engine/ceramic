// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/definitions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Task;
import gpui.Window;
import ropey.Rope;

/**
 * Definition provider (`textDocument/definition`).
 */
interface DefinitionProvider {

    function definitions(text:Rope, offset:Int, window:Window, cx:App):Task<Array<LspLocationLink>>;

}
