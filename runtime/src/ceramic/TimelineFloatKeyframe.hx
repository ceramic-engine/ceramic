package ceramic;

/**
 * A keyframe that stores a floating-point value for timeline animations.
 * 
 * Used by TimelineFloatTrack to animate numeric properties over time.
 * Float values are interpolated between keyframes using the specified
 * easing function, creating smooth transitions.
 * 
 * This is one of the most commonly used keyframe types, suitable for
 * animating properties like position, scale, rotation, alpha, and more.
 * 
 * Example usage in a timeline:
 * ```haxe
 * var track = new TimelineFloatTrack();
 * track.add(new TimelineFloatKeyframe(0.0, 0, LINEAR));
 * track.add(new TimelineFloatKeyframe(100.0, 30, EASE_IN_OUT));
 * track.add(new TimelineFloatKeyframe(50.0, 60, ELASTIC_EASE_OUT));
 * ```
 * 
 * @see TimelineFloatTrack
 * @see TimelineKeyframe
 * @see Timeline
 * @see Easing
 */
@:structInit
class TimelineFloatKeyframe extends TimelineKeyframe {

    /**
     * The floating-point value stored in this keyframe.
     * This value is used as a target for interpolation when animating.
     */
    public var value:Float;

    /**
     * Create a new float keyframe.
     * 
     * @param value The numeric value for this keyframe
     * @param index The frame index (time position) for this keyframe
     * @param easing The easing function for interpolation to the next keyframe
     */
    public function new(value:Float, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}