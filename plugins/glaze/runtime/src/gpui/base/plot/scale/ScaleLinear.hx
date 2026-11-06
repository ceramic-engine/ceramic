// Ported from gpui-kit 0.8.1: crates/base/src/plot/scale/linear.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-scale/linear
package gpui.base.plot.scale;

import gpui.SpringMath;

/**
 * Maps a continuous domain onto a pixel range.
 *
 * Rust's `ScaleLinear<T>` is generic over `f32`, `f64` and `Decimal`. The
 * port computes in `f64` (`ScaleLinear<f64>`), or in `f32` like
 * `ScaleLinear<f32>` when `f32Values` is set. Positions are `f32`.
 */
class ScaleLinear implements Scale<Float> {

    final domainStart:Float;

    final domainDiff:Float;

    final rangeStart:Float;

    final rangeDiff:Float;

    final f32Values:Bool;

    /**
     * Map the extent of `domain` onto `range`: the smallest domain value to
     * `range[0]` and the largest to `range[1]`, so a reversed range such as
     * `[height, 0.]` puts larger values higher.
     */
    public function new(domain:Iterable<Float>, range:Array<Float>, f32Values:Bool = false) {
        var start:Null<Float> = null;
        var end:Null<Float> = null;
        for (value in gpui.util.Iterables.asArray(domain)) {
            final v = f32Values ? f(value) : value;
            if (start == null) {
                start = v;
                end = v;
            }
            else {
                // itertools `minmax_by` with `partial_cmp` (NaN compares equal)
                if (v < start) start = v;
                if (!(v < end)) end = v;
            }
        }
        if (start == null) {
            start = 0.;
            end = 0.;
        }
        this.f32Values = f32Values;
        domainStart = start;
        domainDiff = f32Values ? f(end - start) : end - start;
        rangeStart = f(range[0]);
        rangeDiff = f(f(range[1]) - f(range[0]));
    }

    public function tick(value:Float):Null<Float> {
        if (domainDiff == 0) {
            return null;
        }
        final ratio = f32Values ? f(f(f(value) - domainStart) / domainDiff) : f((value - domainStart) / domainDiff);
        return f(f(ratio * rangeDiff) + rangeStart);
    }

    public function nearestIndex(tick:Float):Int {
        return 0;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
