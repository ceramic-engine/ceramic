package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

class Timeline extends Entity implements Component {

    /** Timeline duration. Default `0`, meaning this timeline won't do anything.
        By default, because `autoFitDuration` is `true`, adding or updating tracks on this
        timeline will update timeline `duration` accordingly so it may not be needed to update `duration` explicitly.
        Setting `duration` to `-1` means the timeline will never finish. */
    public var duration:Float = 0;

    /** If set to `true` (default), adding or updating tracks on this timeline will update
        timeline duration accordingly to match longest track duration. */
    public var autoFitDuration:Bool = true;

    /** Whether this timeline should loop. Ignored if timeline's `duration` is `-1` (not defined). */
    public var loop:Bool = true;

    /** Elapsed time on this timeline.
        Gets back to zero when `loop=true` and time reaches a defined `duration`. */
    public var time(default, null):Float = 0;

    /** The tracks updated by this timeline */
    public var tracks(default, null):ImmutableArray<TimelineTrack<Dynamic>> = [];

    /** Whether this timeline is paused or not. s*/
    public var paused(default, set):Bool = false;
    function set_paused(paused:Bool):Bool {
        if (this.paused == paused) return paused;
        this.paused = paused;
        bindOrUnbindUpdateIfNeeded();
        return paused;
    }

    public function new() {

        super();

        bindOrUnbindUpdateIfNeeded();

    } //new

    function bindAsComponent() {

        // Nothing to do

    } //bindAsComponent

    /** Internal function to bind or update to app
        update event depending on current settings */
    inline function bindOrUnbindUpdateIfNeeded():Void {

        app.offUpdate(update);

        if (!paused) {
            app.onUpdate(this, update);
        }

    } //bindOrUnbindUpdateIfNeeded

    function update(delta:Float):Void {

        inlineSeek(time + delta);

    } //update

    /** Seek the given time (in seconds) in the timeline.
        Will take care of clamping `time` or looping it depending on `duration` and `loop` properties. */
    final public function seek(targetTime:Float):Void {

        inlineSeek(targetTime);

    } //seek

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

            // If time has changed, apply changes to tracks
            if (targetTime != time) {
                time = targetTime;

                // Update each track
                for (i in 0...tracks.length) {
                    var track = tracks.unsafeGet(i);
                    if (!track.locked) {
                        track.inlineSeek(time);
                    }
                }
            }
        }

    } //inlineSeek

    /** Add a track to this timeline */
    public function add(track:TimelineTrack<Dynamic>):Void {

        if (track.timeline != null) {
            track.timeline.remove(track);
        }
        if (track.timeline != this) {
            tracks.mutable.push(track);
            track.timeline = this;
        }

        if (autoFitDuration) {
            fitDuration();
        }

    } //add

    /** Remove a track from this timeline */
    public function remove(track:TimelineTrack<Dynamic>):Void {

        if (track.timeline == this) {
            tracks.mutable.remove(track);
            track.timeline = null;
        }

        if (autoFitDuration) {
            fitDuration();
        }

    } //remove

    /** Update `duration` property to make it fit
        the duration of the longuest track. */
    public function fitDuration():Void {

        var newDuration = duration;

        for (i in 0...tracks.length) {
            var track = tracks.unsafeGet(i);
            if (track.duration > newDuration) {
                newDuration = track.duration;
            }
        }

        duration = newDuration;

    } //fitDuration

} //Timeline
