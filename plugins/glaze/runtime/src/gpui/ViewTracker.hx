// New code for the Haxe port of GPUI (no GPUI origin): automatic reactivity
// of views based on tracker. See CERAMIC_GPUI_PLAN_1.md and NOTICE.md.
package gpui;

import tracker.Autorun;

/**
 * Records the observable fields a view reads while it renders, and reacts when
 * one of them changes.
 *
 * - **Capture**: `beginCapture()` drops the previous dependencies and makes this
 *   tracker `Autorun.current`, so every `@observe` getter read until
 *   `endCapture()` binds to it (including reads in nested calls).
 * - **Reaction**: when a bound field changes, tracker invalidates this autorun
 *   and schedules `run()` with `app.onceImmediate` (flushed within the frame).
 *   `run()` only calls `onInvalidated` (mark the view dirty, the same path as
 *   `cx.notify()`), exactly once per capture, and never re-renders by itself.
 *
 * Code run by executors, timers, event dispatch and observers runs with
 * capture disabled, so it never subscribes the view by accident.
 *
 * A tracker created with an `owner` is destroyed with it. Destroying the tracker
 * stops notifications.
 */
class ViewTracker extends Autorun {

    /**
     * Whether writes to a field read during the same capture (writes during
     * render) are detected. Enabled by default in debug builds.
     */
    public static var checkWritesDuringCapture:Bool = #if debug true #else false #end;

    /**
     * Called when a write during render is detected. Logs a warning by default.
     */
    public static var onWriteDuringCapture:ViewTracker->Void = defaultOnWriteDuringCapture;

    /**
     * Called (with tracker capture disabled) when an observed value read during
     * the last capture has changed.
     */
    public var onInvalidated:Null<Void->Void>;

    /**
     * Name used in warnings, the class name of the owner by default.
     */
    public var name:String;

    /**
     * `true` between `beginCapture()` and `endCapture()`.
     */
    public var capturing(default, null):Bool = false;

    var reacted:Bool = false;

    var writeReported:Bool = false;

    var savedCurrent:Null<Autorun> = null;

    public function new(onInvalidated:Void->Void, ?owner:ceramic.Entity, ?name:String) {
        super(null);
        this.onInvalidated = onInvalidated;
        this.name = name != null ? name : (owner != null ? Type.getClassName(Type.getClass(owner)) : 'ViewTracker');
        if (owner != null) {
            owner.onDestroy(this, _ -> destroy());
        }
    }

    /**
     * Starts recording reads: unbinds every previous dependency and makes this
     * tracker the current autorun.
     */
    public function beginCapture():Void {
        if (capturing) {
            throw 'ViewTracker $name is already capturing';
        }
        unbindFromAllAutorunArrays();
        @:privateAccess invalidated = false;
        reacted = false;
        writeReported = false;
        capturing = true;
        savedCurrent = Autorun.current;
        Autorun.current = this;
    }

    /**
     * Records reads again, keeping the dependencies of the current capture
     * (used for the prepaint and paint phases of a view, after its render).
     */
    public function resumeCapture():Void {
        if (capturing) {
            throw 'ViewTracker $name is already capturing';
        }
        capturing = true;
        savedCurrent = Autorun.current;
        Autorun.current = this;
    }

    /**
     * Stops recording reads and restores the previous current autorun.
     */
    public function endCapture():Void {
        if (!capturing)
            return;
        Autorun.current = savedCurrent;
        savedCurrent = null;
        capturing = false;
        if (checkWritesDuringCapture && invalidated && !destroyed && !writeReported) {
            // Only synchronous code ran during the capture: the invalidation
            // comes from a write to a field read earlier in this same capture.
            writeReported = true;
            onWriteDuringCapture(this);
        }
    }

    /**
     * Runs `render` between `beginCapture()` and `endCapture()`, even if it throws.
     */
    public function capture<R>(render:Void->R):R {
        beginCapture();
        var result:R;
        try {
            result = render();
        }
        catch (e:haxe.Exception) {
            endCapture();
            throw e;
        }
        endCapture();
        return result;
    }

    /**
     * The reaction, scheduled by tracker after an invalidation.
     */
    override public function run():Void {
        if (destroyed || reacted || !invalidated)
            return;
        reacted = true;
        final onInvalidated = this.onInvalidated;
        if (onInvalidated != null) {
            Autorun.unobserve();
            try {
                onInvalidated();
            }
            catch (e:haxe.Exception) {
                Autorun.reobserve();
                throw e;
            }
            Autorun.reobserve();
        }
    }

    override function destroy() {
        if (capturing) {
            endCapture();
        }
        onInvalidated = null;
        super.destroy();
    }

    static function defaultOnWriteDuringCapture(tracker:ViewTracker):Void {
        ceramic.Shortcuts.log.warning('View ${tracker.name} changed an observable value it read during the same render: it will render again on the next frame');
    }

}
