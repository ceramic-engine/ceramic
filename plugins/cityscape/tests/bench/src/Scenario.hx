package;

/**
 * A benchmark scenario: set up once, then `step(frame)` is timed for each
 * frame (warmup frames first, not measured). Register it in `Scenarios.hx`.
 *
 * Scenarios that need an editor on screen will open a Glaze window in
 * `setup` (like Glaze's own bench); the runner then gains drawing, view and
 * allocation measures as they are needed.
 */
interface Scenario {

    /**
     * Short identifier used in the summary lines, the JSON file name and
     * `CITYSCAPE_BENCH_SCENARIOS` (letters, digits, dashes).
     */
    var name:String;

    function setup():Void;

    /**
     * The measured work of one frame.
     */
    function step(frame:Int):Void;

    function teardown():Void;

}
