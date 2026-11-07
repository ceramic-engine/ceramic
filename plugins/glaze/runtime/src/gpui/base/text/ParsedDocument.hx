// Ported from gpui-kit 0.8.1: crates/base/src/text/document.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.App;
import gpui.IntoElement;
import gpui.ListState;
import gpui.Range;
import gpui.Window;
import gpui.base.text.BlockNode.BlockNodeTools;

import gpui.Prelude.*;

using gpui.ParentElementTools;
using gpui.base.text.BlockNode.BlockNodeTools;

/**
 * The parsed document AST.
 *
 * `blocks` is shared between clones (Rust `Arc<Vec<BlockNode>>`): never
 * mutate it after parsing, build a new array instead.
 */
class ParsedDocument {

    public var source:String = '';

    public var blocks:Array<BlockNode> = [];

    /** `ParsedDocument::default()`. */
    public function new(source:String = '', ?blocks:Array<BlockNode>) {
        this.source = source;
        if (blocks != null)
            this.blocks = blocks;
    }

    /** Rust `Clone`: the blocks are shared. */
    public function clone():ParsedDocument {
        return new ParsedDocument(source, blocks);
    }

    public function equals(other:Null<ParsedDocument>):Bool {
        return other != null && source == other.source && (blocks == other.blocks || BlockNodeTools.arrayEquals(blocks, other.blocks));
    }

    /**
     * Where the block at `ix` stands in its flow: whether it is the first
     * block that shows anything, and the visible block before it. Link
     * definitions and other blocks that render nothing are skipped, so a
     * document opening with `[ref]: url` still starts flush.
     */
    public static function flowPosition(blocks:Array<BlockNode>, ix:Int):{isFirst:Bool, prev:PrevBlock} {
        var i = ix - 1;
        while (i >= 0) {
            final block = blocks[i];
            switch block {
                case Definition(_, _, _, _) | Break(_, _) | Unknown:
                    i--;
                case Heading(level, _, _):
                    return {isFirst: false, prev: PrevBlock.Heading(level)};
                case HorizontalRule(_):
                    return {isFirst: false, prev: Rule};
                case _:
                    return {isFirst: false, prev: Other};
            }
        }
        return {isFirst: true, prev: Other};
    }

    @:allow(gpui.base.text)
    function text():String {
        final text = new StringBuf();
        for (block in blocks) {
            text.add(block.text());
        }
        return text.toString();
    }

    /**
     * The selected text across all blocks, in `format`.
     *
     * In `SelectionFormat.Source` each block reconstructs its own Markdown
     * source (inline markup, and block prefixes for headings and lists), and
     * top-level blocks are joined with a blank line so the result re-renders
     * with the same block structure.
     *
     * Paint and synchronous Copy project the current gesture onto retained
     * native layouts. In a scrollable (virtualized) view some covered blocks
     * have never been laid out and report nothing. The selection is
     * continuous, so its interior blocks are emitted whole rather than
     * dropped. `blocks` (an inclusive range, `[first, last]`) bounds that
     * span; it comes from the selection endpoints, which hold on to their
     * block index even after scrolling out of view. Without it, fall back to
     * the blocks with projected selections.
     *
     * A standalone image (a paragraph that is only an image) has no
     * selectable text run, so it never carries a selection of its own. It is
     * therefore included when it is *enclosed* by the selection (some block
     * before and some block after it are selected), mirroring how an inline
     * image is emitted when the selection runs into it.
     */
    @:allow(gpui.base.text)
    function selectedText(format:SelectionFormat, ?blockRange:Array<Int>):String {
        final requestedBlocks = blockRange;
        final painted = [for (block in this.blocks) block.hasSelection()];
        var paintedFirst = -1;
        var paintedLast = -1;
        for (i in 0...painted.length) {
            if (painted[i]) {
                if (paintedFirst < 0)
                    paintedFirst = i;
                paintedLast = i;
            }
        }
        if (paintedFirst < 0) {
            return '';
        }

        final lastIx = this.blocks.length > 0 ? this.blocks.length - 1 : 0;
        var first = paintedFirst;
        var last = paintedLast;
        if (blockRange != null) {
            first = blockRange[0] < lastIx ? blockRange[0] : lastIx;
            last = blockRange[1] < lastIx ? blockRange[1] : lastIx;
        }

        // A selection within one style copies as the text it renders; one
        // that is only partly painted cannot tell, and keeps its source.
        final format:SelectionFormat = switch format {
            case SourceAcrossStyles if (first == last && painted[first] && this.blocks[first].selectionStyles() != Mixed):
                Plain;
            case SourceAcrossStyles:
                Source;
            case format:
                format;
        }

        if (format == Plain) {
            final text = new StringBuf();
            var ix = first;
            while (ix <= last && ix < this.blocks.length) {
                final block = this.blocks[ix];
                final selected = block.selectedText(format);
                final isVirtualEndpoint = requestedBlocks != null && (ix == requestedBlocks[0] || ix == requestedBlocks[1]);
                if (requestedBlocks != null && !isVirtualEndpoint) {
                    text.add(block.text());
                } else if (selected != '') {
                    text.add(selected);
                } else if (!painted[ix]) {
                    // Never painted, so it cannot report a selection of its own
                    // even though the span covers it. A painted block that came
                    // up empty really has nothing selected, and stays empty.
                    text.add(block.text());
                }
                ix++;
            }
            return text.toString();
        }

        final out:Array<String> = [];
        var ix = first;
        while (ix <= last && ix < this.blocks.length) {
            final block = this.blocks[ix];
            // The selection is one continuous range, so only the block it
            // starts in and the block it ends in can be partly selected.
            // Everything between them is covered whole, and so is any block
            // that reports nothing: it either scrolled past without painting,
            // or renders no selectable text run at all (a rule, a break, a
            // custom node, a standalone image).
            final source = if ((ix == first || ix == last) && painted[ix]) {
                block.selectedText(format);
            } else {
                wholeSource(block);
            }

            final trimmed = TextUtils.trimEndMatches(source, '\n');
            if (trimmed != '') {
                out.push(trimmed);
            }
            ix++;
        }
        return out.join('\n\n');
    }

    /**
     * The whole source of a block the selection covers.
     *
     * Copied straight out of the original text, which the Markdown parser
     * locates per block. That keeps whatever the author wrote, and it needs
     * no rule of its own per block type. Blocks the parser could not locate
     * fall back to reconstruction.
     */
    function wholeSource(block:BlockNode):String {
        final span = block.span();
        if (span != null) {
            final source = TextUtils.byteSlice(this.source, span.start, span.end);
            if (source != null) {
                return source;
            }
        }

        return block.selectedText(Source);
    }

    @:allow(gpui.base.text)
    function selectedSourceRange():Null<Range> {
        final selected = SourceRangeSelection.unselected();
        for (block in blocks) {
            selected.merge(block.selectedSourceRange());
        }
        return selected.intoRange();
    }

    /**
     * Synchronously clear the selection stored in every inline state.
     *
     * This mirrors the `selectedText` traversal so the stored selection can
     * be cleared without relying on a repaint. Offscreen (virtualized) views
     * do not repaint, so their `InlineState.selection` would otherwise retain
     * stale values from the last painted frame.
     */
    @:allow(gpui.base.text)
    function clearSelection():Void {
        for (block in blocks) {
            block.clearSelection();
        }
    }

    /**
     * Converts the node to markdown format.
     *
     * This is used to generate markdown for test.
     */
    @:allow(gpui.base.text)
    function toMarkdown():String {
        return [for (child in blocks) child.toMarkdown()].join('\n\n');
    }

    @:allow(gpui.base.text)
    function renderRoot(listState:Null<ListState>, nodeCx:NodeContext, window:Window, cx:App):IntoElement {
        if (listState == null) {
            final blocksLen = blocks.length;
            final container = div();
            for (ix in 0...blocks.length) {
                final node = blocks[ix];
                final isLast = ix + 1 == blocksLen;
                final position = flowPosition(blocks, ix);
                final options = new NodeRenderOptions();
                options.ix = ix;
                options.isLast = isLast;
                options.isFirst = position.isFirst;
                options.prev = position.prev;
                container.child(node.renderBlock(options, nodeCx, window, cx));
            }
            return container;
        }

        final baseOptions = new NodeRenderOptions();
        baseOptions.isLast = true;

        final blocks = this.blocks;
        if (listState.itemCount() != blocks.length) {
            listState.reset(blocks.length);
        }

        final nodeCx = nodeCx.clone();
        return div().sizeFull().child(list(listState, (ix, window, cx) -> {
            final isLast = ix + 1 == blocks.length;
            final position = flowPosition(blocks, ix);
            final options = baseOptions.copy();
            options.ix = ix;
            options.isLast = isLast;
            options.isFirst = position.isFirst;
            options.prev = position.prev;
            return blocks[ix].renderBlock(options, nodeCx, window, cx);
        }).sizeFull());
    }

}
