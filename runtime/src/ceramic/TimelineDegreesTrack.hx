package ceramic;

/**
 * A specialized timeline track for animating rotation values in degrees.
 * 
 * TimelineDegreesTrack handles the complexities of angular interpolation,
 * automatically choosing the shortest path between angles. For example,
 * animating from 350° to 10° will rotate 20° clockwise, not 340°
 * counter-clockwise.
 * 
 * Key features:
 * - Automatic angle normalization (0-360 range)
 * - Shortest path interpolation (never more than 180°)
 * - Smooth transitions across the 0°/360° boundary
 * - Support for all standard easing functions
 * 
 * Common uses:
 * - Object rotation animations
 * - Compass/direction indicators
 * - Circular UI elements
 * - Any property representing angular values
 * 
 * Example usage:
 * ```haxe
 * var track = new TimelineDegreesTrack();
 * 
 * // Rotate from 0° to 270° (will go clockwise)
 * track.add(new TimelineFloatKeyframe(0, 0, LINEAR));
 * track.add(new TimelineFloatKeyframe(270, 30, EASE_IN_OUT));
 * 
 * // Then to 45° (will take shortest path: 270° -> 360° -> 45°)
 * track.add(new TimelineFloatKeyframe(45, 60, EASE_OUT));
 * 
 * track.onChange(this, t -> {
 *     myObject.rotation = t.value;
 * });
 * 
 * timeline.add(track);
 * ```
 * 
 * @see TimelineFloatKeyframe
 * @see TimelineTrack
 * @see Timeline
 * @see GeometryUtils
 */
class TimelineDegreesTrack extends TimelineTrack<TimelineFloatKeyframe> {

    /**
     * Event triggered when the degree value changes.
     * Fired whenever the interpolated angle is different from the previous frame.
     * 
     * @param track This track instance (for convenience in handlers)
     */
    @event function change(track:TimelineDegreesTrack);

    /**
     * The current interpolated angle in degrees.
     * Always normalized to the 0-360 range.
     * Updated automatically as the timeline plays.
     * Default is 0.0.
     */
    public var value:Float = 0.0;

    /**
     * Apply the current timeline position to update the angle value.
     * 
     * Performs smart angular interpolation:
     * - Normalizes all angles to 0-360 range
     * - Chooses the shortest rotation path (max 180°)
     * - Handles wrapping across the 0°/360° boundary
     * - Applies easing to the interpolated value
     * 
     * For example:
     * - 350° to 10° animates as 350° -> 360° -> 10° (20° total)
     * - 10° to 350° animates as 10° -> 0° -> 350° (-20° total)
     * 
     * @param forceChange If true, triggers the change event even if value hasn't changed
     */
    override function apply(forceChange:Bool = false):Void {

        var prevValue:Float = value;
        var newValue:Float = value;

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

            // Normalize angles to 0-360 range
            var beforeValue = GeometryUtils.clampDegrees(before.value);
            var afterValue = GeometryUtils.clampDegrees(after.value);

            // Calculate shortest path (never more than 180 degrees)
            var delta = afterValue - beforeValue;
            if (delta > 180) {
                afterValue -= 360;
            }
            else if (delta < -180) {
                afterValue += 360;
            }

            // Interpolate with easing
            newValue =
                beforeValue
                + (afterValue - beforeValue) * Tween.ease(
                    after.easing,
                    ratio
                );

            // Normalize result back to 0-360 range
            newValue = GeometryUtils.clampDegrees(newValue);
        }
        else if (after != null) {
            // Before first keyframe - use first keyframe's angle
            newValue = GeometryUtils.clampDegrees(after.value);
        }
        else if (before != null) {
            // After last keyframe - use last keyframe's angle
            newValue = GeometryUtils.clampDegrees(before.value);
        }

        // Emit change event if angle has changed
        if (forceChange || prevValue != newValue) {
            value = newValue;
            emitChange(this);
        }

    }

}