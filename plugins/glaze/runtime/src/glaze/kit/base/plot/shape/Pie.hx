// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/pie.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-shape/pie
package glaze.kit.base.plot.shape;

import glaze.SpringMath;
import glaze.kit.base.plot.shape.Arc.ArcData;

/**
 * A pie generator, like `d3.pie`: lays data values out as arcs.
 */
class Pie<T> {

    var valueFn:(T) -> Null<Float> = _ -> null;

    var startAngleValue:Float = 0.;

    var endAngleValue:Float = Arc.TAU;

    var padAngleValue:Float = 0.;

    public function new() {}

    /** Set the value of the Pie. */
    public function value(value:(T) -> Null<Float>):Pie<T> {
        valueFn = value;
        return this;
    }

    /** Set the start angle of the Pie. */
    public function startAngle(startAngle:Float):Pie<T> {
        startAngleValue = f(startAngle);
        return this;
    }

    /** Set the end angle of the Pie. */
    public function endAngle(endAngle:Float):Pie<T> {
        endAngleValue = f(endAngle);
        return this;
    }

    /** Set the pad angle of the Pie. */
    public function padAngle(padAngle:Float):Pie<T> {
        padAngleValue = f(padAngle);
        return this;
    }

    /** Get the arcs of the Pie. */
    public function arcs(data:Array<T>):Array<ArcData<T>> {
        final values:Array<{index:Int, data:T, value:Float}> = [];
        var sum = 0.;

        for (idx in 0...data.length) {
            final raw = valueFn(data[idx]);
            if (raw != null) {
                final value = f(raw);
                if (value > 0.) {
                    sum = f(sum + value);
                    values.push({index: idx, data: data[idx], value: value});
                }
            }
        }

        final arcs:Array<ArcData<T>> = [];
        var k = startAngleValue;

        for (item in values) {
            final startAngle = k;
            final angleDelta = sum > 0. ? f(f(item.value / sum) * f(endAngleValue - startAngleValue)) : 0.;
            k = f(k + angleDelta);
            final endAngle = k;

            final arc = new ArcData(item.data, item.index, item.value, startAngle, endAngle);
            arc.padAngle = padAngleValue;
            arcs.push(arc);
        }

        return arcs;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
