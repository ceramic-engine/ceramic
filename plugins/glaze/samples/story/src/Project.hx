package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.WHITE;
        settings.targetWidth = 1280;
        settings.targetHeight = 800;
        settings.scaling = RESIZE;
        settings.resizable = true;
        settings.title = 'GPUI Component';

        app.onceReady(this, ready);

    }

    function ready() {

        // Set MainScene as the current scene (see MainScene.hx)
        app.scenes.main = new MainScene();

    }

}
