package;

import ceramic.Entity;
import ceramic.InitSettings;
import glaze.App;
import glaze.TestDispatcher;

/**
 * Benchmark suite of Glaze: `BenchRunner` runs the scenarios of
 * `Scenarios.all()` (`cards`, `idle`, and the ones under `src/scenarios/`),
 * prints a summary per scenario and mode, and writes a JSON result per run in
 * `results/`. See `BenchRunner` for the environment variables and
 * `tests/bench/README.md` for the comparison script.
 *
 * Run: `ceramic headless run node --setup --assets` (Node) or
 * `ceramic clay build mac --setup --assets` then
 * `project/mac/bench.app/Contents/MacOS/bench` (native).
 */
class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 640;
        settings.targetHeight = 480;

        ceramic.App.app.onceReady(this, ready);

    }

    function ready() {
        final app = new App(new TestDispatcher());
        // The icons need no loading: the kit's icons and the full-catalog
        // icons of the stories (ToolbarStory's save icon, the reference icons
        // of InputTokens, copied in resources/glaze/icons like samples/story)
        // are embedded in the code (`IconName`)
        new BenchRunner(this, app).run();
    }

}
