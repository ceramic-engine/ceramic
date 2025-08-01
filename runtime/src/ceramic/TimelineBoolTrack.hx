package ceramic;

/**
 * A timeline track that animates boolean values.
 * 
 * TimelineBoolTrack manages a sequence of boolean keyframes to control
 * properties that can be either true or false. Unlike numeric tracks,
 * boolean tracks don't interpolate - they instantly switch values when
 * the timeline position reaches or passes a keyframe.
 * 
 * Common uses:
 * - Toggling visibility (visible property)
 * - Enabling/disabling features or behaviors
 * - Triggering state changes at specific times
 * - Creating on/off patterns for effects
 * 
 * Example usage:
 * ```haxe
 * var track = new TimelineBoolTrack();
 * track.add(new TimelineBoolKeyframe(false, 0, NONE));
 * track.add(new TimelineBoolKeyframe(true, 30, NONE));
 * track.add(new TimelineBoolKeyframe(false, 45, NONE));
 * 
 * // Listen for value changes
 * track.onChange(this, t -> {
 *     myObject.visible = t.value;
 * });
 * 
 * // Add to timeline
 * timeline.add(track);
 * ```
 * 
 * @see TimelineBoolKeyframe
 * @see TimelineTrack
 * @see Timeline
 */
class TimelineBoolTrack extends TimelineTrack<TimelineBoolKeyframe> {

    /**
     * Event triggered when the boolean value changes.
     * Fired when the track's value switches between true and false.
     * 
     * @param track This track instance (for convenience in handlers)
     */
    @event function change(track:TimelineBoolTrack);

    /**
     * The current boolean value of this track.
     * Updated automatically as the timeline plays based on keyframe positions.
     * Default is false.
     */
    public var value:Bool = false;

    /**
     * Apply the current timeline position to update the boolean value.
     * 
     * Boolean tracks use a simple rule:
     * - If between keyframes, use the value of the "before" keyframe
     * - If exactly at a keyframe, use that keyframe's value
     * - If before all keyframes, use the first keyframe's value
     * - If after all keyframes, use the last keyframe's value
     * 
     * @param forceChange If true, triggers the change event even if value hasn't changed
     */
    override function apply(forceChange:Bool = false):Void {

        var prevValue = value;

        if (before != null && after != null) {
            // Between two keyframes - use the "before" keyframe value
            // until we reach or pass the "after" keyframe
            var ratio = (position - before.index) / (after.index - before.index);

            // Clamp ratio to 0-1 range
            if (ratio > 1) {
                ratio = 1;
            }
            else if (ratio < 0) {
                ratio = 0;
            }

            // For boolean values, we switch at ratio >= 1 (at or past the keyframe)
            if (ratio >= 1) {
                value = after.value;
            }
            else {
                value = before.value;
            }
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