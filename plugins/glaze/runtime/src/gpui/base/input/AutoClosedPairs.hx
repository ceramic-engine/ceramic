// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/auto_close.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;

/**
 * Delimiters inserted by the editor, retained across edits and history replay.
 *
 * Each pair is stored as two entries of `opens` and `closes` (Rust
 * `Vec<(Range<usize>, Range<usize>)>`). Rust's `Clone` is `clone()`.
 */
class AutoClosedPairs {

    static final EMPTY:AutoClosedPairs = new AutoClosedPairs();

    final opens:Array<Range> = [];

    final closes:Array<Range> = [];

    public function new() {}

    /** A shared empty set (never modify it) */
    public static inline function empty():AutoClosedPairs {
        return EMPTY;
    }

    public function clone():AutoClosedPairs {
        final result = new AutoClosedPairs();
        for (i in 0...opens.length) {
            result.opens.push(opens[i]);
            result.closes.push(closes[i]);
        }
        return result;
    }

    public function record(open:Range, close:Range):Void {
        opens.push(open);
        closes.push(close);
    }

    public function contains(open:Range, close:Range):Bool {
        for (i in 0...opens.length) {
            if (opens[i].equals(open) && closes[i].equals(close))
                return true;
        }
        return false;
    }

    public function containsCloser(cursor:Int, index:Int, len:Int):Bool {
        for (close in closes) {
            if (close.start + index == cursor && close.len() == len)
                return true;
        }
        return false;
    }

    public function adjust(edit:Range, newLen:Int):Void {
        final delta = newLen - edit.len();
        inline function shift(range:Range):Range {
            // `saturating_add_signed`
            final start = range.start + delta;
            final end = range.end + delta;
            return new Range(start > 0 ? start : 0, end > 0 ? end : 0);
        }
        var i = 0;
        while (i < opens.length) {
            final open = opens[i];
            final close = closes[i];
            var keep = true;
            if (edit.end <= open.start) {
                opens[i] = shift(open);
                closes[i] = shift(close);
            }
            else if (edit.start >= open.end && edit.end <= close.start) {
                closes[i] = shift(close);
            }
            else if (edit.start < close.end) {
                keep = false;
            }
            if (keep) {
                i++;
            }
            else {
                opens.splice(i, 1);
                closes.splice(i, 1);
            }
        }
    }

}
