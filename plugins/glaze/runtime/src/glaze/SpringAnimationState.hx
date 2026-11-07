// Ported from gpui-pre 0.3.10: src/elements/animation.rs (SpringElementState, SpringAnimationElement::request_layout)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * The element state of a `SpringAnimationElement` (Rust `SpringElementState`),
 * kept across frames under the element id, plus the time-based part of
 * `SpringAnimationElement::request_layout` as a pure function of the clock
 * (`advance()`).
 *
 * Times are in seconds, read from `cx.backgroundExecutor().now()`.
 */
class SpringAnimationState {

    public var spring:SpringState;

    public var target:Float;

    public var config:SpringConfig;

    public var initial:Float;

    public var playback:SpringPlayback;

    public var updatedAt:Float;

    public function new(spring:SpringState, target:Float, config:SpringConfig, initial:Float, playback:SpringPlayback, updatedAt:Float) {

        this.spring = spring;
        this.target = target;
        this.config = config;
        this.initial = initial;
        this.playback = playback;
        this.updatedAt = updatedAt;

    }

    /**
     * The state of a newly mounted element: at `initial` (or at the target when
     * `initial` is null), without velocity.
     */
    public static function create(config:SpringConfig, target:Float, initial:Null<Float>, playback:SpringPlayback, now:Float):SpringAnimationState {

        final start:Float = initial != null ? initial : target;
        return new SpringAnimationState(new SpringState(start, 0.0), target, config, start, playback, now);

    }

    /**
     * Advances the spring to `now` with the playback of the previous frame, then
     * applies this frame's configuration, target and playback.
     * The value to render is `spring.position` afterwards.
     *
     * @return Whether the spring is done (no other animation frame needed).
     */
    public function advance(config:SpringConfig, target:Float, epsilon:Float, playback:SpringPlayback, now:Float, reduceMotion:Bool):Bool {

        final elapsed = now - updatedAt;
        switch (this.playback) {
            case Running:
                spring = this.config.step(spring, this.target, elapsed);
            case Paused | Stopped | Completed | Cancelled:
        }

        this.config = config;
        this.target = target;

        final done = switch (playback) {
            case Running:
                if (reduceMotion) {
                    spring = new SpringState(this.target, 0.0);
                    true;
                }
                else {
                    final done = this.config.isSettled(spring, this.target, epsilon);
                    if (done) {
                        spring = new SpringState(this.target, 0.0);
                    }
                    done;
                }
            case Paused:
                true;
            case Stopped:
                spring = new SpringState(spring.position, 0.0);
                true;
            case Completed:
                spring = new SpringState(this.target, 0.0);
                true;
            case Cancelled:
                spring = new SpringState(this.initial, 0.0);
                true;
        }
        this.playback = playback;
        this.updatedAt = now;

        return done;

    }

}
