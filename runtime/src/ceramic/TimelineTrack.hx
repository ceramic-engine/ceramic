package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/** A track meant to be updated by a timeline.
    Base implementation doesn't do much by itself.
    Create subclasses to implement details */
class TimelineTrack<K:TimelineKeyframe> extends Entity {

    /** Track size. Default `0`, meaning this track won't do anything.
        By default, because `autoFitSize` is `true`, adding new keyframes to this
        track will update `size` accordingly so it may not be needed to update `size` explicitly.
        Setting `size` to `-1` means the track will never finish. */
    public var size:Float = 0;

    /** If set to `true` (default), adding keyframes to this track will update
        its size accordingly to match last keyframe time. */
    public var autoFitSize:Bool = true;

    /** Whether this track should loop. Ignored if track's `size` is `-1` (not defined). */
    public var loop:Bool = false;

    /** Whether this track is locked or not.
        A locked track doesn't get updated by the timeline it is attached to, if any. */
    public var locked:Bool = false;

    /** Timeline on which this track is added to */
    @:allow(ceramic.Timeline)
    public var timeline(default, null):Timeline = null;

    /** Position on this track.
        Gets back to zero when `loop=true` and position reaches a defined `size`. */
    public var position(default, null):Float = 0;

    /** The key frames on this track. */
    public var keyframes(default, null):ReadOnlyArray<K> = [];

    /** The keyframe right before or equal to current time, if any. */
    public var before(default, null):K = null;

    /** The keyframe right after current time, if any. */
    public var after(default, null):K = null;

    /** The index of the last resolved `key index before`. Used internally. */
    private var keyframeBeforeIndex:Int = -1;

    /** The index of the last resolved `key index after`. Used internally. */
    private var keyframeAfterIndex:Int = -1;

    public function new() {

        super();

    }

    override function destroy() {

        if (timeline != null && !timeline.destroyed) {
            timeline.remove(cast this);
        }

        super.destroy();

    }

    /** Seek the given position (in frames) in the track.
        Will take care of clamping `position` or looping it depending on `size` and `loop` properties. */
    final public function seek(targetPosition:Float):Void {

        inlineSeek(targetPosition);

    }

    @:allow(ceramic.Timeline)
    inline function inlineSeek(targetPosition:Float, forceSeek:Bool = false, forceChange:Bool = false):Void {

        // Continue only if target position is different than current position
        if (forceSeek || targetPosition != position) {

            if (size > 0) {
                if (targetPosition > size) {
                    if (loop) {
                        targetPosition = targetPosition % size;
                    }
                    else {
                        targetPosition = size;
                    }
                }
            }
            else if (size == 0) {
                targetPosition = 0;
            }

            if (targetPosition < 0) {
                targetPosition = 0;
            }

            // If position has changed, compute surrounding keyframes and apply changes
            if (targetPosition != position) {
                position = targetPosition;

                // Compute before/after keyframes
                computeKeyframeBefore();
                computeKeyframeAfter();

                // Apply changes
                apply(forceChange);
            }
        }

    }

    /** Add a keyframe to this track */
    public function add(keyframe:K):Void {

        var mutableKeyframes:Array<TimelineKeyframe> = cast keyframes.original;

        // Insert keyframe at correct location
        var len = mutableKeyframes.length;
        var i = 0;
        var didInsert = false;
        while (i < len) {
            var next = mutableKeyframes.unsafeGet(i);
            if (next.index == keyframe.index) {
                log.warning('Replacing existing keyframe at index ${keyframe.index}');
                mutableKeyframes.unsafeSet(i, keyframe);
                didInsert = true;
                break;
            }
            else if (next.index > keyframe.index) {
                mutableKeyframes.insert(i, keyframe);
                didInsert = true;
                break;
            }
            i++;
        }
        if (!didInsert) {
            mutableKeyframes.push(keyframe);
        }

        if (autoFitSize) {
            fitSize();
        }

        if (timeline != null && timeline.autoFitSize) {
            timeline.fitSize();
        }

        keyframeBeforeIndex = -1;
        keyframeAfterIndex = -1;

        computeKeyframeBefore();
        computeKeyframeAfter();

        apply(true);

    }

    /** Remove a keyframe from this track */
    public function remove(keyframe:K):Void {

        var index = keyframes.indexOf(keyframe);
        if (index != -1) {
            var mutableKeyframes:Array<TimelineKeyframe> = cast keyframes.original;
            mutableKeyframes.splice(index, 1);

            if (autoFitSize) {
                fitSize();
            }
    
            if (timeline != null && timeline.autoFitSize) {
                timeline.fitSize();
            }

            keyframeBeforeIndex = -1;
            keyframeAfterIndex = -1;
    
            computeKeyframeBefore();
            computeKeyframeAfter();

            apply(true);
        }
        else {
            log.warning('Failed to remove keyframe: keyframe not found in list');
        }

    }

    /** Update `size` property to make it fit
        the index of the last keyframe on this track. */
    public function fitSize():Void {

        if (keyframes.length > 0) {
            size = keyframes[keyframes.length - 1].index;
        }
        else {
            size = 0;
        }

    }

    /** Apply changes that this track is responsible of. Usually called after `update(delta)` or `seek(time)`. */
    public function apply(forceChange:Bool = false):Void {

        // Override in subclasses

    }

    public function findKeyframeAtIndex(index:Int):Null<K> {

        var keyframe = findKeyframeBefore(index);
        if (keyframe != null && keyframe.index == index) {
            return keyframe;
        }
        return null;

    }

    /** Find the keyframe right before or equal to given `position` */
    public function findKeyframeBefore(position:Float):Null<K> {

        var result:K = null;

        var index = -1;
        var len = keyframes.length;
        while (index + 1 < len) {
            var keyframe = keyframes[index + 1];
            if (keyframe.index > position) {
                // Not valid, stop
                break;
            }

            // That one is valid
            result = keyframe;
            index++;
        }

        return result;

    }

    /** Find the keyframe right after given `position` */
    public function findKeyframeAfter(position:Float):Null<K> {

        var result:K = null;

        var index = -1;
        var len = keyframes.length;
        while (index + 1 < len) {
            var keyframe = keyframes[index + 1];
            if (keyframe.index > position) {
                // Not valid, stop
                break;
            }

            // That one is valid
            result = keyframe;
            index++;
        }

        return result;

    }

    /** Internal. Compute `before` keyframe, if any matching. */
    inline function computeKeyframeBefore():Void {
        
        var result:K = null;
        var index = keyframeBeforeIndex;

        // Check if last used keyframe is still valid
        if (index != -1) {
            result = keyframes[index];
            if (result.index <= position) {
                // K was before, check that the following one is not before as well
                var keyframeAfter= keyframes[index + 1];
                while (keyframeAfter != null && keyframeAfter.index <= position) {
                    // Yes, it is! Increment index.
                    result = keyframeAfter;
                    index++;
                    keyframeAfter = keyframes[index + 1];
                }
            }
            else {
                // K index is later, not valid
                result = null;
            }
        }
        
        // Didn't find anything, compute from beginning
        if (result == null) {
            index = -1;
            var len = keyframes.length;
            while (index + 1 < len) {
                var keyframe = keyframes[index + 1];
                if (keyframe.index > position) {
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
        before = result;

    }

    /** Internal. Compute `after` keyframe, if any matching. */
    inline function computeKeyframeAfter():Void {
        
        var result:K = null;
        var index = keyframeAfterIndex;

        // Check if last used keyframe is still valid
        if (index != -1) {
            result = keyframes[index];
            if (result != null) {
                if (result.index > position) {
                    // K is still later, check that the previous one is not later as well
                    if (index > 0) {
                        var keyframeBefore = keyframes[index - 1];
                        while (keyframeBefore != null && keyframeBefore.index > position) {
                            // Yes, it is! Decrement index.
                            result = keyframeBefore;
                            index--;
                            keyframeBefore = index > 0 ? keyframes[index - 1] : null;
                        }
                    }
                }
                else {
                    // K index is before, not valid
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
                if (keyframe.index <= position) {
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
        after = result;

    }

}
