// Ported from gpui-kit 0.8.1: crates/base/src/input/base/cursor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Pixels;
import glaze.Range;

/**
 * One cursor with its selection. Mutable like the Rust `Copy` struct:
 * `copy()` stands for Rust's implicit copies (`*sel`).
 */
class CursorSelection {

    public var id:CursorId;

    public var start:Int;

    public var end:Int;

    public var reversed:Bool;

    public var columnAnchor:Null<ColumnAnchor>;

    public function new(id:CursorId, start:Int, end:Int) {
        this.id = id;
        this.start = start;
        this.end = end;
        this.reversed = false;
        this.columnAnchor = null;
    }

    public inline function len():Int {
        return end > start ? end - start : 0;
    }

    public inline function isEmpty():Bool {
        return start == end;
    }

    public inline function clear():Void {
        start = 0;
        end = 0;
    }

    public inline function contains(offset:Int):Bool {
        return offset >= start && offset < end;
    }

    public inline function cursorOffset():Int {
        return reversed ? start : end;
    }

    public function placeAt(offset:Int, columnAnchor:Null<ColumnAnchor>):Void {
        this.start = offset;
        this.end = offset;
        this.reversed = false;
        this.columnAnchor = columnAnchor;
    }

    public inline function isCollapsed():Bool {
        return isEmpty();
    }

    public function copy():CursorSelection {
        final selection = new CursorSelection(id, start, end);
        selection.reversed = reversed;
        selection.columnAnchor = columnAnchor;
        return selection;
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<CursorSelection>):Bool {
        return other != null && other.id == id && other.start == start && other.end == end && other.reversed == reversed
            && ColumnAnchor.same(other.columnAnchor, columnAnchor);
    }

    /** `From<Range<usize>> for CursorSelection` (default id). */
    public static inline function fromRange(range:Range):CursorSelection {
        return new CursorSelection(CursorId.defaultValue(), range.start, range.end);
    }

    /** `From<CursorSelection> for Range<usize>`. */
    public inline function toRange():Range {
        return new Range(start, end);
    }

    /** A copy of every selection of a list (Rust clones of `Vec<CursorSelection>`). */
    public static function copyAll(selections:Array<CursorSelection>):Array<CursorSelection> {
        return [for (selection in selections) selection.copy()];
    }

}
