package ceramic;

/**
 * A timeline track that animates floating-point values with smooth interpolation.
 * 
 * TimelineFloatTrack is one of the most versatile track types, capable of
 * animating any numeric property. It supports all easing functions for
 * creating natural, dynamic animations.
 * 
 * Common uses:
 * - Position animations (x, y coordinates)
 * - Scale transitions (scaleX, scaleY)
 * - Rotation animations (rotation in degrees)
 * - Alpha/opacity fades
 * - Size changes (width, height)
 * - Any custom numeric property
 * 
 * Example usage:
 * ```haxe
 * var track = new TimelineFloatTrack();
 * 
 * // Animate position from 0 to 500 with easing
 * track.add(new TimelineFloatKeyframe(0, 0, LINEAR));
 * track.add(new TimelineFloatKeyframe(200, 30, EASE_IN));
 * track.add(new TimelineFloatKeyframe(500, 60, ELASTIC_EASE_OUT));
 * 
 * // Apply changes to an object property
 * track.onChange(this, t -> {
 *     myObject.x = t.value;
 * });
 * 
 * timeline.add(track);
 * ```
 * 
 * The track smoothly interpolates between keyframe values based on:
 * - The timeline position
 * - The easing function of the "after" keyframe
 * - The distance between keyframes
 * 
 * @see TimelineFloatKeyframe
 * @see TimelineTrack
 * @see Timeline
 * @see Tween
 */
class TimelineFloatTrack extends TimelineTrack<TimelineFloatKeyframe> {

    /**
     * Event triggered when the float value changes.
     * Fired whenever the interpolated value is different from the previous frame.
     * 
     * @param track This track instance (for convenience in handlers)
     */
    @event function change(track:TimelineFloatTrack);

    /**
     * The current interpolated float value.
     * Updated automatically as the timeline plays, smoothly transitioning
     * between keyframe values based on position and easing.
     * Default is 0.0.
     */
    public var value:Float = 0.0;

    /**
     * Apply the current timeline position to update the float value.
     * 
     * Performs smooth numeric interpolation between keyframes:
     * - Between keyframes: Interpolates using the "after" keyframe's easing function
     * - Before first keyframe: Uses the first keyframe's value
     * - After last keyframe: Uses the last keyframe's value
     * 
     * The interpolation formula is:
     * ```
     * value = before.value + (after.value - before.value) * easedRatio
     * ```
     * 
     * @param forceChange If true, triggers the change event even if value hasn't changed
     */
    override function apply(forceChange:Bool = false):Void {

        var prevValue:Float = value;

        if (before != null && after != null) {
            // Interpolate between two keyframes
            var ratio = (position - before.index) / (after.index - before.index);

            // Clamp ratio to 0-1 range
            if (ratio > 1) {
                ratio = 1;
            }
            else if (ratio < 0) {
                ratio = 0;
            }

            // Linear interpolation with easing applied to the ratio
            value = 
                before.value
                + (after.value - before.value) * Tween.ease(
                    after.easing,
                    ratio
                );
        }
        else if (after != null) {
            // Before first keyframe - use first keyframe's value
            value = after.value;
        }
        else if (before != null) {
            // After last keyframe - use last keyframe's value
            value = before.value;
        }

        // Emit change event if value has changed
        if (forceChange || prevValue != value) {
            emitChange(this);
        }

    }

}