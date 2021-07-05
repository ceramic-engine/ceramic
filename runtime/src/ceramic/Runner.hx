package ceramic;

// Original source: https://gist.github.com/underscorediscovery/e66e72ec702bdcedf5af45f8f4712109

#if (cpp || cs)
#if (haxe_ver < 4)
    import cpp.vm.Thread;
    import cpp.vm.Deque;
#else
    import sys.thread.Thread;
    import sys.thread.Deque;
#end
#end

import ceramic.Shortcuts.*;

/** 
A simple Haxe class for easily running threads and calling functions on the primary thread.
from https://github.com/underscorediscovery/

Usage:
- call Runner.init() from your primary thread 
- call Runner.tick() periodically to service callbacks (i.e inside your main loop)
- use Runner.thread(function() { ... }) to make a thread
- use Runner.runInMainThread(function() { ... }) to run code on the main thread
- use runInMainThreadBlocking to run code on the main thread and wait for the return value

*/
class Runner {

    #if (cpp || cs)

    static var mainThread:Thread;

    static var queue:Deque<Void->Void>;

    #end

    /**
     * Returns `true` if current running thread is main thread
     * @return Bool
     */
    public inline static function currentIsMainThread():Bool {
        
        #if (cpp || cs)
        return mainThread == null || mainThread == Thread.current();
        #else
        return true;
        #end

    }

    /**
     * Call this on your thread to make primary,
     * the calling thread will be used for callbacks.
     */
    @:noCompletion public static function init() {
        #if (cpp || cs)
        queue = new Deque<Void->Void>();
        mainThread = Thread.current();
        #end
    }

    /**
     * Call this on the primary manually,
     * Returns the number of callbacks called.
     */
    @:noCompletion public static function tick():Void {

        #if (cpp || cs)
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

    }

    /**
     * Returns `true` if _running in background_ is emulated on this platform by
     * running _background_ code in main thread instead of using background thread.
     */
    inline public static function isEmulatingBackgroundWithMain():Bool {

        #if (cpp || cs)
        return false;
        #else
        return true;
        #end

    }

    /**
     * Call a function on the primary thread without waiting or blocking.
     * If you want return values see runInMainBlocking
     */
    public static function runInMain(_fn:Void->Void) {

        #if (cpp || cs)
        queue.push(_fn);
        #else
        app.onceImmediate(_fn);
        #end

    }

    /**
     * Create a background thread using the given function, or just run (deferred) the function if threads are not supported
     */
    public static function runInBackground(fn:Void->Void):Void {

        #if (cpp || cs)
        Thread.create(fn);
        #else
        app.onceImmediate(fn);
        #end

    }

}