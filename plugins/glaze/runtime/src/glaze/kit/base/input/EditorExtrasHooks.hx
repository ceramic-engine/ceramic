// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/mod.rs (`impl InputExtras for EditorExtras`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;
import ropey.Rope;

/**
 * What a code editor exposes to the renderer (Rust `impl InputExtras for
 * EditorExtras`, written in `editor/mod.rs`): `EditorExtras` (declared with
 * `kind.rs`) implements the `InputExtras` methods by calling these.
 */
class EditorExtrasHooks {

    public static function decorationLayers(extras:EditorExtras):Array<Array<TextDecoration>> {
        return extras.decorations.iter();
    }

    public static function rangeDecorations(extras:EditorExtras, ranges:Array<Range>):Array<RangeDecoration> {
        return extras.rangeDecorationCollections.intersecting(ranges);
    }

    public static function semanticTokenStyles(extras:EditorExtras, text:Rope, range:Range, resolver:HighlightStyleResolver):Array<StyledRange> {
        return extras.lsp.semanticTokensForRange(text, range, resolver);
    }

    public static function documentColorSwatches(extras:EditorExtras, text:Rope, range:Range):Array<ColorSwatch> {
        return extras.lsp.documentColorsForRange(text, range);
    }

    public static function hoverSymbolRange(extras:EditorExtras):Null<Range> {
        return extras.hoverPopover != null ? extras.hoverPopover.symbolRange : null;
    }

    public static function inlineCompletionItem(extras:EditorExtras):Null<InlineCompletionItem> {
        return extras.inlineCompletion.item;
    }

    /** (go-to-definition, code actions) */
    public static function contextMenuCapabilities(extras:EditorExtras):ContextMenuSupport {
        return new ContextMenuSupport(extras.lsp.definitionProvider != null, extras.lsp.codeActionProviders.length > 0);
    }

}
