package ceramic;

// Original source: https://gist.github.com/underscorediscovery/e66e72ec702bdcedf5af45f8f4712109

#if cpp
    import cpp.vm.Thread;
    import cpp.vm.Deque;
#end

import ceramic.Shortcuts.*;
  
/** 
A simple Haxe class for easily running threads and calling functions on the primary thread.
from https://github.com/underscorediscovery/

Usage:
- call Runner.init() from your primary thread 
- call Runner.run() periodically to service callbacks (i.e inside your main loop)
- use Runner.thread(function() { ... }) to make a thread
- use Runner.runInMainThread(function() { ... }) to run code on the main thread
- use runInMainThreadBlocking to run code on the main thread and wait for the return value

*/
class Runner {

    #if cpp

    static var mainThread:Thread;

    static var queue:Deque<Void->Void>;

    #end

    /** Call this on your thread to make primary,
        the calling thread will be used for callbacks. */
    @:noCompletion public static function init() {
        #if cpp
        queue = new Deque<Void->Void>();
        mainThread = Thread.current();
        #end
    }

    /** Call this on the primary manually,
        Returns the number of callbacks called. */
    @:noCompletion public static function tick():Void {

        #if cpp
        var more = true;
        var count = 0;

        while (more) {
            var item = queue.pop(false);
            if (item != null) {
                count++; item(); item = null;
            } else {
                more = false; break;
            }
        }
        #end

    } //tick

    /** Call a function on the primary thread without waiting or blocking.
        If you want return values see runInMainBlocking */
    public static function runInMain(_fn:Void->Void) {

        #if cpp
        queue.push(_fn);
        #else
        app.onceImmediate(_fn);
        #end

    } //runInMain

    /** Call a function on the primary thread and wait for the return value.
        This will block the calling thread for a maximum of _timeout, default to 0.1s.
        To call without a return or blocking, use call_primary */
    public static function runInMainBlocking<T>(_fn:Void->T, _timeout:Float=0.1):Null<T> {

        #if cpp
        var res:T = null;
        var lock = new cpp.vm.Lock();

        //add to main to call this
        queue.push(function() {
            res = _fn();
            lock.release();
        });

        //wait for the lock release or timeout
        lock.wait(_timeout);

        //clean up
        lock = null;
        //return result
        return res;
        #else
        return _fn();
        #end

    } //runInMainBlocking

    /** Create a background thread using the given function, or just run (deferred) the function if threads are not supported */
    public static function runInBackground(fn:Void->Void):Void {

        #if cpp
        Thread.create(fn);
        #else
        app.onceImmediate(fn);
        #end

    } //runInBackground

} //Runner