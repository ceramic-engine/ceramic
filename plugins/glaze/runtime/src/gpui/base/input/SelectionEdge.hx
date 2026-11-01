// Ported from gpui-kit 0.8.1: crates/base/src/touch_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/** One end of a selection, as a touch handle grabs it. */
enum abstract SelectionEdge(Int) {

    /** The end before the first selected character. */
    var Start = 0;

    /** The end after the last selected character. */
    var End = 1;

    /** The end that stays put while this one is dragged. */
    public inline function opposite():SelectionEdge {
        return this == 0 ? End : Start;
    }

}
