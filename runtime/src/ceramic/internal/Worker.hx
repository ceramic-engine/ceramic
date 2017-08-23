package ceramic.internal;

#if cpp
    import cpp.vm.Thread;
    import cpp.vm.Deque;
#elseif neko
    import neko.vm.Thread;
    import neko.vm.Deque;
#end
  
/** 
A simple Haxe class for easily running threads and calling functions on the primary thread.
Initially from https://github.com/underscorediscovery/, edited for `ceramic` framework.
Usage:
- call Worker.init() from your primary thread 
- call Worker.run() periodically to service callbacks (i.e inside your main loop)
- use Worker.thread(function() { ... }) to make a thread
- use Worker.execInPrimary(function() { ... }) to run code on the main thread
- use Worker.execInPrimarySync to run code on the main thread and wait for the return value
*/
class Worker {

/// Worker instance API

    public var thread:Thread;

    public function new() {

        thread = Thread.create(doWork);

    } //new

    private function doWork():Void {

        while (true) {

            // Wait for next callback to execute
            var info:Array<Dynamic> = Thread.readMessage(true);

            // Gather info
            var func:Void->Void = info[0];
            var done:Void->Void = info[1];

            // Exec function (work)
            func();

            // Notify complete, if needed
            if (done != null) {
                Worker.execInPrimary(done);
            }

        } //while

    } //doWork

    /** Let the worker execute the given function.
        If `done` callback is provided, it will be called on
        primary thread, right after the worker finished to execute
        the provided function.
        This should be called from main thread. */
    public function enqueue(func:Void->Void, ?done:Void->Void):Void {

        thread.sendMessage([func, done]);

    } //enqueue

/// Static API

    public static var primary:Thread;

    static var queue:Deque<Void->Void>;

    /** Call this on your thread to make primary,
        the calling thread will be used for callbacks. */
    public static function init() {
        queue = new Deque<Void->Void>();
        primary = Thread.current();
    }

    /** Call this on the primary manually,
        Returns the number of callbacks called. */
    public static function flush():Int {

        var more = true;
        var count = 0;

        while (more) {
            var item = queue.pop(false);
            if(item != null) {
                count++; item(); item = null;
            } else {
                more = false; break;
            }
        }

        return count;

    } //flush

    /** Call a function on the primary thread without waiting or blocking.
        If you want return values see execInPrimarySync() */
    public static function execInPrimary(fn:Void->Void) {

        queue.push(fn);

    } //execInPrimary

    /** Call a function on the primary thread and wait for the return value.
        This will block the calling thread for a maximum of timeout, default to 0.1s.
        To call without a return or blocking, use execInPrimary() */
    public static function execInPrimarySync<T>(fn:Void->T, timeout:Float=0.1):Null<T> {

        var res:T = null;
        var lock = new cpp.vm.Lock();

        // Add to main to call this
        queue.push(function() {
            res = fn();
            lock.release();
        });

        // Wait for the lock release or timeout
        lock.wait(timeout);

        // Clean up
        lock = null;
        // Return result
        return res;

    } //callPrimarySync

} //Worker
