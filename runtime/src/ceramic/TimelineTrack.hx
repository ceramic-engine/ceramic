package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * Base class for animation tracks in a timeline system.
 * 
 * A TimelineTrack manages a sequence of keyframes that define how a value
 * changes over time. The track handles:
 * - Keyframe storage and ordering
 * - Position tracking and seeking
 * - Interpolation between keyframes
 * - Automatic size adjustment
 * 
 * This is an abstract base class. Concrete implementations include:
 * - TimelineFloatTrack: Animates numeric values
 * - TimelineColorTrack: Animates color values
 * - TimelineBoolTrack: Animates boolean values
 * - TimelineFloatArrayTrack: Animates arrays of numbers
 * 
 * Tracks are typically added to a Timeline which coordinates their playback.
 * 
 * @param K The keyframe type this track uses (must extend TimelineKeyframe)
 * 
 * @see Timeline
 * @see TimelineKeyframe
 */
class TimelineTrack<K:TimelineKeyframe> extends Entity {

    /**
     * The total length of this track in frames.
     * 
     * - Default is 0 (track won't animate)
     * - When autoFitSize is true (default), automatically adjusts to the last keyframe's index
     * - Set to -1 for an infinite track that never finishes
     * 
     * The actual duration = size / timeline.fps
     */
    public var size:Int = 0;

    /**
     * Whether the track should automatically adjust its size to match the last keyframe.
     * When true (default), you don't need to manually set the track size.
     */
    public var autoFitSize:Bool = true;

    /**
     * Whether this track should loop back to the beginning when it reaches the end.
     * Ignored if size is -1 (infinite track).
     * Default is false (tracks don't loop independently, controlled by timeline).
     */
    public var loop:Bool = false;

    /**
     * Whether this track is locked from timeline updates.
     * When true, the track won't be updated when its timeline advances.
     * Useful for temporarily disabling specific animations.
     */
    public var locked:Bool = false;

    /**
     * The timeline that owns this track.
     * Set automatically when the track is added to a timeline.
     * Null if the track is not attached to any timeline.
     */
    @:allow(ceramic.Timeline)
    public var timeline(default, null):Timeline = null;

    /**
     * Current playback position in frames.
     * 
     * - Can be fractional for smooth interpolation
     * - Wraps back to 0 when looping is enabled and size is reached
     * - Updated automatically by the timeline or manually with seek()
     */
    public var position(default, null):Float = 0;

    /**
     * Array of keyframes defining the animation.
     * Keyframes are automatically kept sorted by their index (time position).
     * Use add() and remove() to modify the keyframe list.
     */
    public var keyframes(default, null):ReadOnlyArray<K> = [];

    /**
     * The keyframe at or immediately before the current position.
     * Used as the start point for interpolation.
     * Null if position is before the first keyframe.
     */
    public var before(default, null):K = null;

    /**
     * The keyframe immediately after the current position.
     * Used as the end point for interpolation.
     * Null if position is after the last keyframe.
     */
    public var after(default, null):K = null;

    /**
     * The index of the last resolved `key index before`. Used internally.
     */
    private var keyframeBeforeIndex:Int = -1;

    /**
     * The index of the last resolved `key index after`. Used internally.
     */
    private var keyframeAfterIndex:Int = -1;

    /**
     * Create a new timeline track.
     * The track starts empty with no keyframes.
     */
    public function new() {

        super();

    }

    override function destroy() {

        if (timeline != null && !timeline.destroyed) {
            timeline.remove(cast this);
        }

        super.destroy();

    }

    /**
     * Jump to a specific position in the track.
     * Handles looping and clamping based on track settings.
     * Updates the before/after keyframes and applies the change.
     * 
     * @param targetPosition The frame index to seek to
     */
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

    /**
     * Add a keyframe to this track.
     * 
     * - Keyframes are automatically sorted by index
     * - If a keyframe already exists at the same index, it's replaced
     * - Updates track size if autoFitSize is true
     * - Immediately applies the change
     * 
     * @param keyframe The keyframe to add
     */
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

    /**
     * Remove a keyframe from this track.
     * 
     * - Updates track size if autoFitSize is true
     * - Immediately applies the change
     * 
     * @param keyframe The keyframe to remove
     */
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

    /**
     * Adjust the track size to match the last keyframe's index.
     * Called automatically when autoFitSize is true and keyframes are added/removed.
     */
    public function fitSize():Void {

        if (keyframes.length > 0) {
            size = keyframes[keyframes.length - 1].index;
        }
        else {
            size = 0;
        }

    }

    /**
     * Apply the current animation state to the target property.
     * This method should be overridden in subclasses to implement
     * the actual property updates and interpolation.
     * 
     * Called automatically when the track position changes.
     * 
     * @param forceChange If true, forces the update even if the value hasn't changed
     */
    public function apply(forceChange:Bool = false):Void {

        // Override in subclasses

    }

    /**
     * Find a keyframe at exactly the specified index.
     * 
     * @param index The frame index to search for
     * @return The keyframe at that index, or null if none exists
     */
    public function findKeyframeAtIndex(index:Int):Null<K> {

        var keyframe = findKeyframeBefore(index);
        if (keyframe != null && keyframe.index == index) {
            return keyframe;
        }
        return null;

    }

    /**
     * Find the keyframe at or before a given position.
     * Used to determine the start point for interpolation.
     * 
     * @param position The position to search from
     * @return The keyframe at or before the position, or null if none exists
     */
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

    /**
     * Find the first keyframe after a given position.
     * Used to determine the end point for interpolation.
     * 
     * @param position The position to search from
     * @return The keyframe after the position, or null if none exists
     */
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

    /**
     * Internal. Compute `before` keyframe, if any matching.
     */
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

    /**
     * Internal. Compute `after` keyframe, if any matching.
     */
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
