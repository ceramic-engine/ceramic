// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Bounds;
import glaze.kit.base.text.PendingReveal.RevealReport;
import glaze.kit.base.text.PendingReveal.RevealReportCell;

/** The start of a pending reveal, in the byte space of one run of text. */
class RevealAt {

    final _offset:Int;
    final reportCell:RevealReportCell;

    @:allow(glaze.kit.base.text)
    function new(offset:Int, report:RevealReportCell) {
        _offset = offset;
        this.reportCell = report;
    }

    public inline function offset():Int {
        return _offset;
    }

    /** The reveal in the text between `start` and `end`, rebased to `start`, or `null` when it starts outside it. */
    public function rebase(start:Int, end:Int):Null<RevealAt> {
        return _offset >= start && _offset < end ? new RevealAt(_offset - start, reportCell) : null;
    }

    /**
     * The reveal moved into the text between `start` and `end` and rebased to
     * `start`: one before it moves to its first character, one after it to its end.
     */
    public function clamp(start:Int, end:Int):RevealAt {
        final offset = _offset < start ? start : (_offset > end ? end : _offset);
        return new RevealAt(offset - start, reportCell);
    }

    /**
     * Report where the line the reveal starts on was laid out, in window
     * coordinates, and whether it was inside the visible area.
     */
    public function report(line:Bounds, visible:Bool):Void {
        reportCell.value = new RevealReport(line, visible);
    }

}
