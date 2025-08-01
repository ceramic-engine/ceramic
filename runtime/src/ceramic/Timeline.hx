package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * An animation timeline system that manages keyframe-based animations.
 *
 * Timeline provides:
 * - Frame-based positioning and playback
 * - Multiple animation tracks for different properties
 * - Label system for marking important positions
 * - Looping and one-shot playback modes
 * - Auto-update integration with the game loop
 * - Complete callbacks for animation sequences
 *
 * Timelines are commonly used in:
 * - Fragment animations
 * - Complex UI transitions
 * - Cutscenes and scripted sequences
 * - Any multi-property animations that need synchronization
 *
 * Example usage:
 * ```haxe
 * var timeline = new Timeline();
 * timeline.fps = 30;
 * timeline.size = 120; // 4 seconds at 30 fps
 *
 * // Add animation tracks
 * var track = new TimelineFloatTrack();
 * track.add(new TimelineFloatKeyframe(0, 100));
 * track.add(new TimelineFloatKeyframe(60, 200));
 * timeline.add(track);
 *
 * // Add labels for important positions
 * timeline.setLabel(0, "start");
 * timeline.setLabel(60, "middle");
 * timeline.setLabel(120, "end");
 *
 * // Play animation from a label
 * timeline.animate("start", () -> trace("Animation complete!"));
 * ```
 *
 * @see TimelineTrack
 * @see TimelineKeyframe
 * @see Fragment
 */
class Timeline extends Entity implements Component {

    /**
     * Event triggered when the timeline position reaches a label.
     * Useful for triggering actions at specific points in the animation.
     *
     * @param index The frame index (position) of the label
     * @param name The name of the label that was reached
     */
    @event function startLabel(index:Int, name:String);

    /**
     * Event triggered when the timeline leaves a labeled section.
     * This happens when reaching the next label or the end of the timeline.
     * Useful for cleaning up effects or transitioning to new states.
     *
     * @param index The frame index (position) of the label being left
     * @param name The name of the label being left
     */
    @event function endLabel(index:Int, name:String);

    /**
     * The total length of the timeline in frames.
     *
     * - Default is 0 (timeline won't play)
     * - When `autoFitSize` is true (default), automatically adjusts to match the longest track
     * - Set to -1 for an infinite timeline that never finishes
     *
     * The actual duration in seconds = size / fps
     */
    public var size:Int = 0;

    /**
     * Whether the timeline should automatically adjust its size to match the longest track.
     * When true (default), you don't need to manually set the timeline size.
     */
    public var autoFitSize:Bool = true;

    /**
     * Whether the timeline should loop back to the beginning when it reaches the end.
     * Ignored if size is -1 (infinite timeline).
     * Default is true.
     */
    public var loop:Bool = true;

    /**
     * Whether the timeline automatically updates each frame.
     * When true (default), the timeline advances based on frame delta time.
     * Set to false to manually control timeline playback with seek() or update().
     */
    public var autoUpdate(default, set):Bool = true;
    function set_autoUpdate(autoUpdate:Bool):Bool {
        if (this.autoUpdate != autoUpdate) {
            this.autoUpdate = autoUpdate;
            bindOrUnbindUpdateIfNeeded();
        }
        return autoUpdate;
    }

    /**
     * Timeline playback speed in frames per second.
     * This defines how many timeline frames pass per second of real time.
     *
     * Note: Timeline values are interpolated between frames, so using 30 fps
     * still provides smooth animation even on 60+ fps displays.
     *
     * Default is 30 fps.
     */
    public var fps:Int = 30;

    /**
     * Current playback position in frames.
     *
     * - Starts at 0
     * - Can be fractional for smooth interpolation between frames
     * - Wraps back to 0 when looping is enabled and size is reached
     * - Use seek() to jump to specific positions
     */
    public var position(default, null):Float = 0;

    /**
     * Array of animation tracks managed by this timeline.
     * Each track animates a specific property of an entity.
     * Tracks are updated automatically as the timeline plays.
     */
    public var tracks(default, null):ReadOnlyArray<TimelineTrack<TimelineKeyframe>> = [];

    /**
     * Whether the timeline playback is paused.
     * Setting to true stops all animation while preserving the current position.
     */
    public var paused(default, set):Bool = false;
    function set_paused(paused:Bool):Bool {
        if (this.paused == paused) return paused;
        this.paused = paused;
        bindOrUnbindUpdateIfNeeded();
        return paused;
    }

    /**
     * Array of label names in the timeline.
     * Labels mark important positions for seeking and animation control.
     * Sorted by position (frame index).
     */
    public var labels(default, null):ReadOnlyArray<String> = null;

    /**
     * Used in pair with `labels` to manage timeline labels
     */
    var labelIndexes:Array<Int> = null;

    /**
     * Optional starting position for timeline playback.
     *
     * - If >= 0, timeline starts from this frame index
     * - When looping, timeline resets to this position instead of 0
     * - Default is -1 (use position 0)
     */
    public var startPosition(default, set):Int = -1;
    function set_startPosition(startPosition:Int):Int {
        if (this.startPosition != startPosition) {
            this.startPosition = startPosition;
            apply();
        }
        return startPosition;
    }

    /**
     * Optional ending position for timeline playback.
     *
     * - If >= 0, timeline stops at this frame index
     * - When looping, timeline resets to startPosition (or 0)
     * - Default is -1 (use timeline size)
     */
    public var endPosition(default, set):Int = -1;
    function set_endPosition(endPosition:Int):Int {
        if (this.endPosition != endPosition) {
            this.endPosition = endPosition;
            apply();
        }
        return endPosition;
    }

    /**
     * Internal array of complete handlers
     */
    var completeHandlers:Array<Void->Void> = null;


    /**
     * Internal array of complete handler label indexes
     */
    var completeHandlerIndexes:Array<Int> = null;

    /**
     * Create a new timeline instance.
     * The timeline starts paused at position 0 with no tracks.
     */
    public function new() {

        super();

        bindOrUnbindUpdateIfNeeded();

    }

    function bindAsComponent() {

        // Nothing to do

    }

    /**
     * Internal function to bind or update to app
     * update event depending on current settings
     */
    inline function bindOrUnbindUpdateIfNeeded():Void {

        app.offPreUpdate(update);

        if (!paused && autoUpdate) {
            app.onPreUpdate(this, update);
        }

    }

    /**
     * Update the timeline position based on elapsed time.
     * Called automatically each frame when autoUpdate is true.
     *
     * @param delta Time elapsed since last frame in seconds
     */
    public function update(delta:Float):Void {

        inlineSeek(position + delta * fps);

    }

    /**
     * Jump to a specific position in the timeline.
     * Handles looping and clamping based on timeline settings.
     * Updates all tracks to reflect the new position.
     *
     * @param targetPosition The frame index to seek to
     */
    final public function seek(targetPosition:Float):Void {

        inlineSeek(targetPosition);

    }

    /**
     * Play an animation sequence from a labeled position.
     * The animation plays until reaching the next label or timeline end.
     *
     * If the animation is interrupted (by seeking or playing another animation),
     * the complete callback won't be called.
     *
     * @param name The label name to start from
     * @param complete Callback fired when the animation completes
     */
    public function animate(name:String, complete:Void->Void):Void {

        clearCompleteHandlers();

        var index = indexOfLabel(name);

        if (index != -1) {
            seek(index);

            if (completeHandlers == null) {
                completeHandlers = [];
                completeHandlerIndexes = [];
            }
            completeHandlers.push(complete);
            completeHandlerIndexes.push(index);
        }
        else {
            log.warning('Failed to animate whith label: $name (not found)');
        }

    }

    /**
     * Jump to the position of a named label.
     *
     * @param name The label name to seek to
     * @return The frame index of the label, or -1 if not found
     */
    public function seekLabel(name:String):Int {

        var index = indexOfLabel(name);

        if (index != -1) {
            seek(index);
        }
        else {
            log.warning('Failed to seek label: $name (not found)');
        }

        return index;

    }

    /**
     * Reset the timeline's start and end positions to their defaults.
     * After calling this, the timeline will play from 0 to its full size.
     */
    public function resetStartAndEndPositions():Void {

        startPosition = -1;
        endPosition = -1;

    }

    /**
     * Set up the timeline to loop within a labeled section.
     *
     * The timeline will:
     * - Jump to the label position
     * - Set startPosition to the label's frame
     * - Set endPosition to the next label (or timeline end)
     * - Loop within this range
     *
     * @param name The label name marking the start of the loop section
     * @return The frame index of the label, or -1 if not found
     */
    public function loopLabel(name:String):Int {

        if (labels == null) {
            log.warning('Cannot loop label $name (there is no label at all)');
            return -1;
        }
        var i = labels.indexOf(name);

        if (i == -1) {
            log.warning('Cannot loop label $name (no such label)');
            return -1;
        }

        var index = labelIndexes[i];

        startPosition = index;
        endPosition = i < labelIndexes.length - 1 ? labelIndexes[i + 1] : size;
        seek(index);

        return index;

    }

    /**
     * Apply all timeline tracks at the current position.
     * Useful for ensuring all animated properties are up to date.
     *
     * @param forceChange If true, forces track updates even if values haven't changed
     */
    final public function apply(forceChange:Bool = false):Void {

        inlineSeek(position, true, forceChange);

    }

    inline function inlineSeek(targetPosition:Float, forceSeek:Bool = false, forceChange:Bool = false):Void {

        // Continue only if target position is different than current position
        var prevPosition = position;
        if (forceSeek || targetPosition != position) {

            // Check that targetPosition is within startPosition and endPosition (if applicable)
            if (startPosition >= 0 && targetPosition < startPosition)
                targetPosition = startPosition;
            if (endPosition >= startPosition && startPosition >= 0 && targetPosition > endPosition) {
                if (loop) {
                    targetPosition = startPosition + (targetPosition - startPosition) % (endPosition - startPosition);
                }
                else {
                    targetPosition = endPosition;
                }
            }

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

            // If position has changed, apply changes to tracks
            if (targetPosition != position) {
                position = targetPosition;

                // Update each track
                for (i in 0...tracks.length) {
                    var track = tracks.unsafeGet(i);
                    if (!track.locked) {
                        track.inlineSeek(position, forceSeek, forceChange);
                    }
                }
            }
        }

        // Check if we reached a label start/end at new position
        if (position != prevPosition) {
            var newIndex = Math.floor(position);
            var prevIndex = Math.floor(prevPosition);
            if (newIndex != prevIndex) {
                var label = labelAtIndex(newIndex);
                if (label != null) {
                    var prevLabelIndex = indexOfLabelBeforeIndex(newIndex);
                    if (prevLabelIndex != -1) {
                        emitEndLabel(prevLabelIndex, labelAtIndex(prevLabelIndex));
                    }
                    emitStartLabel(newIndex, label);
                }
            }
        }

    }

    inline function clearCompleteHandlers():Void {

        if (completeHandlers != null && completeHandlers.length > 0) {
            // Reset handlers arrays
            completeHandlers.setArrayLength(0);
            completeHandlerIndexes.setArrayLength(0);
        }

    }

    function didEmitEndLabel(index:Int, name:String):Void {

        if (completeHandlers != null && completeHandlers.length > 0) {

            var pool:ArrayPool = null;
            var toCall:ReusableArray<Any> = null;
            var toCallLen = 0;

            for (i in 0...completeHandlerIndexes.length) {
                var anIndex = completeHandlerIndexes.unsafeGet(i);
                if (anIndex == index) {

                    // Request a reusable array to keep handlers
                    // that we will call without allocating another array
                    if (toCall == null) {
                        pool = ArrayPool.pool(completeHandlers.length);
                        toCall = pool.get();
                    }

                    var handler = completeHandlers.unsafeGet(i);
                    toCall.set(toCallLen, handler);
                    completeHandlers.unsafeSet(i, null);
                    toCallLen++;
                }
            }

            clearCompleteHandlers();

            // Call!
            for (i in 0...toCallLen) {
                var handler:Dynamic = toCall.get(i);
                handler();
            }

            // Release reusable array, if any used
            if (toCall != null) {
                pool.release(toCall);
            }

        }

    }

    /**
     * Add an animation track to this timeline.
     * If the track was previously added to another timeline, it's removed first.
     * If autoFitSize is true, the timeline size adjusts to accommodate the track.
     *
     * @param track The animation track to add
     */
    public function add(track:TimelineTrack<TimelineKeyframe>):Void {

        if (track.timeline != null) {
            track.timeline.remove(track);
        }
        if (track.timeline != this) {
            tracks.original.push(track);
            track.timeline = this;
        }

        if (autoFitSize) {
            fitSize();
        }

    }

    /**
     * Get a track by its ID.
     *
     * @param trackId The track identifier
     * @return The track with the given ID, or null if not found
     */
    public function get(trackId:String):TimelineTrack<TimelineKeyframe> {

        for (i in 0...tracks.length) {
            var track = tracks[i];
            if (track.id == trackId) {
                return track;
            }
        }

        return null;

    }

    /**
     * Remove an animation track from this timeline.
     * If autoFitSize is true, the timeline size adjusts after removal.
     *
     * @param track The animation track to remove
     */
    public function remove(track:TimelineTrack<TimelineKeyframe>):Void {

        if (track.timeline == this) {
            tracks.original.remove(track);
            track.timeline = null;
        }

        if (autoFitSize) {
            fitSize();
        }

    }

    /**
     * Adjust the timeline size to match the longest track.
     * Called automatically when autoFitSize is true and tracks are added/removed.
     */
    public function fitSize():Void {

        var newSize = 0;

        for (i in 0...tracks.length) {
            var track = tracks.unsafeGet(i);
            if (track.size > newSize) {
                newSize = track.size;
            }
        }

        size = newSize;

    }

    /**
     * Find the last label before a given position.
     *
     * @param index The frame index to search before
     * @return The frame index of the previous label, or -1 if none exists
     */
    public function indexOfLabelBeforeIndex(index:Int):Int {

        if (labelIndexes == null)
            return -1;

        var prevIndex = -1;

        for (i in 0...labelIndexes.length) {
            var anIndex = labelIndexes.unsafeGet(i);

            // There is a label at the given index, return it
            if (anIndex == index)
                return prevIndex;

            // Already reached an index higher than the searched one, stop.
            if (anIndex > index)
                break;

            prevIndex = anIndex;
        }

        return prevIndex;

    }

    /**
     * Get the label name at a specific frame index.
     *
     * @param index The frame index to check
     * @return The label name at that position, or null if no label exists
     */
    public function labelAtIndex(index:Int):String {

        if (labelIndexes == null)
            return null;

        for (i in 0...labelIndexes.length) {
            var anIndex = labelIndexes.unsafeGet(i);

            // There is a label at the given index, return it
            if (anIndex == index)
                return labels.unsafeGet(i);

            // Already reached an index higher than the searched one, stop.
            if (anIndex > index)
                break;
        }

        return null;

    }

    /**
     * Get the frame index of a named label.
     *
     * @param name The label name to find
     * @return The frame index of the label, or -1 if not found
     */
    public function indexOfLabel(name:String):Int {

        if (labelIndexes == null)
            return -1;

        for (i in 0...labels.length) {
            var aName = labels.unsafeGet(i);
            if (name == aName)
                return labelIndexes.unsafeGet(i);
        }

        return -1;

    }

    /**
     * Create or update a label at a specific position.
     * If a label with the same name exists, it's moved to the new position.
     * Labels are automatically sorted by position.
     *
     * @param index The frame index for the label
     * @param name The label name
     */
    public function setLabel(index:Int, name:String):Void {

        removeLabel(name);

        if (labelIndexes == null) {
            labelIndexes = [];
            labels = [];
        }

        labelIndexes.push(index);
        labels.original.push(name);

        sortLabels();

    }

    /**
     * Remove any label at the specified frame index.
     *
     * @param index The frame index where the label should be removed
     * @return True if a label was removed, false if no label existed
     */
    public function removeLabelAtIndex(index:Int):Bool {

        var didRemove = false;

        if (labelIndexes != null) {
            var i = labelIndexes.indexOf(index);
            if (i != -1) {
                labels.original.splice(i, 1);
                labelIndexes.splice(i, 1);
                didRemove = true;
            }
        }

        return didRemove;

    }

    /**
     * Remove a label by name.
     *
     * @param name The label name to remove
     * @return True if the label was removed, false if it didn't exist
     */
    public function removeLabel(name:String):Bool {

        var didRemove = false;

        if (labels != null) {
            var i = labels.indexOf(name);
            if (i != -1) {
                labels.original.splice(i, 1);
                labelIndexes.splice(i, 1);
                didRemove = true;
            }
        }

        return didRemove;

    }

    function sortLabels():Void {

        // Maybe this could be better,
        // but it is only needed when changing labels so that should be fine.
        labelIndexes.sort(compareLabelIndexes);
        labels.original.sort(compareLabelNames);

    }

    function compareLabelIndexes(a:Int, b:Int):Int {

        if (a > b)
            return 1;
        else if (a < b)
            return -1;
        else
            return 0;

    }

    function compareLabelNames(nameA:String, nameB:String):Int {

        var iA = labels.indexOf(nameA);
        var a = labelIndexes.unsafeGet(iA);

        var iB = labels.indexOf(nameB);
        var b = labelIndexes.unsafeGet(iB);

        if (a > b)
            return 1;
        else if (a < b)
            return -1;
        else
            return 0;

    }

}
