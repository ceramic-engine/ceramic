// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/completions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;

/**
 * Decides which bytes of a completion label the menu paints as the match.
 *
 * The first argument is the word typed since the menu opened. Returned ranges
 * are byte offsets into `CompletionItem.label`. See `Completions` for the
 * three highlighters gpui-kit ships.
 */
typedef CompletionHighlighter = (query:String, item:CompletionItem) -> Array<Range>;
