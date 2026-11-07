package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.WHITE;
        settings.targetWidth = 800;
        settings.targetHeight = 600;
        settings.scaling = RESIZE;
        settings.resizable = true;
        settings.title = 'GPUI examples';

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new MainScene();

    }

}
