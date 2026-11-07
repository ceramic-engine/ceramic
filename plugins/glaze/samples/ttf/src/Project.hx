package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 0;
        settings.background = Color.fromRGB(24, 26, 31);
        settings.targetWidth = 960;
        settings.targetHeight = 640;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new MainScene();

    }

}
