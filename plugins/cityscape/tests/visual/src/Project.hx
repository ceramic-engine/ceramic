// New code for Cityscape (not a port): the visual check of the view.
package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

/**
 * Visual check of the Cityscape view: a Haxe sample in two editors (word
 * wrap with an indent per level, typed decorations, a hidden range,
 * selections, cursors, rulers, whitespace, CJK and emoji), `vs-dark` theme.
 * Other scenes with `CITYSCAPE_VISUAL_SCENE`: `folding` (FoldingVisualView),
 * `api` (ApiVisualView: models switched through the editor API, markers,
 * an action) and `columns` (ColumnsVisualView: the column positions of wide
 * text compared with the real Monaco, written as JSON to
 * `CITYSCAPE_VISUAL_COLUMNS_OUT`; the web half of the unit test
 * `WideColumnsTest`).
 *
 * Capture: set `CITYSCAPE_VISUAL_OUT` to a PNG path. After a few frames the
 * pixels are written there with `screen.toPng()`, then the app quits (native)
 * or asks the Electron runner for its window screenshot (web, run with
 * `--screenshot <path> --screenshot-on-signal --screenshot-then-quit`).
 *
 * Native: `ceramic clay build mac --setup --assets --allow-multiple`, then
 * `CITYSCAPE_VISUAL_OUT=<path> project/mac/visual.app/Contents/MacOS/visual`
 * (hidden SDL window). Web: `ceramic clay build web --setup --assets
 * --allow-multiple`, then `ceramic web project --run --hidden ...`.
 */
class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.fromRGB(0x1e, 0x1e, 0x1e);
        settings.targetWidth = 900;
        settings.targetHeight = 560;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {
        app.scenes.main = new MainScene();
    }

}
