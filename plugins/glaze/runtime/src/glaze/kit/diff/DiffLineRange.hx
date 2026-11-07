// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs (`DiffLineRange`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.diff;

/**
 * An inclusive range of source lines in one file, identified by its
 * `DiffFile.path`.
 *
 * A range starts at `start` on `side()` and ends at `end` on `endSide()`.
 * When both sides are the same it covers that side's lines between the two
 * numbers, in either order. A range ending on the other side covers the
 * patch body between the two lines in patch order, as a Unified view shows it.
 */
class DiffLineRange {

    final _path:String;

    final _side:DiffSide;

    final _start:Int;

    var _endSide:DiffSide;

    final _end:Int;

    /** Creates a range on one side, clamping the lines to at least one. */
    public function new(path:String, side:DiffSide, start:Int, end:Int) {
        _path = path;
        _side = side;
        _start = start < 1 ? 1 : start;
        _endSide = side;
        _end = end < 1 ? 1 : end;
    }

    /** Ends the range on `side`, keeping `end` as its line on that side. */
    public function withEndSide(side:DiffSide):DiffLineRange {
        final range = new DiffLineRange(_path, _side, _start, _end);
        range._endSide = side;
        return range;
    }

    /** The `DiffFile.path` of the file. */
    public inline function path():String {
        return _path;
    }

    /** The side `start` is on. */
    public inline function side():DiffSide {
        return _side;
    }

    public inline function start():Int {
        return _start;
    }

    /** The side `end` is on; the same as `side()` unless set. */
    public inline function endSide():DiffSide {
        return _endSide;
    }

    public inline function end():Int {
        return _end;
    }

    @:allow(glaze.kit.diff)
    function startPosition():DiffLinePosition {
        return new DiffLinePosition(_path, _side, _start);
    }

    @:allow(glaze.kit.diff)
    function endPosition():DiffLinePosition {
        return new DiffLinePosition(_path, _endSide, _end);
    }

    /** Whether the range covers lines on one side only. */
    @:allow(glaze.kit.diff)
    function isSingleSide():Bool {
        return _side == _endSide;
    }

    public function equals(other:Null<DiffLineRange>):Bool {
        return other != null && other._path == _path && other._side == _side && other._start == _start && other._endSide == _endSide
            && other._end == _end;
    }

    public static function same(a:Null<DiffLineRange>, b:Null<DiffLineRange>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    public function toString():String {
        return 'DiffLineRange { path: "$_path", side: $_side, start: $_start, end_side: $_endSide, end: $_end }';
    }

}
