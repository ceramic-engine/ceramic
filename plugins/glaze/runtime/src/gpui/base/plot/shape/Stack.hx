// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/stack.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-shape/stack
package gpui.base.plot.shape;

import gpui.SpringMath;

/**
 * Represents a stacked series data point with lower and upper values.
 */
class StackPoint<T> {

    /** The lower value (baseline) */
    public final y0:Float;

    /** The upper value (topline) */
    public final y1:Float;

    /** Reference to the original data */
    public final data:T;

    public function new(y0:Float, y1:Float, data:T) {
        this.y0 = y0;
        this.y1 = y1;
        this.data = data;
    }

}

/**
 * Represents a stacked series.
 */
class StackSeries<T> {

    /** The key for this series */
    public final key:String;

    /** The index of this series */
    public final index:Int;

    /** The points in this series */
    public final points:Array<StackPoint<T>>;

    public function new(key:String, index:Int, points:Array<StackPoint<T>>) {
        this.key = key;
        this.index = index;
        this.points = points;
    }

}

/**
 * A stack generator, like `d3.stack` with the natural key order.
 */
class Stack<T> {

    var dataValues:Array<T> = [];

    var keyValues:Array<String> = [];

    var valueFn:(T, String) -> Null<Float> = (_, _) -> null;

    public function new() {}

    /** Set the data to be stacked */
    public function data(data:Iterable<T>):Stack<T> {
        dataValues = [for (v in data) v];
        return this;
    }

    /** Set the keys (series) for stacking */
    public function keys(keys:Iterable<String>):Stack<T> {
        keyValues = [for (k in keys) k];
        return this;
    }

    /** Set the value accessor function */
    public function value(value:(T, String) -> Null<Float>):Stack<T> {
        valueFn = value;
        return this;
    }

    /** Compute the stacked series */
    public function series():Array<StackSeries<T>> {
        if (dataValues.length == 0 || keyValues.length == 0) {
            return [];
        }

        final n = dataValues.length;
        final m = keyValues.length;

        // Extract values into a 2D matrix: series x data points
        final matrix:Array<Array<Float>> = [];
        for (key in keyValues) {
            matrix.push([for (datum in dataValues) {
                final value = valueFn(datum, key);
                value != null ? f(value) : 0.0;
            }]);
        }

        // Compute the stacks in the natural key order
        final stacks:Array<Array<Array<Float>>> = [for (_ in 0...m) [for (_ in 0...n) [0.0, 0.0]]];
        for (j in 0...n) {
            var y0 = 0.0;
            for (i in 0...m) {
                final y1 = f(y0 + matrix[i][j]);
                stacks[i][j] = [y0, y1];
                y0 = y1;
            }
        }

        // Build the result series
        final result:Array<StackSeries<T>> = [];
        for (i in 0...m) {
            final points = [for (j in 0...n) new StackPoint(stacks[i][j][0], stacks[i][j][1], dataValues[j])];
            result.push(new StackSeries(keyValues[i], i, points));
        }
        return result;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
