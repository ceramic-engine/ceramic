// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.base.text.TextLeaf.KeyedTextLeaf;
import gpui.base.text.TextLeaf.TextLeafTools;

/** Rust `(TextLeafKey, usize)`: where a leaf is now, and how much of its text is unchanged. */
class RemappedLeaf {
    public final key:TextLeafKey;
    public final unchanged:Int;

    public inline function new(key:TextLeafKey, unchanged:Int) {
        this.key = key;
        this.unchanged = unchanged;
    }
}

/** Rust `(TextLeafKey, Option<usize>)`: the last cell of a table row, and its source end. */
class RowSourceEnd {
    public final last:TextLeafKey;
    public final end:Null<Int>;

    public inline function new(last:TextLeafKey, end:Null<Int>) {
        this.last = last;
        this.end = end;
    }
}

/**
 * Where the text leaves of one parsed document are found in the document
 * parsed after it.
 *
 * A block that starts before the first change of the source is found at the
 * same offset, and one after the last change at an offset moved by the change
 * in length; a block that starts between them is gone. A leaf keeps its text
 * up to where it first differs from before.
 */
class LeafRemap {

    final oldLen:Int;
    final newLen:Int;
    /** With an append, where the block it parsed again starts: every leaf before it is unchanged. */
    final tailStart:Null<Int>;
    final unchangedPrefix:Int;
    final unchangedSuffix:Int;
    final oldLeaves:Array<KeyedTextLeaf>;
    final newLeaves:Array<KeyedTextLeaf>;
    /** Sorted by each row's last cell. Unneeded for append-only remapping. */
    final tableRows:Array<RowSourceEnd>;

    /**
     * With `tailOnly`, `next` was parsed by appending to `old`, which parses
     * only the last block of `old` again and keeps the others as they were.
     */
    public function new(old:ParsedDocument, next:ParsedDocument, tailOnly:Bool) {
        final oldSource = haxe.io.Bytes.ofString(old.source);
        final newSource = haxe.io.Bytes.ofString(next.source);
        oldLen = oldSource.length;
        newLen = newSource.length;
        // An append starts after the old source, and parses its last block
        // again, or only the new text when that block has no span.
        if (tailOnly) {
            final last = old.blocks.length > 0 ? old.blocks[old.blocks.length - 1].span() : null;
            tailStart = last != null ? last.start : oldLen;
        }
        else {
            tailStart = null;
        }
        if (tailOnly) {
            unchangedPrefix = oldLen;
            unchangedSuffix = 0;
        }
        else {
            final shorter = oldLen < newLen ? oldLen : newLen;
            var prefix = 0;
            while (prefix < shorter && oldSource.get(prefix) == newSource.get(prefix)) prefix++;
            if (prefix == shorter) {
                // One source extends the other, as when text is appended.
                unchangedPrefix = prefix;
                unchangedSuffix = 0;
            }
            else {
                // Where the two overlap, as when a deleted block starts like
                // the block after it, the end wins: the blocks after a change
                // keep following their text rather than their offset.
                var suffix = 0;
                while (suffix < shorter && oldSource.get(oldLen - 1 - suffix) == newSource.get(newLen - 1 - suffix)) suffix++;
                unchangedSuffix = suffix;
                final limit = shorter - suffix;
                unchangedPrefix = prefix < limit ? prefix : limit;
            }
        }

        final tableRows:Array<RowSourceEnd> = [];
        if (!tailOnly) {
            tableRowSourceEnds(old.blocks, tableRows);
            haxe.ds.ArraySort.sort(tableRows, (a, b) -> TextLeafKey.compare(a.last, b.last));
        }
        this.tableRows = tableRows;
        oldLeaves = leavesFrom(old, tailStart);
        newLeaves = leavesFrom(next, tailStart);
    }

    static function leavesFrom(document:ParsedDocument, tailStart:Null<Int>):Array<KeyedTextLeaf> {
        final leaves:Array<KeyedTextLeaf> = [];
        var i = document.blocks.length - 1;
        while (i >= 0) {
            final block = document.blocks[i];
            if (tailStart != null) {
                final span = block.span();
                if (span == null || span.start < tailStart) {
                    break;
                }
            }
            StreamFade.textLeaves(block, leaves);
            i--;
        }
        haxe.ds.ArraySort.sort(leaves, (a, b) -> TextLeafKey.compare(a.key, b.key));
        return leaves;
    }

    /**
     * Where leaf `key` is in the new document, and how much of its text is
     * unchanged, or `null` when it is gone.
     */
    public function leaf(key:TextLeafKey):Null<RemappedLeaf> {
        if (tailStart != null && key.blockStart() < tailStart) {
            return new RemappedLeaf(key, 0x7fffffff);
        }
        final moved = this.moved(key.blockStart());
        if (moved == null) return null;
        final newKey = key.movedTo(moved);
        final oldLeaf = find(oldLeaves, key);
        if (oldLeaf == null) return null;
        // A table's cells are only known by their place in it, so after a
        // change inside the table a cell is the same one only when the source
        // of its whole row ends before that change.
        if (key.cellIx() != null && key.blockStart() < unchangedPrefix && tailStart == null) {
            final end = rowSourceEnd(key);
            if (end == null || end > unchangedPrefix) {
                return null;
            }
        }
        final newLeaf = find(newLeaves, newKey);
        if (newLeaf == null) return null;
        return new RemappedLeaf(newKey, TextLeafTools.commonPrefixLen(newLeaf, oldLeaf));
    }

    function rowSourceEnd(key:TextLeafKey):Null<Int> {
        var lo = 0;
        var hi = tableRows.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (TextLeafKey.compare(tableRows[mid].last, key) < 0) lo = mid + 1 else hi = mid;
        }
        if (lo >= tableRows.length) return null;
        final row = tableRows[lo];
        if (row.last.blockStart() != key.blockStart()) {
            return null;
        }
        return row.end;
    }

    /** Where the block starting at `start` in the old document starts in the new one. */
    function moved(start:Int):Null<Int> {
        if (start < unchangedPrefix) {
            return start;
        }
        else if (start >= oldLen - unchangedSuffix) {
            return start + newLen - oldLen;
        }
        else {
            return null;
        }
    }

    static function find(leaves:Array<KeyedTextLeaf>, key:TextLeafKey):Null<TextLeaf> {
        var lo = 0;
        var hi = leaves.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            final order = TextLeafKey.compare(leaves[mid].key, key);
            if (order == 0) return leaves[mid].leaf;
            if (order < 0) lo = mid + 1 else hi = mid;
        }
        return null;
    }

    /**
     * The last cell and source end of each table row. Collect them once so
     * remapping cells neither rescans a table nor recomputes a row's end.
     */
    static function tableRowSourceEnds(blocks:Array<BlockNode>, rows:Array<RowSourceEnd>):Void {
        for (block in blocks) {
            switch block {
                case Table(table):
                    final span = table.span;
                    if (span == null) {
                        continue;
                    }
                    var cellCount = 0;
                    for (row in table.children) {
                        if (row.children.length == 0) {
                            continue;
                        }
                        cellCount += row.children.length;
                        var end:Null<Int> = null;
                        for (cell in row.children) {
                            final cellEnd = paragraphSourceEnd(cell.children);
                            if (cellEnd != null && (end == null || cellEnd > end)) end = cellEnd;
                        }
                        rows.push(new RowSourceEnd(TextLeafKey.tableCell(span.start, cellCount - 1), end));
                    }
                case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                    tableRowSourceEnds(children, rows);
                case _:
            }
        }
    }

    /** Where the source of `paragraph`'s text ends, when the parser recorded it. */
    static function paragraphSourceEnd(paragraph:Paragraph):Null<Int> {
        var max:Null<Int> = null;
        for (node in paragraph.children_) {
            for (segment in node.sourceSegments_) {
                if (max == null || segment.source.end > max) max = segment.source.end;
            }
            if (node.custom != null) {
                final range = node.custom.sourceRange();
                if (range != null && (max == null || range.end > max)) max = range.end;
            }
        }
        return max;
    }

}
