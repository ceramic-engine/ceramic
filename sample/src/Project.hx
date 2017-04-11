package;

import ceramic.Entity;
import ceramic.Color;

class Project extends Entity {

    function new() {

        app.settings.antialiasing = true;
        app.settings.background = Color.GRAY;
        app.settings.width = 640;
        app.settings.height = 480;
        app.settings.scaling = FILL;

        app.onReady(ready);

    } //new

    function ready() {

        // Hello World?

    } //ready

}
