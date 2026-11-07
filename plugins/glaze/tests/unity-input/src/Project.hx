package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.BLACK;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = RESIZE;
        settings.resizable = true;
        settings.title = 'Scroll calibration';

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new MainScene();

    }

}
