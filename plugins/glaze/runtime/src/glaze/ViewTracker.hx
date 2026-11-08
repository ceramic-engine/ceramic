// New code for the Haxe port of GPUI (no GPUI origin): automatic reactivity
// of views based on tracker. See NOTICE.md.
package glaze;

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
 * - **Window**: the tracker of a view drawn by a window is also told to that
 *   window as soon as it is invalidated (`Window.viewTrackerInvalidated`), so
 *   that a change made while the window draws has the effect of a notify sent
 *   during a draw, and a change made before a draw is seen by that draw.
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
    public static var onWriteDuringCapture:(ViewTracker) -> Void = defaultOnWriteDuringCapture;

    /**
     * Called (with tracker capture disabled) when an observed value read during
     * the last capture has changed.
     */
    public var onInvalidated:Null<() -> Void>;

    /**
     * Name used in warnings, the class name of the owner by default.
     */
    public var name:String;

    /**
     * `true` between `beginCapture()` and `endCapture()`.
     */
    public var capturing(default, null):Bool = false;

    /**
     * `true` during the render capture (`beginCapture()` to `endCapture()`),
     * not during the prepaint and paint captures (`resumeCapture()`).
     */
    public var rendering(default, null):Bool = false;

    /**
     * The entities read, updated or created while the view rendered,
     * prepainted and painted since its last render (Rust: the accessed
     * entities of a view, kept while a cached view is reused). Cleared by
     * `beginCapture()`. See `Window.recordEntitiesAccessed`.
     */
    public final accessed:AccessedEntities = new AccessedEntities();

    var reacted:Bool = false;

    /**
     * The window drawing the view and the view's entity id (set by the
     * window): the window is told synchronously when this tracker is
     * invalidated.
     */
    @:allow(glaze)
    var window:Null<Window> = null;

    @:allow(glaze)
    var viewId:Int = -1;

    var writeReported:Bool = false;

    var savedCurrent:Null<Autorun> = null;

    public function new(onInvalidated:() -> Void, ?owner:ceramic.Entity, ?name:String) {
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
        // Not invalidated anymore before unbinding: unbinding an invalidated
        // tracker is how an invalidation is detected (see below)
        @:privateAccess invalidated = false;
        unbindFromAllAutorunArrays();
        accessed.clear();
        reacted = false;
        writeReported = false;
        capturing = true;
        rendering = true;
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
        rendering = false;
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
    public function capture<R>(render:() -> R):R {
        beginCapture();
        var result:R;
        try {
            result = render();
        }
        catch (e:haxe.Exception) {
            endCapture();
            throw glaze.util.Exceptions.rethrow(e);
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
                throw glaze.util.Exceptions.rethrow(e);
            }
            Autorun.reobserve();
        }
    }

    /**
     * Tracker's `invalidate()` marks the autorun invalidated, then unbinds it:
     * this is where the window learns synchronously that the view changed,
     * while the reaction itself waits for `run()`.
     */
    override public function unbindFromAllAutorunArrays():Void {
        super.unbindFromAllAutorunArrays();
        final window = this.window;
        if (window != null && invalidated && !reacted && !destroyed) {
            window.viewTrackerInvalidated(this);
        }
    }

    override function destroy() {
        if (capturing) {
            endCapture();
        }
        onInvalidated = null;
        window = null;
        super.destroy();
    }

    static function defaultOnWriteDuringCapture(tracker:ViewTracker):Void {
        ceramic.Shortcuts.log.warning('View ${tracker.name} changed an observable value it read during the same render: it will render again on the next frame');
    }

}
