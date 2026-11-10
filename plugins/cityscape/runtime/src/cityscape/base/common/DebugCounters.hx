// New code for Cityscape (not a port): counts of live objects, for the
// leak tests.
package cityscape.base.common;

/**
 * Counts of live objects of every Cityscape context, kept only when the
 * define `cityscape_debug_counters` is set (the unit tests set it; zero
 * cost otherwise): the leak tests compare them before and after editors
 * are created and destroyed (Monaco's tests use a `DisposableTracker` for
 * the same purpose). Global by design: not editor state.
 */
class DebugCounters {

    /** Listeners subscribed to an `Emitter` or `VoidEmitter`, not removed yet. */
    public static var listeners:Int = 0;

    /** `Disposable` objects created and not disposed. */
    public static var disposables:Int = 0;

    /**
     * Timeouts of `Async.setTimeout` scheduled, not run nor cancelled yet,
     * and cursor blink intervals running.
     */
    public static var timers:Int = 0;

    /** `CityscapeView`s created and not disposed (`disposeView`). */
    public static var views:Int = 0;

    /**
     * Glaze entities created by Cityscape (editor views, widget views and
     * their kit inputs) and not released yet.
     */
    public static var entities:Int = 0;

    /**
     * Counts `entity` in `entities` until the app releases it (returns it).
     */
    public static inline function trackEntity<T:glaze.Model>(entity:glaze.Entity<T>, app:glaze.App):glaze.Entity<T> {
        #if cityscape_debug_counters
        entities++;
        app.observeRelease(entity, (_, _) -> entities--);
        #end
        return entity;
    }

    /** Whether the counters are kept (the define is set). */
    public static inline function enabled():Bool {
        #if cityscape_debug_counters
        return true;
        #else
        return false;
        #end
    }

}
