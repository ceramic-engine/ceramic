// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.base.text.PendingReveal.RevealReportCell;

/**
 * The start of a pending reveal, as rendering hands it to the `Inline` that
 * lays that text out.
 */
class RevealRequest {

    final key:TextLeafKey;
    final offset:Int;
    final report:RevealReportCell;

    @:allow(gpui.base.text)
    function new(key:TextLeafKey, offset:Int, report:RevealReportCell) {
        this.key = key;
        this.offset = offset;
        this.report = report;
    }

    /** The start of the reveal, when it is in `key`'s text between `start` and `end`, rebased to `start`. */
    public function at(key:Null<TextLeafKey>, start:Int, end:Int):Null<RevealAt> {
        if (!TextLeafKey.eq(key, this.key)) {
            return null;
        }
        return new RevealAt(offset, report).rebase(start, end);
    }

}
