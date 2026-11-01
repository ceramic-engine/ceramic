// Ported from gpui-kit 0.8.1: crates/component/src/diff/decoration.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.ElementId;
import gpui.Hsla;

/**
 * A background that marks source lines in place, without changing the
 * selection, copying or layout.
 *
 * Decorations paint above the change background and below inline emphasis,
 * search highlights and text; a selected line shows the selection instead.
 * Where several decorations cover a line, the last supplied one is shown.
 */
class DiffDecoration {

    final _range:DiffLineRange;

    var _background:Null<Hsla> = null;

    /**
     * Marks the lines of `range`.
     *
     * A range that ends on the other side covers its start side from `start`
     * onwards and its end side up to `end`.
     */
    public function new(range:DiffLineRange) {
        _range = range;
    }

    /** Sets the background, which defaults to a translucent warning color. */
    public function withBackground(background:Hsla):DiffDecoration {
        final decoration = new DiffDecoration(_range);
        decoration._background = background;
        return decoration;
    }

    public function range():DiffLineRange {
        return _range;
    }

    /** The background set with `withBackground`. */
    public function background():Null<Hsla> {
        return _background;
    }

    @:allow(gpui.component.diff)
    function contains(side:DiffSide, line:Int):Bool {
        final range = _range;
        if (range.isSingleSide())
            return side == range.side() && line >= range.start() && line <= range.end();
        if (side == range.side())
            return line >= range.start();
        return line <= range.end();
    }

}

/**
 * Decorations by file path, in supplied order.
 */
@:allow(gpui.component.diff)
class Decorations {

    final files:Map<String, Array<DiffDecoration>> = new Map();

    function new(decorations:Iterable<DiffDecoration>) {
        for (decoration in decorations) {
            final path = decoration.range().path();
            var list = files.get(path);
            if (list == null) {
                list = [];
                files.set(path, list);
            }
            list.push(decoration);
        }
    }

    /** The decoration shown on a line: the last supplied one covering it. */
    function at(position:DiffLinePosition):Null<DiffDecoration> {
        final list = files.get(position.path());
        if (list == null)
            return null;
        var i = list.length - 1;
        while (i >= 0) {
            if (list[i].contains(position.side(), position.line()))
                return list[i];
            i--;
        }
        return null;
    }

}

/**
 * Gutter markers by line, keeping the first supplied for each line.
 */
@:allow(gpui.component.diff)
class GutterMarkers {

    final lines:Map<String, DiffGutterMarker> = new Map();

    var count = 0;

    function new(markers:Iterable<DiffGutterMarker>) {
        for (marker in markers) {
            final key = marker.position().key();
            if (!lines.exists(key)) {
                lines.set(key, marker);
                count++;
            }
        }
    }

    function isEmpty():Bool {
        return count == 0;
    }

    function at(position:DiffLinePosition):Null<DiffGutterMarker> {
        return lines.get(position.key());
    }

}
