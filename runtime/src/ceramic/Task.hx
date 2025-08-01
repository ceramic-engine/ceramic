package ceramic;

/**
 * Base class for asynchronous tasks that can either succeed or fail.
 * Tasks are single-use operations that call done() or fail() when completed.
 *
 * Custom tasks should extend this class and override the run() method:
 * ```haxe
 * class MyAsyncTask extends Task {
 *     override function run():Void {
 *         someAsyncOperation((success, result) -> {
 *             if (success) {
 *                 this.result = result;
 *                 done();
 *             } else {
 *                 fail("Operation failed");
 *             }
 *         });
 *     }
 * }
 * ```
 *
 * They are typically not called directly and triggered using `ceramic task` command instead.
 */
class Task extends Entity {

    /// Events

    /**
     * Emitted when the task completes successfully.
     * After this event is emitted, the task should not be reused.
     */
    @event function done();

    /**
     * Emitted when the task fails to complete.
     * @param reason A human-readable description of why the task failed
     */
    @event function fail(reason:String);

    /// Helpers

    /**
     * Mark the task as successfully completed.
     * This will emit the done event. Should only be called once per task.
     *
     * Typically called from within the run() implementation when the
     * asynchronous operation completes successfully.
     */
    public function done():Void {

        emitDone();

    }

    /**
     * Mark the task as failed.
     * This will emit the fail event with the given reason. Should only be called once per task.
     *
     * @param reason A human-readable description of why the task failed.
     *               This should help developers understand what went wrong.
     */
    public function fail(reason:String):Void {

        emitFail(reason);

    }

    /// Lifecycle

    /**
     * Execute the task.
     * This method must be overridden in subclasses to implement the actual task logic.
     *
     * The implementation should:
     * - Start the asynchronous operation
     * - Call done() when the operation succeeds
     * - Call fail(reason) when the operation fails
     *
     * The default implementation fails with an error message.
     */
    public function run():Void {

        fail('Script.run() method must be overrided in subclasses.');

    }

}
