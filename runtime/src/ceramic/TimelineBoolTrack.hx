package ceramic;

class TimelineBoolTrack extends TimelineTrack<TimelineBoolKeyframe> {

    @event function change(track:TimelineBoolTrack);

    public var value:Bool = false;

    override function apply():Void {

        var prevValue = value;

        if (before != null && after != null) {
            // Perform interpolation between two keyframes surrounding current time
            var ratio = (time - before.time) / (after.time - before.time);

            // Clamp
            if (ratio > 1) {
                ratio = 1;
            }
            else if (ratio < 0) {
                ratio = 0;
            }

            // Compute value
            if (ratio >= 1) {
                value = after.value;
            }
            else {
                value = before.value;
            }
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
        if (prevValue != value) {
            emitChange(this);
        }

    }

}