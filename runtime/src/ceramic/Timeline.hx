package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

class Timeline extends Entity implements Component {

    /** Timeline size. Default `0`, meaning this timeline won't do anything.
        By default, because `autoFitSize` is `true`, adding or updating tracks on this
        timeline will update timeline `size` accordingly so it may not be needed to update `size` explicitly.
        Setting `size` to `-1` means the timeline will never finish. */
    public var size:Float = 0;

    /** If set to `true` (default), adding or updating tracks on this timeline will update
        timeline size accordingly to match longest track size. */
    public var autoFitSize:Bool = true;

    /** Whether this timeline should loop. Ignored if timeline's `size` is `-1` (not defined). */
    public var loop:Bool = true;

    /** Whether this timeline should bind itself to update cycle automatically or not (default `true`). */
    public var autoUpdate(default, set):Bool = true;
    function set_autoUpdate(autoUpdate:Bool):Bool {
        if (this.autoUpdate != autoUpdate) {
            this.autoUpdate = autoUpdate;
            bindOrUnbindUpdateIfNeeded();
        }
        return autoUpdate;
    }

    /**
     * Frames per second on this timeline.
     * Note: a lower fps doesn't mean animations won't be interpolated between frames.
     * Thus using 30 fps is still fine even if screen refreshes at 60 fps.
     **/
    public var fps:Int = 30;

    /** Position on this timeline.
        Gets back to zero when `loop=true` and position reaches a defined `size`. */
    public var position(default, null):Float = 0;

    /** The tracks updated by this timeline */
    public var tracks(default, null):ReadOnlyArray<TimelineTrack<TimelineKeyframe>> = [];

    /** Whether this timeline is paused or not. */
    public var paused(default, set):Bool = false;
    function set_paused(paused:Bool):Bool {
        if (this.paused == paused) return paused;
        this.paused = paused;
        bindOrUnbindUpdateIfNeeded();
        return paused;
    }

    /**
     * Used in pair with `labelIndexes` to manage timeline labels
     */
    var labelNames:Array<String> = null;

    /**
     * Used in pair with `labelNames` to manage timeline labels
     */
    var labelIndexes:Array<Int> = null;

    /**
     * If >= 0, timeline will start from this index.
     * When timeline is looping, it will reset to this index as well at each iteration.
     */
    var startPosition:Int = -1;

    /**
     * If provided, timeline will stop at this index.
     * When timeline is looping, it will reset to startIndex (if >= 0).
     */
    var endPosition:Int = -1;

    public function new() {

        super();

        bindOrUnbindUpdateIfNeeded();

    }

    function bindAsComponent() {

        // Nothing to do

    }

    /** Internal function to bind or update to app
        update event depending on current settings */
    inline function bindOrUnbindUpdateIfNeeded():Void {

        app.offPreUpdate(update);

        if (!paused && autoUpdate) {
            app.onPreUpdate(this, update);
        }

    }

    public function update(delta:Float):Void {

        inlineSeek(position + delta * fps);

    }

    /** Seek the given position (in frames) in the timeline.
        Will take care of clamping `position` or looping it depending on `size` and `loop` properties. */
    final public function seek(targetPosition:Float):Void {

        inlineSeek(targetPosition);

    }

    /** Apply (or re-apply) every track of this timeline at the current position */
    final public function apply(forceChange:Bool = false):Void {

        inlineSeek(position, true, forceChange);

    }

    inline function inlineSeek(targetPosition:Float, forceSeek:Bool = false, forceChange:Bool = false):Void {

        // Continue only if target position is different than current position
        if (forceSeek || targetPosition != position) {

            // Check that targetPosition is within startPosition and endPosition (if applicable)
            if (startPosition >= 0 && targetPosition < startPosition)
                targetPosition = startPosition;
            if (endPosition >= startPosition && startPosition >= 0 && targetPosition >= endPosition) {
                if (loop) {
                    targetPosition = startPosition + (targetPosition - startPosition) % (endPosition - startPosition);
                }
                else {
                    targetPosition = endPosition;
                }
            }

            if (size > 0) {
                if (targetPosition >= size) {
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

    }

    /** Add a track to this timeline */
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

    public function get(trackId:String):TimelineTrack<TimelineKeyframe> {

        for (i in 0...tracks.length) {
            var track = tracks[i];
            if (track.id == trackId) {
                return track;
            }
        }

        return null;

    }

    /** Remove a track from this timeline */
    public function remove(track:TimelineTrack<TimelineKeyframe>):Void {

        if (track.timeline == this) {
            tracks.original.remove(track);
            track.timeline = null;
        }

        if (autoFitSize) {
            fitSize();
        }

    }

    /** Update `size` property to make it fit
        the size of the longuest track. */
    public function fitSize():Void {

        var newSize = 0.0;

        for (i in 0...tracks.length) {
            var track = tracks.unsafeGet(i);
            if (track.size > newSize) {
                newSize = track.size;
            }
        }

        size = newSize;

    }

    public function seekLabel(name:String):Void {

        var index = indexOfLabel(name);
        if (index != -1) {
            seek(index);
        }
        else {
            log.warning('Failed to seek to label: $name (not found)');
            seek(0);
        }

    }

    public function labelAtIndex(index:Int):String {

        if (labelIndexes == null)
            return null;

        for (i in 0...labelIndexes.length) {
            var anIndex = labelIndexes.unsafeGet(i);

            // There is a label at the given index, return it
            if (anIndex == index)
                return labelNames.unsafeGet(i);

            // Already reached an index higher than the searched one, stop.
            if (anIndex > index)
                break;
        }

        return null;

    }

    public function indexOfLabel(name:String):Int {

        if (labelIndexes == null)
            return -1;

        for (i in 0...labelNames.length) {
            var aName = labelNames.unsafeGet(i);
            if (name == aName)
                return labelIndexes.unsafeGet(i);
        }

        return -1;
        
    }

    public function setLabel(index:Int, name:String):Void {

        removeLabel(name);

        if (labelIndexes == null) {
            labelIndexes = [];
            labelNames = [];
        }
        
        labelIndexes.push(index);
        labelNames.push(name);

        sortLabels();

    }

    public function removeLabelAtIndex(index:Int):Bool {

        var didRemove = false;

        if (labelIndexes != null) {
            var i = labelIndexes.indexOf(index);
            if (i != -1) {
                labelNames.splice(i, 1);
                labelIndexes.splice(i, 1);
                didRemove = true;
            }
        }

        return didRemove;

    }

    public function removeLabel(name:String):Bool {

        var didRemove = false;

        if (labelNames != null) {
            var i = labelNames.indexOf(name);
            if (i != -1) {
                labelNames.splice(i, 1);
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
        labelNames.sort(compareLabelNames);

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

        var iA = labelNames.indexOf(nameA);
        var a = labelIndexes.unsafeGet(iA);

        var iB = labelNames.indexOf(nameB);
        var b = labelIndexes.unsafeGet(iB);

        if (a > b)
            return 1;
        else if (a < b)
            return -1;
        else
            return 0;

    }

}
