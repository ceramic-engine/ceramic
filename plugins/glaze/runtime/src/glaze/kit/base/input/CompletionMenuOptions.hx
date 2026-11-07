// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/completions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Display options for the LSP completion popover.
 *
 * Accessed through `Lsp.completionMenu` so embedders can tweak the
 * popover without growing the `InputBaseState` API. Label highlighting is
 * configured separately, on `Lsp.completionHighlighter`.
 */
class CompletionMenuOptions {

    /**
     * Maximum width of the popover.
     *
     * Defaults to 320 px, which is fine for most identifiers but can
     * truncate longer labels.
     */
    public var maxWidth:Float;

    public function new(maxWidth:Float = 320.) {
        this.maxWidth = maxWidth;
    }

    public inline function copy():CompletionMenuOptions {
        return new CompletionMenuOptions(maxWidth);
    }

}
