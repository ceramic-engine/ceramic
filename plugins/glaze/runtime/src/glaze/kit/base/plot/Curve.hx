// Ported from gpui-kit 0.8.1: crates/base/src/plot/mod.rs (Curve)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

/**
 * How a `Line` or `Area` connects its points, like d3's curve factories.
 */
enum abstract Curve(Int) {

    /** A smooth curve through every point (`d3.curveNatural`). The default. */
    var Natural = 0;

    /** Straight segments between points (`d3.curveLinear`). */
    var Linear = 1;

    /** A step that holds each value until the next point (`d3.curveStepAfter`). */
    var StepAfter = 2;

    public inline function toInt():Int {
        return this;
    }

}
