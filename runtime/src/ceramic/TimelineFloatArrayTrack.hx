package ceramic;

using ceramic.Extensions;

class TimelineFloatArrayTrack extends TimelineTrack<TimelineFloatArrayKeyframe> {

    @event function change(track:TimelineFloatArrayTrack);

    public var value:Array<Float> = [];

    override function apply(forceChange:Bool = false):Void {

        var didChange = false;

        // TODO didChange when array length changes

        inline function interpolateArray(result:Array<Float>, from:Array<Float>, to:Array<Float>, ratio:Float) {

            var toLen = to.length;
            var fromLen = from.length;
            var maxLen = toLen > fromLen ? fromLen : toLen;
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
                    // Did change, because adding value to array
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
                    // Did change, because adding value to array
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
                applyArray(value, after.value);
            }
            else if (ratio <= 0) {
                applyArray(value, before.value);
            }
            else {
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
            // Current time lower than first keyframe's time
            // Use value of that first keyframe then
            applyArray(value, after.value);
        }
        else if (before != null) {
            // Current time higher than last keyframe's time
            // Use value of that last keyframe then
            applyArray(value, before.value);
        }

        // Emit updateValue event if value has changed
        if (forceChange || didChange) {
            emitChange(this);
        }

    }

}