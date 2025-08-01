package ceramic;

/**
 * A keyframe that stores a boolean value for timeline animations.
 * 
 * Used by TimelineBoolTrack to animate boolean properties that toggle
 * between true and false states at specific points in time.
 * 
 * Boolean keyframes don't interpolate between values - they instantly
 * switch to the keyframe's value when the timeline position reaches
 * or passes the keyframe's index.
 * 
 * Example usage in a timeline:
 * ```haxe
 * var track = new TimelineBoolTrack();
 * track.add(new TimelineBoolKeyframe(false, 0, NONE));    // Start with false
 * track.add(new TimelineBoolKeyframe(true, 30, NONE));    // Switch to true at frame 30
 * track.add(new TimelineBoolKeyframe(false, 60, NONE));   // Back to false at frame 60
 * ```
 * 
 * @see TimelineBoolTrack
 * @see TimelineKeyframe
 * @see Timeline
 */
@:structInit
class TimelineBoolKeyframe extends TimelineKeyframe {

    /**
     * The boolean value stored in this keyframe.
     * This value is applied when the timeline reaches this keyframe's position.
     */
    public var value:Bool;

    /**
     * Create a new boolean keyframe.
     * 
     * @param value The boolean value for this keyframe
     * @param index The frame index (time position) for this keyframe
     * @param easing The easing function (typically NONE for boolean values since they don't interpolate)
     */
    public function new(value:Bool, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}