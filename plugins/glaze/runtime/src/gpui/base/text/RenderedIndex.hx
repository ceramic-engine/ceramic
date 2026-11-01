// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;
import gpui.util.Utf8;

/**
 * The rendered text of one parsed document, and where each text leaf sits in
 * it.
 */
@:allow(gpui.base.text)
class RenderedIndex {

    final text:String;

    final textLen:Int;

    /** In document order, so by their position in `text`. */
    final leaves:Array<LeafSpan>;

    /** Where the text of each top-level block sits, in document order. */
    final blocks:Array<Range>;

    /**
     * Where the pieces of `text` came from in the source, with `rendered` in
     * offsets of `text`, in the order of `text`.
     */
    final sourceMap:Array<SourceSegment>;

    public function new(document:ParsedDocument) {
        final builder = new IndexBuilder();
        final blocks:Array<Range> = [];
        for (block in document.blocks) {
            final start = builder.len;
            builder.pushBlock(block);
            blocks.push(new Range(start, builder.len));
        }
        this.text = builder.text.toString();
        this.textLen = builder.len;
        this.leaves = builder.leaves;
        this.blocks = blocks;
        this.sourceMap = builder.sourceMap;
    }

    /**
     * The leaf ranges `range` paints over, which are none when it covers no
     * leaf text, or `null` when it is not a range of the text.
     */
    function resolve(range:Range):Null<Array<LeafPiece>> {
        if (range.start > range.end
            || range.end > textLen
            || !Utf8.isCharBoundary(text, range.start)
            || !Utf8.isCharBoundary(text, range.end)) {
            return null;
        }

        final first = partitionLeaves(leaf -> leaf.range.end <= range.start);
        final pieces:Array<LeafPiece> = [];
        for (i in first...leaves.length) {
            final leaf = leaves[i];
            if (leaf.range.start >= range.end) {
                break;
            }
            final end = (range.end < leaf.range.end ? range.end : leaf.range.end) - leaf.range.start;
            var cursor = (range.start > leaf.range.start ? range.start : leaf.range.start) - leaf.range.start;
            for (object in leaf.objects) {
                if (object.start >= end) {
                    break;
                }
                if (object.end <= cursor) {
                    continue;
                }
                if (object.start > cursor) {
                    pieces.push(new LeafPiece(leaf.key, new Range(cursor, object.start)));
                }
                cursor = object.end;
            }
            if (cursor < end) {
                pieces.push(new LeafPiece(leaf.key, new Range(cursor, end)));
            }
        }
        return pieces;
    }

    /** Rust `partition_point` over `leaves`. */
    function partitionLeaves(pred:LeafSpan->Bool):Int {
        var lo = 0;
        var hi = leaves.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (pred(leaves[mid])) lo = mid + 1 else hi = mid;
        }
        return lo;
    }

    /**
     * Where `range` starts: the line of the first leaf text it covers, or,
     * when it covers none, as an empty range does, of the leaf text at its
     * start or last before it in its top-level block, or else that whole
     * block. `null` when it is not a range of the text, or there is none.
     */
    function locate(range:Range):Null<RevealTarget> {
        final resolved = resolve(range);
        if (resolved == null) return null;
        if (resolved.length > 0) {
            return Line(resolved[0].key, resolved[0].range.start);
        }
        if (blocks.length == 0) return null;
        var blockIx = 0;
        {
            var lo = 0;
            var hi = blocks.length;
            while (lo < hi) {
                final mid = (lo + hi) >> 1;
                if (blocks[mid].end <= range.start) lo = mid + 1 else hi = mid;
            }
            blockIx = lo < blocks.length - 1 ? lo : blocks.length - 1;
        }
        final blockStart = blocks[blockIx].start;
        final ix = partitionLeaves(leaf -> leaf.range.end <= range.start);
        var leaf:Null<LeafSpan> = null;
        var offset = 0;
        if (ix < leaves.length && leaves[ix].range.contains(range.start)) {
            leaf = leaves[ix];
            offset = range.start - leaf.range.start;
        }
        else if (ix > 0 && leaves[ix - 1].range.start >= blockStart) {
            // A position after the text of a leaf, on the separators after it
            // or at the end of the text, is on the line of the last character
            // before it in its block.
            final candidate = leaves[ix - 1];
            final leafText = Utf8.substring(text, candidate.range.start, candidate.range.end);
            final last = lastCharIndex(leafText);
            if (last != null) {
                leaf = candidate;
                offset = last;
            }
        }
        if (leaf != null) {
            final near = leaf.textOffsetNear(offset);
            if (near != null) {
                return Line(leaf.key, near);
            }
        }
        return Block(blockIx);
    }

    static function lastCharIndex(text:String):Null<Int> {
        final len = Utf8.byteLength(text);
        if (len == 0) return null;
        var ix = len - 1;
        while (ix > 0 && !Utf8.isCharBoundary(text, ix)) ix--;
        return ix;
    }

    /**
     * The smallest range of the text holding every character whose source
     * overlaps `source`, a valid, non-empty range of the source.
     */
    function rangeForSource(source:Range):Null<Range> {
        var found:Null<Range> = null;
        for (segment in sourceMap) {
            if (!(segment.source.start < source.end && segment.source.end > source.start)) {
                continue;
            }
            final range = if (!segment.linear) {
                segment.rendered;
            }
            else {
                final start = (segment.source.start > source.start ? segment.source.start : source.start) - segment.source.start;
                final end = (segment.source.end < source.end ? segment.source.end : source.end) - segment.source.start;
                new Range(floorCharBoundary(text, segment.rendered.start + start), Utf8.ceilCharBoundary(text, segment.rendered.start + end));
            }
            found = found == null ? range : new Range(found.start < range.start ? found.start : range.start, found.end > range.end ? found.end : range.end);
        }
        return found;
    }

    static function floorCharBoundary(text:String, offset:Int):Int {
        final len = Utf8.byteLength(text);
        if (offset >= len) return len;
        var ix = offset;
        while (ix > 0 && !Utf8.isCharBoundary(text, ix)) ix--;
        return ix;
    }

}

/** Rust `(TextLeafKey, Range<usize>)`: a piece of a range in one leaf's text. */
class LeafPiece {
    public final key:TextLeafKey;
    public final range:Range;

    public inline function new(key:TextLeafKey, range:Range) {
        this.key = key;
        this.range = range;
    }
}

/** Where a range to reveal starts. */
enum RevealTarget {
    /** A line of a text leaf: the leaf, and the offset in its text. */
    Line(key:TextLeafKey, offset:Int);
    /** A whole top-level block, for text that belongs to no leaf. */
    Block(ix:Int);
}

@:allow(gpui.base.text)
class LeafSpan {
    /** Where the leaf's text sits in the rendered text. */
    final range:Range;
    final key:TextLeafKey;
    /**
     * Inline objects in the leaf's text, in leaf offsets. They paint as
     * objects rather than as text, so no highlight paints them.
     */
    final objects:Array<Range>;

    function new(range:Range, key:TextLeafKey, objects:Array<Range>) {
        this.range = range;
        this.key = key;
        this.objects = objects;
    }

    /**
     * `offset` in the leaf's text, moved out of an inline object onto the
     * text after it, or before it at the end of the leaf. `null` when the
     * leaf has no text outside its objects.
     */
    function textOffsetNear(offset:Int):Null<Int> {
        function objectAt(offset:Int):Null<Range> {
            for (object in objects) if (object.contains(offset)) return object;
            return null;
        }
        var after = offset;
        var object = objectAt(after);
        while (object != null) {
            after = object.end;
            object = objectAt(after);
        }
        if (after < range.len()) {
            return after;
        }
        var before = offset;
        object = objectAt(before);
        while (object != null) {
            if (object.start == 0) return null;
            before = object.start - 1;
            object = objectAt(before);
        }
        return before;
    }
}

/**
 * Builds the rendered text the way `BlockNode.text` does, recording each
 * leaf, and where its text came from in the source, as it goes.
 */
@:allow(gpui.base.text)
class IndexBuilder {

    final text:StringBuf = new StringBuf();
    var len:Int = 0;
    final leaves:Array<LeafSpan> = [];
    final sourceMap:Array<SourceSegment> = [];

    function new() {}

    inline function pushStr(s:String):Void {
        text.add(s);
        len += Utf8.byteLength(s);
    }

    function pushBlock(block:BlockNode):Void {
        final start = len;
        switch block {
            case Root(children, _) | Blockquote(children, _):
                for (child in children) {
                    pushBlock(child);
                }
            case List(children, _, _, _) | ListItem(children, _, _, _):
                for (child in children) {
                    pushBlock(child);
                }
                return;
            case Paragraph(paragraph):
                pushParagraph(paragraph, paragraph.span != null ? TextLeafKey.block(paragraph.span.start) : null);
            case Heading(_, children, span):
                pushParagraph(children, span != null ? TextLeafKey.block(span.start) : null);
            case Table(table):
                var ordinal = 0;
                for (row in table.children) {
                    if (row.children.length == 0) continue;
                    for (ix in 0...row.children.length) {
                        final cell = row.children[ix];
                        if (ix > 0) {
                            pushStr(' ');
                        }
                        pushParagraph(cell.children, table.span != null ? TextLeafKey.tableCell(table.span.start, ordinal) : null);
                        ordinal += 1;
                    }
                    pushStr('\n');
                }
            case CodeBlock(codeBlock):
                final code = codeBlock.code();
                pushSourceSegments(len, code, codeBlock.sourceSegments_);
                pushLeaf(code, codeBlock.span != null ? TextLeafKey.block(codeBlock.span.start) : null, []);
            case Custom(node, _):
                pushObjectSource(len, node.asText(), node.sourceRange());
                pushStr(node.asText());
            case Definition(_, _, _, _) | Break(_, _) | HorizontalRule(_) | Unknown:
        }
        if (len > start) {
            pushStr('\n');
        }
    }

    function pushParagraph(paragraph:Paragraph, key:Null<TextLeafKey>):Void {
        final start = len;
        final buf = new StringBuf();
        var textLen = 0;
        final objects:Array<Range> = [];
        for (child in paragraph.children_) {
            final offset = start + textLen;
            final childLen = Utf8.byteLength(child.text_);
            if (child.custom != null) {
                objects.push(new Range(textLen, textLen + childLen));
                pushObjectSource(offset, child.text_, child.custom.sourceRange());
            }
            else {
                pushSourceSegments(offset, child.text_, child.sourceSegments_);
            }
            buf.add(child.text_);
            textLen += childLen;
        }
        pushLeaf(buf.toString(), key, objects);
    }

    /**
     * Records `segments` of `text`, which is about to be pushed at `offset`.
     *
     * A segment that is empty or does not address `text` maps nothing and is
     * left out, so a bad one cannot map a range to text it did not render.
     */
    function pushSourceSegments(offset:Int, text:String, segments:Array<SourceSegment>):Void {
        final textLen = Utf8.byteLength(text);
        for (segment in segments) {
            if (!segment.rendered.isEmpty()
                && !segment.source.isEmpty()
                && segment.rendered.end <= textLen
                && Utf8.isCharBoundary(text, segment.rendered.start)
                && Utf8.isCharBoundary(text, segment.rendered.end)) {
                sourceMap.push(new SourceSegment(new Range(offset + segment.rendered.start, offset + segment.rendered.end), segment.source, segment.linear));
            }
        }
    }

    /**
     * Records that all of `text`, an object about to be pushed at `offset`,
     * was rendered from `source`, which maps only as a whole.
     */
    function pushObjectSource(offset:Int, text:String, source:Null<Range>):Void {
        if (source != null) {
            pushSourceSegments(offset, text, [new SourceSegment(new Range(0, Utf8.byteLength(text)), source, false)]);
        }
    }

    function pushLeaf(text:String, key:Null<TextLeafKey>, objects:Array<Range>):Void {
        final start = len;
        pushStr(text);
        if (key != null && text.length > 0) {
            leaves.push(new LeafSpan(new Range(start, len), key, objects));
        }
    }

}
