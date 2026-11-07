// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/completions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Task;
import gpui.Window;
import ropey.Rope;

/**
 * A provider of code completions based on the current input state and context.
 *
 * Rust's `Task<Result<T>>` is a `Task<T>` that may be rejected. Extend
 * `CompletionProviderBase` for the trait's default methods.
 */
interface CompletionProvider {

    /**
     * Fetches completions based on the given byte offset of the cursor
     * (`textDocument/completion`). Rust's `CompletionResponse` (an array or
     * a list) is the array of its items.
     */
    function completions(text:Rope, offset:Int, trigger:CompletionContext, window:Window, cx:App):Task<Array<CompletionItem>>;

    /**
     * Fetches an inline completion suggestion for the given position
     * (`textDocument/inlineCompletion`), after a debounce period when the
     * user stops typing.
     */
    function inlineCompletion(rope:Rope, offset:Int, trigger:InlineCompletionContext, window:Window, cx:App):Task<Array<InlineCompletionItem>>;

    /** The debounce duration for inline completions, in milliseconds (default 300). */
    function inlineCompletionDebounce():Float;

    /**
     * Rust `resolve_completions(completion_indices, completions, cx)`: the
     * completions are the items shown by the menu.
     */
    function resolveCompletions(completionIndices:Array<Int>, completions:Array<CompletionItem>, cx:App):Task<Bool>;

    /**
     * Determines if the completion should be triggered based on the given byte offset.
     *
     * This is called on the main thread.
     */
    function isCompletionTrigger(offset:Int, newText:String, cx:App):Bool;

}

/**
 * The default methods of the `CompletionProvider` trait.
 */
abstract class CompletionProviderBase implements CompletionProvider {

    public abstract function completions(text:Rope, offset:Int, trigger:CompletionContext, window:Window, cx:App):Task<Array<CompletionItem>>;

    public function inlineCompletion(rope:Rope, offset:Int, trigger:InlineCompletionContext, window:Window, cx:App):Task<Array<InlineCompletionItem>> {
        return Task.ready([]);
    }

    public function inlineCompletionDebounce():Float {
        return Completions.DEFAULT_INLINE_COMPLETION_DEBOUNCE;
    }

    public function resolveCompletions(completionIndices:Array<Int>, completions:Array<CompletionItem>, cx:App):Task<Bool> {
        return Task.ready(false);
    }

    public abstract function isCompletionTrigger(offset:Int, newText:String, cx:App):Bool;

}
