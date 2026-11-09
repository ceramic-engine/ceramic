package;

import ceramic.Entity;
import ceramic.InitSettings;

/**
 * Benchmark suite of Cityscape: `BenchRunner` runs the scenarios of
 * `Scenarios.all()`, prints a summary per scenario and writes a JSON result
 * per scenario in `results/` (see `BenchRunner` for the environment
 * variables).
 *
 * Run: `ceramic headless run node --setup --assets --allow-multiple` (Node) or
 * `ceramic clay build mac --setup --assets --allow-multiple` then
 * `project/mac/bench.app/Contents/MacOS/bench` (native).
 */
class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 640;
        settings.targetHeight = 480;

        app.onceReady(this, ready);

    }

    function ready() {
        new BenchRunner().run();
    }

}
