// New code for the Haxe port of GPUI (no GPUI origin): the platform
// dispatcher backed by Ceramic. See NOTICE.md.
package gpui;

/**
 * Default `PlatformDispatcher`: `dispatch` uses `app.onceImmediate` (flushed
 * within the current frame), `dispatchAfter` uses `ceramic.Timer` and `now`
 * is `ceramic.Timer.now`.
 */
class CeramicDispatcher implements PlatformDispatcher {

    public function new() {}

    public function dispatch(runnable:Void->Void):Void {
        ceramic.App.app.onceImmediate(runnable);
    }

    public function dispatchAfter(seconds:Float, runnable:Void->Void):Void->Void {
        return ceramic.Timer.delay(null, seconds, runnable);
    }

    public function now():Float {
        return ceramic.Timer.now;
    }

}
