// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;
import ropey.Rope;

/**
 * The default (empty) answers of `InputExtras`: Rust's `impl InputExtras
 * for ()`, and the base of the other implementations.
 */
class InputExtrasBase implements InputExtras {

    public function new() {}

    public function decorationLayers():Array<Array<TextDecoration>> {
        return [];
    }

    public function rangeDecorations(ranges:Array<Range>):Array<RangeDecoration> {
        return [];
    }

    public function semanticTokenStyles(text:Rope, range:Range, resolver:HighlightStyleResolver):Array<StyledRange> {
        return [];
    }

    public function documentColorSwatches(text:Rope, range:Range):Array<ColorSwatch> {
        return [];
    }

    public function hoverSymbolRange():Null<Range> {
        return null;
    }

    public function inlineCompletionItem():Null<InlineCompletionItem> {
        return null;
    }

    public function contextMenuCapabilities():ContextMenuSupport {
        return ContextMenuSupport.NONE;
    }

}
