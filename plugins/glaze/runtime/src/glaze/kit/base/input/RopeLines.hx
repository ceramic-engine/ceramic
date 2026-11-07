// Ported from gpui-kit 0.8.1: crates/base/src/input/base/rope_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import ropey.Rope;
import ropey.RopeSlice;

using glaze.kit.base.input.RopeExt;

/**
 * An iterator over the lines of a `Rope`. Each line slice includes `\r` if
 * present, but not `\n`. Works with Haxe `for` loops.
 */
class RopeLines {

    final rope:Rope;

    var row:Int;

    final endRow:Int;

    public function new(rope:Rope) {
        this.rope = rope;
        this.row = 0;
        this.endRow = rope.linesLen();
    }

    /** The next line, or null at the end. */
    public function next():Null<RopeSlice> {
        if (row >= endRow) {
            return null;
        }

        final line = rope.sliceLine(row);
        row += 1;
        return line;
    }

    /** Skips `n` lines then returns the next one (Rust `Iterator::nth`). */
    public function nth(n:Int):Null<RopeSlice> {
        row = row + n;
        return next();
    }

    /** The exact number of lines left. */
    public function sizeHint():Int {
        return endRow - row;
    }

    public inline function hasNext():Bool {
        return row < endRow;
    }

    public inline function iterator():RopeLines {
        return this;
    }

}
