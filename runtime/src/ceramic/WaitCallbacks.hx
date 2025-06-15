package ceramic;

/**
 * Utility to create and wait for multiple callback and call
 * a final one after every other callback has been called.
 */
class WaitCallbacks {

    private var completionCallback:()->Void;

    /**
     * Get the number of callbacks still pending
     */
    public var pending(default, null):Int;

    /**
     * Check if all callbacks have completed
     */
    public var complete(default, null):Bool;

    public function new(onComplete:()->Void) {
        this.completionCallback = onComplete;
        this.pending = 0;
        this.complete = false;
    }

    /**
     * Create a new callback to wait for.
     * Returns a function that should be called when this particular task is done.
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
