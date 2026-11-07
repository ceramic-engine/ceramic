// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/completions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Task;

/**
 * The inline completion of an editor.
 */
class InlineCompletion {

    /** Completion item to display as an inline completion suggestion */
    public var item:Null<InlineCompletionItem> = null;

    /** Task for debouncing inline completion requests */
    public var task:Task<Array<InlineCompletionItem>> = Task.ready([]);

    public function new() {}

}
