package ceramic;

/**
 * Internal handler for delayed update callbacks in the App class.
 * 
 * AppXUpdatesHandler is used by App.onceXUpdates() to schedule callbacks
 * that execute after a specific number of update frames. This class is
 * pooled for efficiency and managed internally by the App class.
 * 
 * @see App.onceXUpdates
 */
@:allow(ceramic.App)
class AppXUpdatesHandler {

    /**
     * The entity that owns this callback.
     * If the owner is destroyed, the callback won't execute.
     */
    public var owner:Entity = null;

    /**
     * Number of update frames remaining before executing the callback.
     * Decremented each frame until it reaches 0.
     */
    public var numUpdates:Int = -1;

    /**
     * The callback function to execute when numUpdates reaches 0.
     */
    public var callback:Void->Void = null;

    private function new() {}

    /**
     * Resets this handler to its initial state for reuse.
     * Called when the handler is returned to the pool.
     */
    function reset() {

        owner = null;
        numUpdates = -1;
        callback = null;

    }

}