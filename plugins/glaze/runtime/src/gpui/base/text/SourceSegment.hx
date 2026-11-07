// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;

/**
 * A rendered UTF-8 byte span paired with its exact Markdown source span.
 */
class SourceSegment {

    @:allow(gpui.base.text)
    var rendered:Range;

    @:allow(gpui.base.text)
    var source:Range;

    /**
     * Whether each rendered character came from a source character of the
     * same length, so that part of the segment maps to part of its source.
     * A decoded entity or an escape maps only as a whole, even an entity
     * whose characters take as many bytes as its source, like `&acE;`.
     */
    @:allow(gpui.base.text)
    var linear:Bool;

    public function new(rendered:Range, source:Range, linear:Bool) {
        this.rendered = rendered;
        this.source = source;
        this.linear = linear;
    }

    public function equals(other:Null<SourceSegment>):Bool {
        return other != null && rendered.equals(other.rendered) && source.equals(other.source) && linear == other.linear;
    }

    public static function arrayEquals(a:Array<SourceSegment>, b:Array<SourceSegment>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

    /**
     * The source range of the rendered `selection`, when every selected
     * byte maps to source (Rust free `source_range_for_segments`).
     */
    @:allow(gpui.base.text)
    static function sourceRangeForSegments(segments:Array<SourceSegment>, selection:Range):Null<Range> {
        inline function satSub(a:Int, b:Int):Int {
            return a > b ? a - b : 0;
        }
        inline function mappedSourceStart(segment:SourceSegment, renderedStart:Int):Int {
            return segment.linear ? segment.source.start + satSub(renderedStart, segment.rendered.start) : segment.source.start;
        }
        inline function mappedSourceEnd(segment:SourceSegment, renderedEnd:Int):Int {
            return segment.linear ? segment.source.start + satSub(renderedEnd < segment.rendered.end ? renderedEnd : segment.rendered.end,
                segment.rendered.start) : segment.source.end;
        }

        if (selection.start >= selection.end) {
            return null;
        }

        var first:Null<SourceSegment> = null;
        var renderedEnd = 0;
        var sourceStart = 0;
        var sourceEnd = 0;
        for (segment in segments) {
            if (!(segment.rendered.start < selection.end && segment.rendered.end > selection.start))
                continue;
            if (first == null) {
                first = segment;
                if (first.rendered.start > selection.start) {
                    return null;
                }
                renderedEnd = first.rendered.end;
                sourceStart = mappedSourceStart(first, selection.start);
                sourceEnd = mappedSourceEnd(first, selection.end);
                continue;
            }
            if (segment.rendered.start > renderedEnd) {
                return null;
            }
            if (segment.rendered.end > renderedEnd)
                renderedEnd = segment.rendered.end;
            sourceEnd = mappedSourceEnd(segment, selection.end);
        }
        if (first == null)
            return null;
        return renderedEnd >= selection.end ? new Range(sourceStart, sourceEnd) : null;
    }

    public function toString():String {
        return 'SourceSegment { rendered: $rendered, source: $source, linear: $linear }';
    }

}
