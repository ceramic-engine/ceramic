package;

import ceramic.Entity;
import ceramic.Color;
import ceramic.Quad;
import ceramic.InitSettings;
import ceramic.Shortcuts.*;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 4;
        settings.background = Color.GRAY;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FILL;

        app.onceReady(this, ready);

    } //new

    function ready() {

        // Hello World?
        //

        var quad1 = new Quad();
        quad1.color = Color.RED;
        quad1.depth = 2;
        quad1.size(50, 50);
        quad1.anchor(0.5, 0.5);
        quad1.pos(screen.width * 0.5, screen.height * 0.5);
        quad1.rotation = 30;
        quad1.scale(2.0, 0.5);

        var quad2 = new Quad();
        quad2.depth = 1;
        quad2.color = Color.YELLOW;
        quad2.size(50, 50);
        quad2.anchor(0.5, 0.5);
        quad2.pos(screen.width * 0.5, screen.height * 0.5 + 20);
        quad2.rotation = 30;
        quad2.scale(2.0, 0.5);

        app.onUpdate(this, function(delta) {

            quad1.rotation = (quad1.rotation + delta * 100) % 360;
            quad2.rotation = (quad2.rotation + delta * 100) % 360;

        });

    } //ready

}
