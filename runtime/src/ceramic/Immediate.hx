package ceramic;

import ceramic.ArrayPool;

using ceramic.Extensions;

/**
 * A utility class for scheduling callbacks to be executed in a batch.
 * 
 * Immediate provides a simple queuing mechanism where callbacks can be scheduled
 * with `push()` and then all executed at once with `flush()`. This pattern is
 * useful for deferring work until a specific point in the application lifecycle,
 * such as at the end of a frame or after a batch of operations.
 * 
 * Key features:
 * - Efficient callback storage with pre-allocated capacity
 * - Safe execution that allows new callbacks to be added during flush
 * - Memory pooling to avoid allocations during flush operations
 * - Null callback protection
 * 
 * Common use cases:
 * - Deferring expensive operations until after critical path execution
 * - Batching multiple updates to avoid redundant calculations
 * - Implementing a simple event loop or task queue
 * - Ensuring callbacks run after the current call stack completes
 * 
 * Example usage:
 * ```haxe
 * var immediate = new Immediate();
 * 
 * // Schedule some callbacks
 * immediate.push(() -> trace("First callback"));
 * immediate.push(() -> trace("Second callback"));
 * 
 * // Later, execute all callbacks
 * if (immediate.flush()) {
 *     trace("Callbacks were executed");
 * }
 * 
 * // Callbacks can add more callbacks during execution
 * immediate.push(() -> {
 *     trace("This callback adds another");
 *     immediate.push(() -> trace("Added during flush"));
 * });
 * immediate.flush(); // Both callbacks will execute
 * ```
 * 
 * @see ceramic.App For the main application immediate queue
 * @see ceramic.Timer For time-based callback scheduling
 */
class Immediate {

    /**
     * Array storing the queued callbacks. Pre-allocated for efficiency.
     */
    var immediateCallbacks:Array<Void->Void> = [];

    /**
     * The current allocated capacity of the callbacks array.
     * Used to track when the array needs to grow.
     */
    var immediateCallbacksCapacity:Int = 0;

    /**
     * The number of callbacks currently queued.
     * This may be less than the array capacity.
     */
    var immediateCallbacksLen:Int = 0;

    /**
     * Creates a new Immediate instance with an empty callback queue.
     */
    public function new() {}

    /**
     * Schedules a callback to be executed when `flush()` is called.
     * 
     * The callback will be added to the queue and executed in the order it was added
     * (FIFO - First In, First Out). Multiple callbacks can be queued before flushing.
     * 
     * The implementation uses a pre-allocated array that grows as needed, avoiding
     * unnecessary allocations for typical usage patterns.
     * 
     * @param handleImmediate The callback function to schedule. Must not be null.
     * @throws String If the callback is null
     */
    public function push(handleImmediate:Void->Void):Void {

        if (handleImmediate == null) {
            throw 'Immediate callback should not be null!';
        }

        if (immediateCallbacksLen < immediateCallbacksCapacity) {
            immediateCallbacks.unsafeSet(immediateCallbacksLen, handleImmediate);
            immediateCallbacksLen++;
        }
        else {
            immediateCallbacks[immediateCallbacksLen++] = handleImmediate;
            immediateCallbacksCapacity++;
        }

    }

    /**
     * Executes all queued callbacks and clears the queue.
     * 
     * This method will execute callbacks in the order they were added. If any callback
     * adds new callbacks to the queue (by calling `push()`), those new callbacks will
     * also be executed in the same flush operation. This continues until no more
     * callbacks remain in the queue.
     * 
     * The implementation uses a temporary array from the pool to safely iterate through
     * callbacks while allowing the queue to be modified during execution.
     * 
     * @return `true` if any callbacks were executed, `false` if the queue was empty
     */
    public function flush():Bool {

        var didFlush = false;

        // Process callbacks in batches until the queue is empty
        while (immediateCallbacksLen > 0) {

            didFlush = true;

            // Get a temporary array from the pool to hold current callbacks
            var pool = ArrayPool.pool(immediateCallbacksLen);
            var callbacks = pool.get();
            var len = immediateCallbacksLen;
            immediateCallbacksLen = 0;

            // Copy callbacks to temporary array and clear originals
            for (i in 0...len) {
                callbacks.set(i, immediateCallbacks.unsafeGet(i));
                immediateCallbacks.unsafeSet(i, null);
            }

            // Execute all callbacks (they may add new callbacks to the queue)
            for (i in 0...len) {
                var cb:Dynamic = callbacks.get(i);
                cb();
            }

            // Return temporary array to pool
            pool.release(callbacks);

        }

        return didFlush;

    }

}
