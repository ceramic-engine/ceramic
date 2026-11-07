// Ported from gpui-pre 0.3.10: src/spring.rs (SpringState)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * The instantaneous position and velocity of a spring.
 *
 * Immutable (Rust's `SpringState` is `Copy`): code that assigns a field in
 * Rust creates a new state here.
 */
class SpringState {

    /**
     * The current value in the animated unit.
     */
    public final position:Float;

    /**
     * The current value's change per second.
     */
    public final velocity:Float;

    public inline function new(position:Float = 0.0, velocity:Float = 0.0) {

        this.position = position;
        this.velocity = velocity;

    }

    public function equals(other:SpringState):Bool {

        return position == other.position && velocity == other.velocity;

    }

    public function toString():String {

        return 'SpringState(position: $position, velocity: $velocity)';

    }

}
