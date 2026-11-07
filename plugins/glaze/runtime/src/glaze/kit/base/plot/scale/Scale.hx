// Ported from gpui-kit 0.8.1: crates/base/src/plot/scale.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot.scale;

/**
 * A scale maps domain values to pixel positions (Rust trait `Scale<T>`).
 *
 * `PlotValue` (the sealed number trait of `f32`, `f64` and `Decimal`) is
 * `Float` in the port: the charts take their values as `Float` (an `f64`).
 */
interface Scale<T> {

    /**
     * Get the tick of the scale, or `null` when the value has no position.
     */
    function tick(value:T):Null<Float>;

    /**
     * The index of the domain value whose position is nearest `tick`; `0`
     * for an empty domain or a scale without discrete positions (the Rust
     * default).
     */
    function nearestIndex(tick:Float):Int;

}
