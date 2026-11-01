// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/semantic_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Range;
import gpui.Task;
import gpui.Window;
import ropey.Rope;

/**
 * Range semantic tokens provider (`textDocument/semanticTokens/range`).
 */
interface DocumentRangeSemanticTokensProvider {

    function legend():SemanticTokensLegend;

    function semanticTokens(text:Rope, range:Range, window:Window, cx:App):Task<SemanticTokens>;

}
