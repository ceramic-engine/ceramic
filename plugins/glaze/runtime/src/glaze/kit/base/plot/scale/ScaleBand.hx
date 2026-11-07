// Ported from gpui-kit 0.8.1: crates/base/src/plot/scale/band.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-scale/band
package glaze.kit.base.plot.scale;

import glaze.SpringMath;
import glaze.util.MathUtil;

/**
 * Lays the distinct values of a domain out as bands across a range.
 *
 * D3 keys its band domain through an `InternMap`, so a repeated value keeps
 * the index of its first occurrence and the band count follows the distinct
 * values, not the entry count. The port keeps the distinct values in order
 * and compares them with `==` (Rust uses a `HashMap` over `Eq + Hash`).
 */
class ScaleBand<T> implements Scale<T> {

    final indices:Array<T> = [];

    var bandCountValue:Int = 0;

    var maxBandWidthValue:Null<Float> = null;

    final rangeStart:Float;

    final rangeDiff:Float;

    var paddingInnerValue:Float = 0.;

    var paddingOuterValue:Float = 0.;

    /**
     * Lay the distinct values of `domain` out as bands across `range`, from
     * its lower end in domain order.
     */
    public function new(domain:Iterable<T>, range:Array<Float>) {
        for (value in glaze.util.Iterables.asArray(domain)) {
            if (indices.indexOf(value) < 0) {
                indices.push(value);
            }
        }
        final r0 = f(range[0]);
        final r1 = f(range[1]);
        rangeStart = Math.min(r0, r1);
        rangeDiff = Math.abs(f(r1 - r0));
    }

    /**
     * The width of a band: the range divided among the bands, less the inner
     * padding, and no wider than `maxBandWidth` when set.
     */
    public function bandWidth():Float {
        final width = f(avgWidth() * f(1. - paddingInnerValue));
        return maxBandWidthValue == null ? width : Math.min(width, maxBandWidthValue);
    }

    /**
     * Cap the band width at `width`, so a few bands in a wide range stay
     * narrow; a band still starts where it would uncapped. Unset by default.
     */
    public function maxBandWidth(width:Float):ScaleBand<T> {
        maxBandWidthValue = f(width);
        return this;
    }

    /**
     * The distance between the starts of two adjacent bands: the band width
     * plus the inner padding. The whole range for a single band.
     */
    public function step():Float {
        if (len() <= 1) {
            return rangeDiff;
        }
        return f(displayAvgWidth() * ratio());
    }

    /**
     * Lay the range out for `count` bands, the domain taking the leading ones
     * in order and the rest staying empty. A `count` below the domain's
     * length has no effect.
     */
    public function bandCount(count:Int):ScaleBand<T> {
        bandCountValue = count;
        return this;
    }

    /** Set the padding inner of the band. */
    public function paddingInner(paddingInner:Float):ScaleBand<T> {
        paddingInnerValue = f(paddingInner);
        return this;
    }

    /** Set the padding outer of the band. */
    public function paddingOuter(paddingOuter:Float):ScaleBand<T> {
        paddingOuterValue = f(paddingOuter);
        return this;
    }

    /**
     * The number of bands: one per distinct domain value, or the band count
     * when larger.
     */
    @:allow(tests)
    function len():Int {
        return indices.length > bandCountValue ? indices.length : bandCountValue;
    }

    /** The range divided evenly among the bands. */
    function avgWidth():Float {
        final len = len();
        return len == 0 ? 0. : f(rangeDiff / len);
    }

    /** Get the ratio of the band. */
    function ratio():Float {
        return f(1. + f(paddingInnerValue / (len() - 1)));
    }

    /** Get the average width of the band for display. */
    function displayAvgWidth():Float {
        final paddingOuterWidth = f(avgWidth() * paddingOuterValue);
        return f(f(rangeDiff - f(paddingOuterWidth * 2.)) / len());
    }

    public function tick(value:T):Null<Float> {
        final index = indices.indexOf(value);
        if (index < 0) {
            return null;
        }
        final domainLen = len();

        // When there's only one element, place it in the center.
        if (domainLen == 1) {
            return f(rangeStart + f(f(rangeDiff - bandWidth()) / 2.));
        }

        final avgWidth = displayAvgWidth();
        final paddingOuterWidth = f(this.avgWidth() * paddingOuterValue);
        return f(f(rangeStart + f(f(index * avgWidth) * ratio())) + paddingOuterWidth);
    }

    public function nearestIndex(tick:Float):Int {
        final domainLen = len();
        if (domainLen == 0) {
            return 0;
        }

        // Handle single element case
        if (domainLen == 1) {
            return 0;
        }

        final avgWidth = displayAvgWidth();
        final paddingOuterWidth = f(this.avgWidth() * paddingOuterValue);
        final adjustedTick = f(f(f(tick) - rangeStart) - paddingOuterWidth);
        // `as i32` saturates (NaN becomes 0)
        final rounded = MathUtil.round(f(adjustedTick / f(avgWidth * ratio())));
        final index:Int = Math.isNaN(rounded) ? 0 : (rounded > 2147483647. ? 2147483647 : (rounded < -2147483648. ? -2147483648 : Std.int(rounded)));
        final clamped = index > 0 ? index : 0;
        final last = domainLen - 1;
        return clamped < last ? clamped : last;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
