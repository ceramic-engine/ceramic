// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;
import gpui.base.text.RangeHighlightError;
import gpui.base.text.RenderedIndex.LeafPiece;

/** Rust `(TextLeafKey, Vec<(Range<usize>, Hsla)>)`. */
class LeafBackgrounds {
    public final key:TextLeafKey;
    public final backgrounds:Array<RangedColor>;

    public inline function new(key:TextLeafKey, backgrounds:Array<RangedColor>) {
        this.key = key;
        this.backgrounds = backgrounds;
    }
}

/**
 * The highlights each leaf paints, resolved once when they change so
 * rendering only looks up its leaf.
 */
class RangeHighlightFrame {

    /**
     * Sorted by key. A leaf's backgrounds keep the order the application gave
     * them in, so a later one paints over an earlier one.
     */
    final leaves:Array<LeafBackgrounds>;

    function new(leaves:Array<LeafBackgrounds>) {
        this.leaves = leaves;
    }

    /**
     * Validates `highlights` against `text` and resolves them to leaves.
     * Throws `RangeHighlightException` with `InvalidRange` (Rust `Err`);
     * `null` when no highlight paints anything.
     */
    @:allow(gpui.base.text)
    static function create(text:RenderedText, highlights:Iterable<RangeHighlight>):Null<RangeHighlightFrame> {
        final pieces:Array<{key:TextLeafKey, color:RangedColor}> = [];
        var ix = 0;
        for (highlight in highlights) {
            final leafRanges = text.index().resolve(highlight.range());
            if (leafRanges == null) {
                throw new RangeHighlightException(InvalidRange(ix));
            }
            for (piece in leafRanges) {
                pieces.push({key: piece.key, color: new RangedColor(piece.range, highlight.background())});
            }
            ix++;
        }

        // Stable, so each leaf keeps the application's order.
        haxe.ds.ArraySort.sort(pieces, (a, b) -> TextLeafKey.compare(a.key, b.key));
        final leaves:Array<LeafBackgrounds> = [];
        for (piece in pieces) {
            final last = leaves.length > 0 ? leaves[leaves.length - 1] : null;
            if (last != null && last.key.equals(piece.key)) {
                last.backgrounds.push(piece.color);
            }
            else {
                leaves.push(new LeafBackgrounds(piece.key, [piece.color]));
            }
        }
        return leaves.length > 0 ? new RangeHighlightFrame(leaves) : null;
    }

    static final EMPTY:Array<RangedColor> = [];

    /** The backgrounds of leaf `key`, in its rendered byte space. */
    public function backgrounds(key:TextLeafKey):Array<RangedColor> {
        var lo = 0;
        var hi = leaves.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            final order = TextLeafKey.compare(leaves[mid].key, key);
            if (order == 0) return leaves[mid].backgrounds;
            if (order < 0) lo = mid + 1 else hi = mid;
        }
        return EMPTY;
    }

    /**
     * The highlights that still describe the document `remap` maps the old
     * one to: each follows its leaf as far as the leaf's text is unchanged, and
     * is dropped with a leaf that is gone.
     */
    @:allow(gpui.base.text)
    function remap(remap:LeafRemap):Null<RangeHighlightFrame> {
        final leaves:Array<LeafBackgrounds> = [];
        for (leaf in this.leaves) {
            final found = remap.leaf(leaf.key);
            if (found == null) continue;
            final clipped:Array<RangedColor> = [];
            for (background in leaf.backgrounds) {
                if (background.range.start < found.unchanged) {
                    final end = background.range.end < found.unchanged ? background.range.end : found.unchanged;
                    clipped.push(new RangedColor(new Range(background.range.start, end), background.color));
                }
            }
            if (clipped.length > 0) {
                leaves.push(new LeafBackgrounds(found.key, clipped));
            }
        }
        // Moving keys keeps their order, but stay safe for the binary search.
        haxe.ds.ArraySort.sort(leaves, (a, b) -> TextLeafKey.compare(a.key, b.key));
        return leaves.length > 0 ? new RangeHighlightFrame(leaves) : null;
    }

}
