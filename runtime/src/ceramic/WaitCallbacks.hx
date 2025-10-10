package ceramic;

/**
 * Utility to create and wait for multiple callbacks and call
 * a final one after every other callback has been called.
 *
 * This class is useful for coordinating multiple asynchronous operations,
 * ensuring that a completion handler is called only after all individual
 * operations have finished. Each callback can only be called once.
 *
 * Common use cases:
 * - Loading multiple assets in parallel
 * - Waiting for multiple animations to complete
 * - Coordinating multiple async operations before proceeding
 *
 * Example usage:
 * ```haxe
 * var wait = new WaitCallbacks(() -> {
 *     trace("All operations completed!");
 * });
 *
 * // Register callbacks for async operations
 * var cb1 = wait.callback();
 * var cb2 = wait.callback();
 * var cb3 = wait.callback();
 *
 * // Start async operations
 * loadAsset("image1.png", cb1);
 * loadAsset("image2.png", cb2);
 * loadAsset("sound.ogg", cb3);
 *
 * // The completion callback will fire after all three callbacks are invoked
 * ```
 *
 * Note: Once all callbacks have been called and the completion handler has fired,
 * no new callbacks can be registered.
 */
class WaitCallbacks {

    public var completionCallback:()->Void;

    /**
     * Get the number of callbacks still pending.
     * This decreases as callbacks are invoked.
     */
    public var pending(default, null):Int;

    /**
     * Check if all callbacks have completed.
     * Once true, no new callbacks can be registered.
     */
    public var complete(default, null):Bool;

    /**
     * Create a new WaitCallbacks instance.
     *
     * @param completionCallback The function to call when all registered callbacks have been invoked
     */
    public function new(?completionCallback:()->Void) {
        this.completionCallback = completionCallback;
        this.pending = 0;
        this.complete = false;
    }

    /**
     * Create a new callback to wait for.
     * Returns a function that should be called when this particular task is done.
     *
     * The returned callback:
     * - Can only be called once (subsequent calls are ignored)
     * - Decrements the pending counter when called
     * - Triggers the completion callback when it's the last pending callback
     *
     * @return A callback function to be called when the associated task completes
     * @throws String if called after all callbacks have completed
     */
    public function callback():()->Void {
        if (complete) {
            throw "Cannot register new callbacks after completion";
        }

        pending++;
        var calledOnce = false;

        return function() {
            if (calledOnce) {
                return; // Prevent double-calling
            }
            calledOnce = true;

            pending--;

            if (pending == 0 && !complete) {
                complete = true;
                completionCallback();
            }
        };
    }

}
