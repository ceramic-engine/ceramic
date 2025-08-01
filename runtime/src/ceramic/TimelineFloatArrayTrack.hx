package ceramic;

using ceramic.Extensions;

/**
 * A timeline track that animates arrays of floating-point values.
 * 
 * TimelineFloatArrayTrack enables simultaneous animation of multiple
 * numeric values, with each array element interpolated independently.
 * This is ideal for animating multi-dimensional data where all components
 * need to change together in a coordinated way.
 * 
 * Key features:
 * - Element-wise interpolation with easing
 * - Dynamic array length handling
 * - Efficient change detection
 * - Support for arrays of different lengths (uses minimum length)
 * 
 * Common uses:
 * - 2D/3D position animations ([x, y] or [x, y, z])
 * - Multi-channel color animations ([r, g, b, a])
 * - Vertex/shape morphing animations
 * - Complex parameter sets for effects
 * - Any synchronized multi-value animation
 * 
 * Example usage:
 * ```haxe
 * var track = new TimelineFloatArrayTrack();
 * 
 * // Animate a 2D path
 * track.add(new TimelineFloatArrayKeyframe([0, 0], 0, LINEAR));
 * track.add(new TimelineFloatArrayKeyframe([100, 0], 15, EASE_IN));
 * track.add(new TimelineFloatArrayKeyframe([100, 100], 30, EASE_OUT));
 * track.add(new TimelineFloatArrayKeyframe([0, 100], 45, EASE_IN));
 * track.add(new TimelineFloatArrayKeyframe([0, 0], 60, EASE_OUT));
 * 
 * track.onChange(this, t -> {
 *     myObject.x = t.value[0];
 *     myObject.y = t.value[1];
 * });
 * 
 * timeline.add(track);
 * ```
 * 
 * Note: For best results, all keyframes should have arrays of the same length.
 * 
 * @see TimelineFloatArrayKeyframe
 * @see TimelineTrack
 * @see Timeline
 */
class TimelineFloatArrayTrack extends TimelineTrack<TimelineFloatArrayKeyframe> {

    /**
     * Event triggered when any value in the array changes.
     * Fired whenever one or more elements are different from the previous frame.
     * 
     * @param track This track instance (for convenience in handlers)
     */
    @event function change(track:TimelineFloatArrayTrack);

    /**
     * The current interpolated array of float values.
     * Updated automatically as the timeline plays, with each element
     * smoothly transitioning based on keyframes and easing.
     * Default is an empty array.
     */
    public var value:Array<Float> = [];

    /**
     * Apply the current timeline position to update the float array.
     * 
     * Performs element-wise interpolation:
     * - Each array element is interpolated independently
     * - Handles arrays of different lengths (uses minimum length)
     * - Efficiently tracks changes to avoid unnecessary updates
     * - Applies easing to each element's interpolation
     * 
     * @param forceChange If true, triggers the change event even if no values changed
     */
    override function apply(forceChange:Bool = false):Void {

        var didChange = false;

        // Track if any value in the array has changed

        /**
         * Interpolate between two float arrays element by element.
         * Uses the minimum length of both arrays to avoid index errors.
         */
        inline function interpolateArray(result:Array<Float>, from:Array<Float>, to:Array<Float>, ratio:Float) {

            var toLen = to.length;
            var fromLen = from.length;
            var maxLen = toLen > fromLen ? fromLen : toLen; // Use minimum length
            if (result.length > maxLen) {
                result.setArrayLength(maxLen);
            }
            var resLen = result.length;
            for (i in 0...maxLen) {
                var prev:Float = 0.0;
                if (i < resLen) {
                    prev = result.unsafeGet(i);
                }
                else {
                    // Array is growing - this is a change
                    didChange = true;
                }
                var fromVal = from.unsafeGet(i);
                var toVal = to.unsafeGet(i);
                var newVal = fromVal + (toVal - fromVal) * ratio;
                result[i] = newVal;
                if (newVal != prev) {
                    didChange = true;
                }
            }

        }

        /**
         * Copy values from source array to result array.
         * Tracks changes for each element.
         */
        inline function applyArray(result:Array<Float>, array:Array<Float>) {

            var maxLen = array.length;
            if (result.length > maxLen) {
                result.setArrayLength(maxLen);
            }
            var resLen = result.length;
            for (i in 0...maxLen) {
                var prev:Float = 0.0;
                if (i < resLen) {
                    prev = result.unsafeGet(i);
                }
                else {
                    // Array is growing - this is a change
                    didChange = true;
                }
                var newVal = array.unsafeGet(i);
                result[i] = newVal;
                if (newVal != prev) {
                    didChange = true;
                }
            }

        }

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

            // Apply interpolation based on ratio
            if (ratio >= 1) {
                // At or past the after keyframe
                applyArray(value, after.value);
            }
            else if (ratio <= 0) {
                // At or before the before keyframe
                applyArray(value, before.value);
            }
            else {
                // Between keyframes - interpolate with easing
                interpolateArray(value,
                    before.value,
                    after.value,
                    Tween.ease(
                        after.easing,
                        ratio
                    )
                );
            }
        }
        else if (after != null) {
            // Before first keyframe - use first keyframe's values
            applyArray(value, after.value);
        }
        else if (before != null) {
            // After last keyframe - use last keyframe's values
            applyArray(value, before.value);
        }

        // Emit change event if any value has changed
        if (forceChange || didChange) {
            emitChange(this);
        }

    }

}