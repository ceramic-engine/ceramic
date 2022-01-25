package ceramic;

class TimelineDegreesTrack extends TimelineTrack<TimelineFloatKeyframe> {

    @event function change(track:TimelineDegreesTrack);

    public var value:Float = 0.0;

    override function apply(forceChange:Bool = false):Void {

        var prevValue:Float = value;
        var newValue:Float = value;

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

            var beforeValue = GeometryUtils.clampDegrees(before.value);
            var afterValue = GeometryUtils.clampDegrees(after.value);

            // Always choose shortest path (<= 180 degrees)
            var delta = afterValue - beforeValue;
            if (delta > 180) {
                afterValue -= 360;
            }
            else if (delta < -180) {
                afterValue += 360;
            }

            // Compute value
            // (Use `after`'s easing function to interpolate)
            newValue =
                beforeValue
                + (afterValue - beforeValue) * Tween.ease(
                    after.easing,
                    ratio
                );

            newValue = GeometryUtils.clampDegrees(newValue);
        }
        else if (after != null) {
            // Current time lower than first keyframe's time
            // Use value of that first keyframe then
            newValue = GeometryUtils.clampDegrees(after.value);
        }
        else if (before != null) {
            // Current time higher than last keyframe's time
            // Use value of that last keyframe then
            newValue = GeometryUtils.clampDegrees(before.value);
        }

        // Emit updateValue event if value has changed
        if (forceChange || prevValue != newValue) {
            value = newValue;
            emitChange(this);
        }

    }

}