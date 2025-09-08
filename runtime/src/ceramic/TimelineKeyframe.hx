package ceramic;

/**
 * Represents a keyframe in a timeline animation.
 * 
 * TimelineKeyframe defines a specific point in time within an animation sequence,
 * including the frame index and the easing function to apply when interpolating
 * to the next keyframe.
 * 
 * @see Timeline
 * @see Easing
 */
@:structInit
class TimelineKeyframe {

    public var index:Int;

    public var easing:Easing = NONE;

    public function new(index:Int, easing:Easing) {
        
        this.index = index;
        this.easing = easing;

    }

}
