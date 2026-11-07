// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/hover.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Task;
import glaze.Window;
import ropey.Rope;

/**
 * Hover provider (`textDocument/hover`).
 */
interface HoverProvider {

    function hover(text:Rope, offset:Int, window:Window, cx:App):Task<Null<LspHover>>;

}
