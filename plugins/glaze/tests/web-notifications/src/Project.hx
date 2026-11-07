package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

/**
 * Browser check of deliberate deviation DEV-021 (system notifications in a
 * browser), driven by `check.js` in headless Chromium: see `check.sh`.
 */
class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 0;
        settings.background = Color.WHITE;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FIT;

        ceramic.App.app.onceReady(this, () -> {
            ceramic.App.app.scenes.main = new MainScene();
        });

    }

}
