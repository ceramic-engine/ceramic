// Ported from gpui-kit 0.8.1: crates/base/src/motion/keyframes.rs (Discrete, DiscreteError)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

/**
 * Why a discrete switch point was rejected.
 */
enum DiscreteError {
    InvalidSwitchPoint;
}

/**
 * A value that does not interpolate: it reads `from` before the switch point
 * (0.5 by default) and `to` from it on.
 */
class Discrete<T> {

    final from:T;

    final to:T;

    var switchPoint:Float;

    public function new(from:T, to:T) {
        this.from = from;
        this.to = to;
        this.switchPoint = 0.5;
    }

    /**
     * Sets the progress at which the value switches. Throws
     * `InvalidSwitchPoint` (Rust `Err`) unless it is finite and within `0..=1`.
     */
    public function switchAt(progress:Float):Discrete<T> {
        if (!Math.isFinite(progress) || !(progress >= 0.0 && progress <= 1.0)) {
            throw DiscreteError.InvalidSwitchPoint;
        }
        final discrete = new Discrete(from, to);
        discrete.switchPoint = progress;
        return discrete;
    }

    public inline function sample(progress:Float):T {
        return progress < switchPoint ? from : to;
    }

}
