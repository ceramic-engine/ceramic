package;

import ceramic.Entity;
import ceramic.Quad;
import ceramic.Color;
import ceramic.Assets;
import ceramic.Blending;

class Project extends Entity {

    var assets:Assets = new Assets();

    function new() {

        app.settings.antialiasing = true;
        app.settings.background = 0x444444;
        app.settings.width = 320;
        app.settings.height = 568;
        app.settings.scaling = FILL;

        app.onReady(ready);

    } //new

    function ready() {

        var quad1 = new Quad();
        quad1.color = Color.RED;
        quad1.depth = 2;
        quad1.size(50, 50);
        quad1.anchor(0.5, 0.5);
        quad1.pos(320 * 0.5, 568 * 0.5);
        quad1.rotation = 30;
        quad1.scale(2.0, 0.5);

        var quad2 = new Quad();
        quad2.depth = 1;
        quad2.color = Color.YELLOW;
        quad2.size(50, 50);
        quad2.anchor(0.5, 0.5);
        quad2.pos(320 * 0.5, 568 * 0.5 + 20);
        quad2.rotation = 30;
        quad2.scale(2.0, 0.5);

        screen.onUpdate(function(delta) {

            quad1.rotation = (quad1.rotation + delta * 100) % 360;
            quad2.rotation = (quad2.rotation + delta * 100) % 360;

        }, this);

        trace('loading assets...');

        var textureName = 'NOPEMAN_TALK.spine/NOPEMAN_TALK@1x.png';
        assets.addTexture(textureName);
        assets.onceComplete(function(success) {
            trace("ASSETS COMPLETE: success=" + success);

            var texture = assets.texture(textureName);
            trace('texture width=' + texture.width + ' height=' + texture.height);

            var quad3 = new Quad();
            quad3.texture = texture;
            quad3.frame(0, 0, 100, 200);
            quad3.pos(20, 220);
            quad3.depth = 4;
            quad3.skewX = 25;
            quad3.blending = Blending.Additive;

            quad3.data.name = "Patrick";
            quad3.data.youpi = "bref";
            
        });
        assets.load();

    } //ready

}
