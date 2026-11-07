// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;
import glaze.Task;
import glaze.Unit;
import ropey.Rope;

/**
 * What a code editor adds on top of multi-line text: language features.
 *
 * Declared with the modes; its `InputExtras` implementation lives with the
 * editor code (`EditorExtrasHooks`, Rust `editor/mod.rs`).
 */
class EditorExtras implements InputExtras {

    public var lsp:Lsp = new Lsp();

    public var decorations:DecorationCollections<TextDecoration> = new DecorationCollections();

    /** Rust `range_decorations`. */
    public var rangeDecorationCollections:DecorationCollections<RangeDecoration> = new DecorationCollections();

    public var inlineCompletion:InlineCompletion = new InlineCompletion();

    public var contextMenuContent:ContextMenuContent = new ContextMenuContent();

    public var hoverPopover:Null<HoverPopoverState> = null;

    public var hoverDefinition:HoverDefinition = new HoverDefinition();

    public var contextMenuTask:Task<Unit> = Task.done();

    public function new() {}

    public function decorationLayers():Array<Array<TextDecoration>> {
        return EditorExtrasHooks.decorationLayers(this);
    }

    public function rangeDecorations(ranges:Array<Range>):Array<RangeDecoration> {
        return EditorExtrasHooks.rangeDecorations(this, ranges);
    }

    public function semanticTokenStyles(text:Rope, range:Range, resolver:HighlightStyleResolver):Array<StyledRange> {
        return EditorExtrasHooks.semanticTokenStyles(this, text, range, resolver);
    }

    public function documentColorSwatches(text:Rope, range:Range):Array<ColorSwatch> {
        return EditorExtrasHooks.documentColorSwatches(this, text, range);
    }

    public function hoverSymbolRange():Null<Range> {
        return EditorExtrasHooks.hoverSymbolRange(this);
    }

    public function inlineCompletionItem():Null<InlineCompletionItem> {
        return EditorExtrasHooks.inlineCompletionItem(this);
    }

    public function contextMenuCapabilities():ContextMenuSupport {
        return EditorExtrasHooks.contextMenuCapabilities(this);
    }

}
