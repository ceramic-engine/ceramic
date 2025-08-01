package ceramic;

/**
 * A timeline track that animates color values with smooth interpolation.
 * 
 * TimelineColorTrack manages a sequence of color keyframes to create
 * smooth color transitions over time. Colors are interpolated in RGB
 * space, with support for all standard easing functions.
 * 
 * Common uses:
 * - Animating object colors (tint, background, text)
 * - Creating color fade effects
 * - Mood transitions in scenes
 * - UI state color changes
 * - Particle color animations
 * 
 * Example usage:
 * ```haxe
 * var track = new TimelineColorTrack();
 * 
 * // Create a rainbow animation
 * track.add(new TimelineColorKeyframe(Color.RED, 0, LINEAR));
 * track.add(new TimelineColorKeyframe(Color.ORANGE, 10, LINEAR));
 * track.add(new TimelineColorKeyframe(Color.YELLOW, 20, LINEAR));
 * track.add(new TimelineColorKeyframe(Color.GREEN, 30, LINEAR));
 * track.add(new TimelineColorKeyframe(Color.BLUE, 40, LINEAR));
 * track.add(new TimelineColorKeyframe(Color.PURPLE, 50, EASE_IN_OUT));
 * 
 * // Apply color changes to a visual
 * track.onChange(this, t -> {
 *     myVisual.color = t.value;
 * });
 * 
 * timeline.add(track);
 * ```
 * 
 * @see TimelineColorKeyframe
 * @see TimelineTrack
 * @see Timeline
 * @see Color
 */
class TimelineColorTrack extends TimelineTrack<TimelineColorKeyframe> {

    /**
     * Event triggered when the color value changes.
     * Fired whenever the interpolated color is different from the previous frame.
     * 
     * @param track This track instance (for convenience in handlers)
     */
    @event function change(track:TimelineColorTrack);

    /**
     * The current interpolated color value.
     * Updated automatically as the timeline plays, smoothly transitioning
     * between keyframe colors based on position and easing.
     * Default is WHITE.
     */
    public var value:Color = Color.WHITE;

    /**
     * Apply the current timeline position to update the color value.
     * 
     * Performs smooth color interpolation between keyframes:
     * - Between keyframes: Interpolates RGB values using the easing function
     * - Before first keyframe: Uses the first keyframe's color
     * - After last keyframe: Uses the last keyframe's color
     * 
     * The interpolation uses the "after" keyframe's easing function to
     * determine how the transition occurs.
     * 
     * @param forceChange If true, triggers the change event even if color hasn't changed
     */
    override function apply(forceChange:Bool = false):Void {

        var prevValue = value;

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

            // Interpolate color using the after keyframe's easing function
            value = Color.interpolate(
                before.value,
                after.value,
                Tween.ease(
                    after.easing,
                    ratio
                )
            );
        }
        else if (after != null) {
            // Before first keyframe - use first keyframe's color
            value = after.value;
        }
        else if (before != null) {
            // After last keyframe - use last keyframe's color
            value = before.value;
        }

        // Emit change event if color has changed
        if (forceChange || prevValue != value) {
            emitChange(this);
        }

    }

}