// Ported from gpui-pre 0.3.10: src/spring.rs (SpringConfig::propagator)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * The exact state-transition matrix of a spring for a constant target and a
 * given frame delta, returned by `SpringConfig.propagator()`.
 *
 * Rust returns a `[[f32; 2]; 2]`: `m00` is `[0][0]`, `m01` is `[0][1]`, and so on.
 * It maps `(displacement, velocity)` to their values after the frame delta.
 */
class SpringPropagator {

    public final m00:Float;

    public final m01:Float;

    public final m10:Float;

    public final m11:Float;

    public inline function new(m00:Float, m01:Float, m10:Float, m11:Float) {

        this.m00 = m00;
        this.m01 = m01;
        this.m10 = m10;
        this.m11 = m11;

    }

    /**
     * The coefficient at `row` and `column` (0 or 1), like `matrix[row][column]` in Rust.
     */
    public function get(row:Int, column:Int):Float {

        return row == 0 ? (column == 0 ? m00 : m01) : (column == 0 ? m10 : m11);

    }

    public function toString():String {

        return '[[$m00, $m01], [$m10, $m11]]';

    }

}
