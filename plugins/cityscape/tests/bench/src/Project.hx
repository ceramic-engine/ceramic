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
        // The Glaze app of the view scenarios (headless windows)
        final glazeApp = new glaze.App(new glaze.TestDispatcher());
        scenarios.ViewBench.app = glazeApp;
        // The kit's theme, as in an app using the kit (the editor's
        // scrollbars and popups read it)
        glazeApp.update(cx -> {
            glaze.kit.theme.Theme.setMode(glaze.kit.theme.ThemeMode.Dark, cx);
            glaze.kit.theme.Theme.syncBase(cx);
        });
        new BenchRunner().run();
    }

}
