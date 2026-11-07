package;

import glaze.App;
import glaze.Window;

/**
 * A benchmark scenario: a window built once per mode, then one mutation or
 * input per frame. The runner (`BenchRunner`) draws the window after each
 * `step`, measures the frame time, the views rendered and reused, the objects
 * allocated and the per-phase timings, and writes a JSON result.
 *
 * Implement it directly, or extend `BaseScenario` for the defaults (both
 * modes, no-op teardown). Register the scenario in `Scenarios.hx`.
 */
interface Scenario {

    /**
     * Short identifier used in the summary lines, the JSON file name and
     * `GLAZE_BENCH_SCENARIOS` (letters, digits, dashes).
     */
    var name:String;

    /**
     * Which view caching modes to measure: `false` is a full render every
     * frame (no view cache, like GPUI's uncached views), `true` the default
     * view caching. `[false, true]` runs both.
     */
    var cachedModes:Array<Bool>;

    /**
     * Opens the window of the scenario for one mode. Use
     * `BenchRunner.openWindow(app, caching, buildRoot)` to get the standard
     * 1280x1024 window at scale 2 with the right caching options, or open
     * your own `Window` (pass `autoDraw: false, bindInput: false,
     * viewCaching: caching` and set `window.viewCachingDisabled = !caching`).
     * The runner draws the first frame itself.
     */
    function setup(app:App, caching:Bool):Window;

    /**
     * The per-frame mutation or input (change an observable field, dispatch a
     * key, scroll...). Called before each draw, warmup frames included.
     * Anything that must be flushed goes through `ceramic.App.app.flushImmediate()`
     * which the runner calls right after.
     */
    function step(frame:Int):Void;

    /**
     * Called after the measurements of one mode, before the window is
     * destroyed by the runner.
     */
    function teardown():Void;

}
