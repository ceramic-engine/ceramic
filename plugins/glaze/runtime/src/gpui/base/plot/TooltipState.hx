// Ported from gpui-kit 0.8.1: crates/base/src/plot/hover.rs (TooltipState)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.plot;

import gpui.Point;

/**
 * The datum the cursor resolved to, returned from `Plot.tooltipState`.
 * Positions are relative to the plot's origin.
 */
class TooltipState {

    /** The hovered datum's index in the plot's data. */
    public final index:Int;

    /** Where a crosshair marking the datum sits. */
    public final crossLine:Point;

    /** The data points to mark, one per series at the hovered datum. */
    public final dots:Array<Point>;

    public function new(index:Int, crossLine:Point, dots:Array<Point>) {
        this.index = index;
        this.crossLine = crossLine;
        this.dots = dots;
    }

}
