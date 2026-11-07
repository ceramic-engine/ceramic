// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Hsla;
import glaze.Range;
import ropey.Rope;

/**
 * What the renderer may read out of a mode's extra state.
 *
 * Kept apart from `InputModeKind` on purpose. This interface is *data*:
 * the renderer cannot name `EditorExtras` and reach its fields directly,
 * and these are the accessors it goes through instead. Every one of them
 * has an empty answer (`InputExtrasBase`), which is what a plain input and
 * a textarea give.
 *
 * `InputModeKind` is *behavior*: points where the engine hands control
 * back during an edit. Adding a field an editor renders belongs here and
 * leaves the engine's callbacks alone.
 */
interface InputExtras {

    /** Decoration ranges to paint, innermost collection first. */
    function decorationLayers():Array<Array<TextDecoration>>;

    /** Geometric decorations intersecting visible, non-folded buffer spans. */
    function rangeDecorations(ranges:Array<Range>):Array<RangeDecoration>;

    /** Semantic-token styles for a visible range, when an LSP supplies them. */
    function semanticTokenStyles(text:Rope, range:Range, resolver:HighlightStyleResolver):Array<StyledRange>;

    /** Document colours to paint as swatches, when an LSP supplies them. */
    function documentColorSwatches(text:Rope, range:Range):Array<ColorSwatch>;

    /** The symbol range the hover popover is anchored to. */
    function hoverSymbolRange():Null<Range>;

    /** The inline completion to paint as ghost text. */
    function inlineCompletionItem():Null<InlineCompletionItem>;

    /** What this mode can offer its context menu: go-to-definition, code actions. */
    function contextMenuCapabilities():ContextMenuSupport;

}
