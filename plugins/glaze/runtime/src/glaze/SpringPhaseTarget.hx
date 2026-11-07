// Ported from gpui-pre 0.3.10: src/spring.rs (SpringTarget for bool, AnimationPhase)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * A spring target whose output is an `AnimationPhase`: an `AnimationPhase` in
 * Rust, or a `bool` (targeting 1 for `true`, 0 for `false`) with `ofBool()`.
 */
class SpringPhaseTarget implements SpringTarget<AnimationPhase> {

    public final phase:AnimationPhase;

    public inline function new(phase:AnimationPhase) {

        this.phase = phase;

    }

    /**
     * `SpringTarget for bool`.
     */
    public static inline function ofBool(value:Bool):SpringPhaseTarget {

        return new SpringPhaseTarget(value ? 1.0 : 0.0);

    }

    public function target():Float {

        return phase;

    }

    public function resolve(value:Float):AnimationPhase {

        return new AnimationPhase(value);

    }

}
