package ceramic;

/**
 * A keyframe that stores an array of floating-point values for timeline animations.
 * 
 * Used by TimelineFloatArrayTrack to animate multiple numeric values simultaneously.
 * Each element in the array is interpolated independently, allowing complex
 * multi-value animations with a single track.
 * 
 * Common uses:
 * - Animating multi-dimensional positions (2D/3D coordinates)
 * - Color components as separate values (R, G, B, A)
 * - Complex shape morphing (vertex positions)
 * - Particle system parameters
 * - Any property that requires multiple synchronized values
 * 
 * Example usage in a timeline:
 * ```haxe
 * var track = new TimelineFloatArrayTrack();
 * 
 * // Animate a 2D position
 * track.add(new TimelineFloatArrayKeyframe([0, 0], 0, LINEAR));
 * track.add(new TimelineFloatArrayKeyframe([100, 50], 30, EASE_IN_OUT));
 * track.add(new TimelineFloatArrayKeyframe([200, 0], 60, BOUNCE_EASE_OUT));
 * 
 * // Or animate RGBA values
 * track.add(new TimelineFloatArrayKeyframe([1.0, 0.0, 0.0, 1.0], 0, LINEAR));
 * track.add(new TimelineFloatArrayKeyframe([0.0, 1.0, 0.0, 0.5], 30, EASE_OUT));
 * ```
 * 
 * Note: All keyframes in a track should have arrays of the same length.
 * 
 * @see TimelineFloatArrayTrack
 * @see TimelineKeyframe
 * @see Timeline
 */
@:structInit
class TimelineFloatArrayKeyframe extends TimelineKeyframe {

    /**
     * The array of float values stored in this keyframe.
     * Each element is interpolated independently during animation.
     * All arrays in a track should have the same length.
     */
    public var value:Array<Float>;

    /**
     * Create a new float array keyframe.
     * 
     * @param value The array of numeric values for this keyframe
     * @param index The frame index (time position) for this keyframe
     * @param easing The easing function for interpolation to the next keyframe
     */
    public function new(value:Array<Float>, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}