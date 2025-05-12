package ceramic;

#if (cpp || cs)
#if (haxe_ver < 4)
import cpp.vm.Mutex;
#else
import sys.thread.Mutex;
#end
#end

/**
 * An utility to enqueue functions and execute them in bbackground, in a serialized way,
 * meaning it is garanteed that no function in this queue will be run in parallel. An enqueued
 * function will always be started after every previous function has finished executing.
 */
#if (android && clay_sdl)
@:headerCode('#include "linc_sdl.h"')
#end
class BackgroundQueue extends Entity {

    /**
     * Time interval between each checks to see if there is something to run.
     */
    public var checkInterval:Float = 0.1;

    var runsInBackground:Bool = false;

    var stop:Bool = false;

    var pending:Array<Void->Void> = [];

    #if (cpp || cs)
    var mutex:Mutex;
    #end

    public function new(checkInterval:Float = 0.1) {

        super();

        this.checkInterval = 0.1;

        #if (cpp || cs)
        mutex = new Mutex();
        runsInBackground = true;
        Runner.runInBackground(internalRunInBackground);
        #end

    }

    public function schedule(fn:Void->Void):Void {

        #if (cpp || cs)

        // Run in background with ceramic.Runner
        mutex.acquire();
        pending.push(fn);
        mutex.release();

        #else

        // Defer in main thread if background threading is not available
        ceramic.App.app.onceImmediate(fn);

        #end

    }

    #if (cpp || cs)

    private function internalRunInBackground():Void {

        #if (android && clay_sdl)
        // This lets us attach thread to JNI.
        // Required because some JNI calls could be done in background
        untyped __cpp__('SDL_GetAndroidJNIEnv()');
        #end

        #if cs
        untyped __cs__('global::System.Threading.Thread.CurrentThread.CurrentCulture = global::System.Globalization.CultureInfo.CreateSpecificCulture("en-GB")');
        #end

        while (!stop) {
            var shouldSleep = true;

            mutex.acquire();
            if (pending.length > 0) {
                var fn = pending.pop();
                mutex.release();

                shouldSleep = false;
                fn();
            }
            else {
                mutex.release();
            }

            if (shouldSleep) {
                Sys.sleep(checkInterval);
            }
        }

    }

    #end

    override function destroy():Void {

        super.destroy();

        stop = true;

    }

}
