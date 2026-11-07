package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.BLACK;
        settings.targetWidth = 400;
        settings.targetHeight = 300;
        settings.scaling = FIT;
        settings.resizable = true;
        settings.title = 'GPUI text field';

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new MainScene();

    }

}
