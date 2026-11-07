// Ported from gpui-kit 0.8.1: crates/base/src/plot/scale/ordinal.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-scale/ordinal
package gpui.base.plot.scale;

/**
 * Maps discrete domain values to range values, cycling through the range.
 * Domain values are compared with `==` (value equality for strings and
 * numbers, like Rust's `PartialEq`).
 */
class ScaleOrdinal<D, R> {

    var domainValues:Array<D>;

    var rangeValues:Array<R>;

    var unknownValue:Null<R> = null;

    public function new(?domain:Array<D>, ?range:Array<R>) {
        domainValues = domain != null ? domain : [];
        rangeValues = range != null ? range : [];
    }

    /**
     * Set the domain to the specified array of values.
     */
    public function domain(domain:Array<D>):ScaleOrdinal<D, R> {
        domainValues = domain;
        return this;
    }

    /**
     * Set the range of the ordinal scale to the specified array of values.
     */
    public function range(range:Array<R>):ScaleOrdinal<D, R> {
        rangeValues = range;
        return this;
    }

    /**
     * Set the output value of the scale for unknown input values and returns this scale.
     */
    public function unknown(unknown:R):ScaleOrdinal<D, R> {
        unknownValue = unknown;
        return this;
    }

    /**
     * Given a value in the input domain, returns the corresponding value in the output range.
     */
    public function map(value:D):Null<R> {
        for (index in 0...domainValues.length) {
            if (domainValues[index] == value) {
                if (rangeValues.length == 0) {
                    return null;
                }
                return rangeValues[index % rangeValues.length];
            }
        }
        return unknownValue;
    }

}
