package ceramic;

using ceramic.Extensions;

/**
 * The computations timeline tracks use to get a value between two keyframes.
 *
 * These are plain static functions with no state, so that anything that needs
 * the value of a track at a given position (a tool, an exporter, a test) gets
 * exactly what `Timeline` plays, without creating tracks.
 *
 * In every function, `ratio` is the progress between the two keyframes
 * (see `ratio()`) and `easing` is the easing of the keyframe being reached.
 *
 * @see TimelineFloatTrack
 * @see TimelineDegreesTrack
 * @see TimelineColorTrack
 * @see TimelineBoolTrack
 * @see TimelineFloatArrayTrack
 */
class TimelineInterpolation {

    /**
     * Progress between two keyframes, within the 0-1 range.
     *
     * @param position Position on the timeline (in frames)
     * @param beforeIndex Frame index of the keyframe at or before the position
     * @param afterIndex Frame index of the keyframe after the position
     */
    public static inline function ratio(position:Float, beforeIndex:Int, afterIndex:Int):Float {

        var ratio = (position - beforeIndex) / (afterIndex - beforeIndex);
        if (ratio > 1) {
            ratio = 1;
        }
        else if (ratio < 0) {
            ratio = 0;
        }
        return ratio;

    }

    /**
     * Float value between two keyframes.
     */
    public static inline function float(before:Float, after:Float, easing:Easing, ratio:Float):Float {

        return before + (after - before) * Tween.ease(easing, ratio);

    }

    /**
     * Angle (in degrees, 0-360) between two keyframes,
     * following the shortest path around the circle.
     */
    public static function degrees(before:Float, after:Float, easing:Easing, ratio:Float):Float {

        // Normalize angles to 0-360 range
        var beforeValue = GeometryUtils.clampDegrees(before);
        var afterValue = GeometryUtils.clampDegrees(after);

        // Calculate shortest path (never more than 180 degrees)
        var delta = afterValue - beforeValue;
        if (delta > 180) {
            afterValue -= 360;
        }
        else if (delta < -180) {
            afterValue += 360;
        }

        // Interpolate with easing, then normalize the result back to 0-360 range
        return GeometryUtils.clampDegrees(
            beforeValue + (afterValue - beforeValue) * Tween.ease(easing, ratio)
        );

    }

    /**
     * Color between two keyframes.
     */
    public static inline function color(before:Color, after:Color, easing:Easing, ratio:Float):Color {

        return Color.interpolate(before, after, Tween.ease(easing, ratio));

    }

    /**
     * Bool value between two keyframes: the value of the first one,
     * until the second one is reached.
     */
    public static inline function bool(before:Bool, after:Bool, ratio:Float):Bool {

        return ratio >= 1 ? after : before;

    }

    /**
     * Float array between two keyframes, written into `result`
     * (resized to the shortest of both arrays).
     *
     * @return `true` if `result` has changed
     */
    public static function floatArray(result:Array<Float>, before:Array<Float>, after:Array<Float>, easing:Easing, ratio:Float):Bool {

        if (ratio >= 1) {
            // At or past the after keyframe
            return copyFloatArray(result, after);
        }
        else if (ratio <= 0) {
            // At or before the before keyframe
            return copyFloatArray(result, before);
        }

        var didChange = false;
        var easedRatio = Tween.ease(easing, ratio);

        var afterLen = after.length;
        var beforeLen = before.length;
        var len = afterLen > beforeLen ? beforeLen : afterLen;
        if (result.length > len) {
            result.setArrayLength(len);
        }

        var resLen = result.length;
        for (i in 0...len) {
            var prev:Float = 0.0;
            if (i < resLen) {
                prev = result.unsafeGet(i);
            }
            else {
                // Array is growing - this is a change
                didChange = true;
            }
            var beforeVal = before.unsafeGet(i);
            var afterVal = after.unsafeGet(i);
            var newVal = beforeVal + (afterVal - beforeVal) * easedRatio;
            result[i] = newVal;
            if (newVal != prev) {
                didChange = true;
            }
        }

        return didChange;

    }

    /**
     * Copy a float array into `result` (resized to match).
     *
     * @return `true` if `result` has changed
     */
    public static function copyFloatArray(result:Array<Float>, array:Array<Float>):Bool {

        var didChange = false;

        var len = array.length;
        if (result.length > len) {
            result.setArrayLength(len);
        }

        var resLen = result.length;
        for (i in 0...len) {
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

        return didChange;

    }

}
