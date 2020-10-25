package ceramic;

class TimelineFloatTrack extends TimelineTrack<TimelineFloatKeyframe> {

    @event function change(track:TimelineFloatTrack);

    public var value:Float = 0.0;

    override function apply(forceChange:Bool = false):Void {

        var prevValue:Float = value;

        if (before != null && after != null) {
            // Perform interpolation between two keyframes surrounding current position
            var ratio = (position - before.index) / (after.index - before.index);

            // Clamp
            if (ratio > 1) {
                ratio = 1;
            }
            else if (ratio < 0) {
                ratio = 0;
            }

            // Compute value
            // (Use `after`'s easing function to interpolate)
            value = 
                before.value
                + (after.value - before.value) * Tween.ease(
                    after.easing,
                    ratio
                );
        }
        else if (after != null) {
            // Current time lower than first keyframe's time
            // Use value of that first keyframe then
            value = after.value;
        }
        else if (before != null) {
            // Current time higher than last keyframe's time
            // Use value of that last keyframe then
            value = before.value;
        }

        // Emit updateValue event if value has changed
        if (forceChange || prevValue != value) {
            emitChange(this);
        }

    }

}