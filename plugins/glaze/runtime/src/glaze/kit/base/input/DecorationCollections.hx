// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;
import ropey.Rope;

using glaze.kit.base.input.RopeExt;

/**
 * A balanced interval index over stable insertion-order entries. Each midpoint
 * stores the maximum end of its subtree, so one document-spanning decoration
 * does not force a scan of every preceding decoration on each frame.
 */
class DecorationIndex<T:TrackedDecoration> {

    public var indices:Array<Int>;

    public var maxEnds:Array<Int>;

    public function new(decorations:Array<T>) {
        final indices = [for (i in 0...decorations.length) i];
        // sort_unstable_by_key(|&ix| (start, ix)): the key is unique, any sort gives the same order
        indices.sort((a, b) -> {
            final sa = decorations[a].getRange().start;
            final sb = decorations[b].getRange().start;
            return sa != sb ? (sa < sb ? -1 : 1) : a - b;
        });
        this.maxEnds = [for (_ in 0...indices.length) 0];
        this.indices = indices;
        build(decorations, 0, decorations.length);
    }

    public function build(decorations:Array<T>, spanStart:Int, spanEnd:Int):Int {
        if (spanStart >= spanEnd)
            return 0;
        final mid = spanStart + Std.int((spanEnd - spanStart) / 2);
        var end = decorations[indices[mid]].getRange().end;
        final left = build(decorations, spanStart, mid);
        if (left > end)
            end = left;
        final right = build(decorations, mid + 1, spanEnd);
        if (right > end)
            end = right;
        maxEnds[mid] = end;
        return end;
    }

    /** Returns the number of visited nodes, allowing deterministic complexity tests. */
    public function query(decorations:Array<T>, spanStart:Int, spanEnd:Int, range:Range, matches:Array<Int>):Int {
        if (spanStart >= spanEnd || range.isEmpty())
            return 0;
        final mid = spanStart + Std.int((spanEnd - spanStart) / 2);
        if (maxEnds[mid] <= range.start)
            return 1;
        var visited = 1 + query(decorations, spanStart, mid, range, matches);
        final ix = indices[mid];
        final candidate = decorations[ix].getRange();
        if (candidate.start < range.end) {
            if (candidate.end > range.start)
                matches.push(ix);
            visited += query(decorations, mid + 1, spanEnd, range, matches);
        }
        return visited;
    }

}

class DecorationEntries<T:TrackedDecoration> {

    public var decorations:Array<T>;

    public var index:DecorationIndex<T>;

    public function new(decorations:Array<T>) {
        this.decorations = decorations;
        this.index = new DecorationIndex(decorations);
    }

    public function reindex():Void {
        index = new DecorationIndex(decorations);
    }

}

/**
 * The decoration collections of an editor, by collection id (Rust
 * `DecorationCollections<T>`, a `BTreeMap` by id). Ids increase, so the
 * entries are kept in id order by appending.
 */
class DecorationCollections<T:TrackedDecoration> {

    final ids:Array<Int> = [];

    final entries:Array<DecorationEntries<T>> = [];

    var nextId:Int = 0;

    public function new() {}

    function find(id:Int):Int {
        for (i in 0...ids.length) {
            if (ids[i] == id)
                return i;
        }
        return -1;
    }

    public function create(decorations:Array<T>):Int {
        final id = nextId;
        nextId += 1;
        ids.push(id);
        entries.push(new DecorationEntries(decorations));
        return id;
    }

    public function set(id:Int, decorations:Array<T>):Bool {
        final i = find(id);
        if (i < 0)
            return false;
        entries[i] = new DecorationEntries(decorations);
        return true;
    }

    public function append(id:Int, decorations:Array<T>):Bool {
        final i = find(id);
        if (i < 0)
            return false;
        final current = entries[i];
        for (d in decorations)
            current.decorations.push(d);
        current.reindex();
        return true;
    }

    public function get(id:Int):Null<Array<T>> {
        final i = find(id);
        return i < 0 ? null : entries[i].decorations;
    }

    /** Rust `entries.remove(&id).is_some()` */
    public function remove(id:Int):Bool {
        final i = find(id);
        if (i < 0)
            return false;
        ids.splice(i, 1);
        entries.splice(i, 1);
        return true;
    }

    public function adjustForEdit(editedRange:Range, insertedLen:Int):Void {
        for (entry in entries) {
            final len = entry.decorations.length;
            if (len == 0 || entry.index.maxEnds[Std.int(len / 2)] <= editedRange.start)
                continue;
            final remap:Array<Int> = [];
            var retained = 0;
            final kept:Array<T> = [];
            for (decoration in entry.decorations) {
                decoration.setRange(adjustRangeForEdit(decoration.getRange(), editedRange, insertedLen));
                final keep = !decoration.getRange().isEmpty();
                remap.push(keep ? retained : -1);
                if (keep) {
                    retained += 1;
                    kept.push(decoration);
                }
            }
            entry.decorations = kept;
            // Anchor transforms are monotone. Preserve start ordering and remap
            // removed entries rather than sorting on every keystroke: O(n).
            final indices:Array<Int> = [];
            for (ix in entry.index.indices) {
                final mapped = remap[ix];
                if (mapped != -1)
                    indices.push(mapped);
            }
            entry.index.indices = indices;
            entry.index.maxEnds.resize(retained);
            entry.index.build(entry.decorations, 0, retained);
        }
    }

    public function clear():Void {
        for (i in 0...entries.length)
            entries[i] = new DecorationEntries([]);
    }

    public function iter():Array<Array<T>> {
        return [for (entry in entries) entry.decorations];
    }

    /**
     * Query visible buffer spans (not the intervening folded-away text).
     * Rebuilds happen on mutations, never in layout/paint. Preserve owner/item
     * order after deduplicating ranges crossing multiple visible lines.
     */
    public function intersecting(ranges:Array<Range>):Array<T> {
        final result:Array<T> = [];
        for (entry in entries) {
            final matches:Array<Int> = [];
            for (range in ranges)
                entry.index.query(entry.decorations, 0, entry.decorations.length, range, matches);
            matches.sort((a, b) -> a - b);
            var previous = -1;
            for (ix in matches) {
                if (ix == previous)
                    continue;
                previous = ix;
                result.push(entry.decorations[ix]);
            }
        }
        return result;
    }

    public static function adjustRangeForEdit(range:Range, editedRange:Range, insertedLen:Int):Range {
        final removedLen = editedRange.end > editedRange.start ? editedRange.end - editedRange.start : 0;
        inline function shift(offset:Int):Int {
            if (insertedLen >= removedLen)
                return offset + (insertedLen - removedLen);
            final value = offset - (removedLen - insertedLen);
            return value > 0 ? value : 0;
        }

        if (editedRange.isEmpty()) {
            final start = range.start < editedRange.start ? range.start : shift(range.start);
            final end = range.end <= editedRange.start ? range.end : shift(range.end);
            return new Range(start, end);
        }

        final insertedEnd = editedRange.start + insertedLen;
        final start = range.start <= editedRange.start ? range.start : (range.start >= editedRange.end ? shift(range.start) : editedRange.start);
        final end = range.end <= editedRange.start ? range.end : (range.end >= editedRange.end ? shift(range.end) : insertedEnd);
        return new Range(start, end);
    }

    /** Clip ranges to UTF-8 boundaries, dropping empty and reversed ones. */
    public static function normalize<T:TrackedDecoration>(text:Rope, decorations:Array<T>):Array<T> {
        final result:Array<T> = [];
        for (decoration in decorations) {
            // Reject reversed ranges before clipping, which could otherwise turn a
            // reversed pair within a multibyte character into a nonempty range.
            if (decoration.getRange().isEmpty())
                continue;
            final range = new Range(text.clipOffset(decoration.getRange().start, Bias.Left), text.clipOffset(decoration.getRange().end, Bias.Right));
            if (range.isEmpty())
                continue;
            decoration.setRange(range);
            result.push(decoration);
        }
        return result;
    }

}
