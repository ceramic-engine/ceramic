// Ported from gpui-pre 0.3.10: src/spring.rs (SpringAnimation)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * A stateful spring animation targeting a value or projected path.
 *
 * Rust starts from `SpringAnimation<()>` (no target yet) and `to()` changes the
 * type. Here `new SpringAnimation(config)` has a null target until `to()` (or
 * `toValue()`, `toPhase()`, `toBool()`) returns the typed animation.
 *
 * Builder methods modify this instance and return it.
 */
class SpringAnimation<T> {

    public final config:SpringConfig;

    public final target:SpringTarget<T>;

    public var epsilon(default, null):Float;

    /**
     * The coordinate used when the element has no prior spring state
     * (null: start at the target).
     */
    public var initial(default, null):Null<Float>;

    public var playback(default, null):SpringPlayback;

    /**
     * Creates a spring animation builder.
     */
    public function new(config:SpringConfig, ?target:SpringTarget<T>) {

        this.config = config;
        this.target = target;
        this.epsilon = Spring.DEFAULT_SPRING_EPSILON;
        this.initial = null;
        this.playback = Running;

    }

    /**
     * Sets the value or path targeted by this spring.
     */
    public function to<O>(target:SpringTarget<O>):SpringAnimation<O> {

        final result = new SpringAnimation<O>(config, target);
        result.epsilon = epsilon;
        result.initial = initial;
        result.playback = playback;
        return result;

    }

    /**
     * `to()` with an `f32`, `Pixels` or `Rems` target.
     */
    public inline function toValue(target:Float):SpringAnimation<Float> {

        return to(new SpringValueTarget(target));

    }

    /**
     * `to()` with an `AnimationPhase` target.
     */
    public inline function toPhase(target:AnimationPhase):SpringAnimation<AnimationPhase> {

        return to(new SpringPhaseTarget(target));

    }

    /**
     * `to()` with a `bool` target (1 for `true`, 0 for `false`), resolved as an `AnimationPhase`.
     */
    public inline function toBool(target:Bool):SpringAnimation<AnimationPhase> {

        return to(SpringPhaseTarget.ofBool(target));

    }

    /**
     * Sets the settling tolerance in the target's scalar coordinate space.
     */
    public function withEpsilon(epsilon:Float):SpringAnimation<T> {

        this.epsilon = epsilon;
        return this;

    }

    /**
     * Sets how the spring advances or resolves its current value.
     * (Rust `playback()`, renamed because it clashes with the field.)
     */
    public function withPlayback(playback:SpringPlayback):SpringAnimation<T> {

        this.playback = playback;
        return this;

    }

    /**
     * Sets the coordinate used when this element has no prior spring state.
     * Rust's `from(initial: T)` stores `initial.target()`: this takes a target
     * of the same type, see `fromValue()` for the scalar form.
     */
    public function from(initial:SpringTarget<T>):SpringAnimation<T> {

        this.initial = initial.target();
        return this;

    }

    /**
     * `from()` with the scalar coordinate (the value itself for `f32`, `Pixels`,
     * `Rems` and `AnimationPhase`, 0 or 1 for `bool`).
     */
    public function fromValue(initial:Float):SpringAnimation<T> {

        this.initial = initial;
        return this;

    }

}
