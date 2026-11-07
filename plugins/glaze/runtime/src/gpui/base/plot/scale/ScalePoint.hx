// Ported from gpui-kit 0.8.1: crates/base/src/plot/scale/point.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-scale/point
package gpui.base.plot.scale;

import gpui.SpringMath;
import gpui.util.MathUtil;

/**
 * Point scale maps discrete domain values to continuous range positions.
 *
 * Points are evenly distributed across the range, with the first and last
 * points aligned to the range boundaries. Domain values are compared with
 * `==`.
 */
class ScalePoint<T> implements Scale<T> {

    final domain:Array<T>;

    final rangeStart:Float;

    final rangeTick:Float;

    /**
     * Place `domain` evenly from `range[0]` to `range[1]`; a single value
     * sits in the middle of the range.
     */
    public function new(domain:Iterable<T>, range:Array<Float>) {
        this.domain = gpui.util.Iterables.toArray(domain);
        final len = this.domain.length;
        final r0 = f(range[0]);
        final rangeDiff = f(f(range[1]) - r0);
        switch len {
            case 0:
                rangeStart = 0.;
                rangeTick = 0.;
            case 1:
                rangeStart = r0;
                rangeTick = rangeDiff;
            case _:
                rangeStart = r0;
                rangeTick = f(rangeDiff / (len - 1));
        }
    }

    /**
     * Returns the position of the domain value at `index`.
     *
     * Equivalent to `tick` on `domain[index]` for a domain of unique values,
     * without searching the domain.
     */
    public function tickAt(index:Int):Null<Float> {
        final len = domain.length;
        if (index >= len || index < 0) {
            return null;
        }
        if (len == 1) {
            return f(rangeStart + f(rangeTick / 2.));
        }
        return f(rangeStart + f(index * rangeTick));
    }

    public function tick(value:T):Null<Float> {
        final index = domain.indexOf(value);
        if (index < 0) {
            return null;
        }
        return tickAt(index);
    }

    public function nearestIndex(tick:Float):Int {
        if (domain.length == 0) {
            return 0;
        }
        if (rangeTick == 0.) {
            return 0;
        }
        final normalizedTick = f(f(tick) - rangeStart);
        final index = MathUtil.round(f(normalizedTick / rangeTick));
        // `as usize` saturates: negative and NaN become 0
        final i:Int = !(index > 0) ? 0 : (index >= domain.length ? domain.length : Std.int(index));
        return i < domain.length - 1 ? i : domain.length - 1;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
