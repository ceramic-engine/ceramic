package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/** A track meant to be updated by a timeline.
    Base implementation doesn't do much by itself.
    Create subclasses to implement details */
class TimelineTrack<Keyframe:TimelineKeyframe> extends Entity {

    /** Track duration. Default `0`, meaning this track won't do anything.
        By default, because `autoFitDuration` is `true`, adding new keyframes to this
        track will update `duration` accordingly so it may not be needed to update `duration` explicitly.
        Setting `duration` to `-1` means the track will never finish. */
    public var duration:Float = 0;

    /** If set to `true` (default), adding keyframes to this track will update
        its duration accordingly to match last keyframe time. */
    public var autoFitDuration:Bool = true;

    /** Whether this track should loop. Ignored if track's `duration` is `-1` (not defined). */
    public var loop:Bool = true;

    /** Whether this track is locked or not.
        A locked track doesn't get updated by the timeline it is attached to, if any. */
    public var locked:Bool = false;

    /** Timeline on which this track is added to */
    @:allow(ceramic.Timeline)
    public var timeline(default, null):Timeline = null;

    /** Elapsed time on this track.
        Gets back to zero when `loop=true` and time reaches a defined `duration`. */
    public var time(default, null):Float = 0;

    /** The key frames on this track. */
    public var keyframes(default, null):ImmutableArray<Keyframe> = [];

    /** The keyframe right before or equal to current time, if any. */
    public var before(default, null):Keyframe = null;

    /** The keyframe right after current time, if any. */
    public var after(default, null):Keyframe = null;

    /** The index of the last resolved `key frame before`. Used internally. */
    private var keyframeBeforeIndex:Int = -1;

    /** The index of the last resolved `key frame after`. Used internally. */
    private var keyframeAfterIndex:Int = -1;

    public function new() {

        super();

    } //new

    /** Seek the given time (in seconds) in the track.
        Will take care of clamping `time` or looping it depending on `duration` and `loop` properties. */
    final public function seek(targetTime:Float):Void {

        inlineSeek(targetTime);

    } //seek

    @:allow(ceramic.Timeline)
    inline function inlineSeek(targetTime:Float):Void {

        // Continue only if target time is different than current time
        if (targetTime != time) {

            if (duration > 0) {
                if (targetTime > duration) {
                    if (loop) {
                        targetTime = targetTime % duration;
                    }
                    else {
                        targetTime = duration;
                    }
                }
            }
            else if (duration == 0) {
                targetTime = 0;
            }

            if (targetTime < 0) {
                targetTime = 0;
            }

            // If time has changed, compute surrounding keyframes and apply changes
            if (targetTime != time) {
                time = targetTime;

                // Compute before/after keyframes
                computeKeyframeBefore();
                computeKeyframeAfter();

                // Apply changes
                apply();
            }
        }

    } //inlineSeek

    /** Add a keyframe to this track */
    public function add(keyframe:Keyframe):Void {

        var mutableKeyframes:Array<TimelineKeyframe> = cast keyframes.mutable;

        // Insert keyframe at correct location
        var len = mutableKeyframes.length;
        var i = 0;
        var didInsert = false;
        while (i < len) {
            var next = mutableKeyframes.unsafeGet(i);
            if (next.time == keyframe.time) {
                warning('Replacing existing keyframe at time ${keyframe.time}');
                mutableKeyframes.unsafeSet(i, keyframe);
                didInsert = true;
                break;
            }
            else if (next.time > keyframe.time) {
                mutableKeyframes.insert(i, keyframe);
                didInsert = true;
                break;
            }
            i++;
        }
        if (!didInsert) {
            mutableKeyframes.push(keyframe);
        }

        if (timeline != null && timeline.autoFitDuration) {
            timeline.fitDuration();
        }

        if (autoFitDuration) {
            fitDuration();
        }

    } //add

    /** Update `duration` property to make it fit
        the time of the last keyframe on this track. */
    public function fitDuration():Void {

        if (keyframes.length > 0) {
            duration = keyframes[keyframes.length - 1].time;
        }
        else {
            duration = 0;
        }

    } //fitDuration

    /** Apply changes that this track is responsible of. Usually called after `update(delta)` or `seek(time)`. */
    public function apply():Void {

        // Override in subclasses

    } //apply

    /** Internal. Compute `before` keyframe, if any matching. */
    inline function computeKeyframeBefore():Void {
        
        var result:TimelineKeyframe = null;
        var index = keyframeBeforeIndex;

        // Check if last used keyframe is still valid
        if (index != -1) {
            result = keyframes[index];
            if (result.time <= time) {
                // Keyframe was before, check that the following one is not before as well
                var keyframeAfter:TimelineKeyframe = keyframes[index + 1];
                while (keyframeAfter != null && keyframeAfter.time <= time) {
                    // Yes, it is! Increment index.
                    result = keyframeAfter;
                    index++;
                    keyframeAfter = keyframes[index + 1];
                }
            }
            else {
                // Keyframe time is later, not valid
                result = null;
            }
        }
        
        // Didn't find anything, compute from beginning
        if (result == null) {
            index = -1;
            var len = keyframes.length;
            while (index + 1 < len) {
                var keyframe = keyframes[index + 1];
                if (keyframe.time > time) {
                    // Not valid, stop
                    break;
                }

                // That one is valid
                result = keyframe;
                index++;
            }
        }

        // Update last used index and return
        keyframeBeforeIndex = index;
        before = cast result;

    } //computeKeyframeBefore

    /** Internal. Compute `after` keyframe, if any matching. */
    inline function computeKeyframeAfter():Void {
        
        var result:TimelineKeyframe = null;
        var index = keyframeAfterIndex;

        // Check if last used keyframe is still valid
        if (index != -1) {
            result = keyframes[index];
            if (result != null) {
                if (result.time > time) {
                    // Keyframe is still later, check that the previous one is not later as well
                    if (index > 0) {
                        var keyframeBefore:TimelineKeyframe = keyframes[index - 1];
                        while (keyframeBefore != null && keyframeBefore.time > time) {
                            // Yes, it is! Decrement index.
                            result = keyframeBefore;
                            index--;
                            keyframeBefore = index > 0 ? keyframes[index - 1] : null;
                        }
                    }
                }
                else {
                    // Keyframe time is before, not valid
                    result = null;
                }
            }
        }
        
        // Didn't find anything, compute from end
        if (result == null) {
            var len = keyframes.length;
            index = len;
            while (index - 1 >= 0) {
                var keyframe = keyframes[index - 1];
                if (keyframe.time <= time) {
                    // Not valid, stop
                    break;
                }

                // That one is valid
                result = keyframe;
                index--;
            }

            // Nothing valid, set index to `-1` then
            if (index >= len) {
                index = -1;
            }
        }

        // Update last used index and return
        keyframeAfterIndex = index;
        after = cast result;

    } //computeKeyframeAfter

} //TimelineTrack
