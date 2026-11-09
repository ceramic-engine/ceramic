// New code for Cityscape (not a port): virtual time for the tests that wait
// (vscode's `runWithFakedTimers` of src/vs/base/test/common/timeTravelScheduler.ts).
package testing;

/**
 * Moves Ceramic's timer clock forward and runs the timers due on the way,
 * in the order of their time (timers of the same time in the order they
 * were set), the timers set by a timer included. `Async.setTimeout` goes
 * through `ceramic.Timer`, so the editor's timers run as with vscode's fake
 * timers: `CeramicTimeTravel.advance(1000)` is vscode's `await timeout(1000)`.
 */
@:access(ceramic.Timer)
class CeramicTimeTravel {

    /**
     * The virtual time in milliseconds (`new Date().getTime()` under
     * vscode's fake timers).
     */
    public static function now():Float {
        return ceramic.Timer.now * 1000;
    }

    public static function advance(ms:Float):Void {
        final target = ceramic.Timer.now + ms / 1000.0;
        while (true) {
            var next = Math.POSITIVE_INFINITY;
            for (c in ceramic.Timer.callbacks) {
                if (!c.cleared && c.time < next) {
                    next = c.time;
                }
            }
            if (next > target) {
                break;
            }
            if (next > ceramic.Timer.now) {
                ceramic.Timer.now = next;
            }
            ceramic.Timer.flush();
        }
        ceramic.Timer.now = target;
    }

}
