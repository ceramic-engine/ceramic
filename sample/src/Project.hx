package;

import ceramic.Settings;
import ceramic.Entity;
import ceramic.Quad;
import ceramic.Color;
import ceramic.Assets;
import ceramic.Blending;
import ceramic.Text;

class Project extends Entity {

    var assets:Assets = new Assets();

    function new(settings:InitSettings) {

        settings.antialiasing = true;
        settings.background = 0x444444;
        settings.resizable = true;
        settings.scaling = FIT;
        settings.targetWidth = 320;
        settings.targetHeight = 568;

        app.onceReady(this, ready);

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

        var text = new Text();
        text.content = "Jérémy.\nligne.";
        //text.rotation = 45;
        text.pointSize = 20;
        text.color = Color.YELLOW;
        text.pos(40, 40);

        trace('text width=${text.width} height=${text.height}');

        /*
        // Just an idea
        var tween = new Tween(easeInOut, 0.3, 3, 4);
        tween.onUpdate(this, function(v) {
            this.alpha = v;
        });
        */

        //assets.addFont(te);
        //assets.addFont(Fonts.BALOO_20);

        assets.add(Fonts.BALOO_20);
        assets.add(Images.TILESHEET);

        assets.onceComplete(this, function(success) {
            log('success? ' + success);
            if (!success) return;

            var font = assets.font(Fonts.BALOO_20);
            text.font = font;

            trace('text width=${text.width} height=${text.height}');

        });

        assets.load();

        screen.onResize(this, function() {

            log('RESIZE width='+screen.width+' height='+screen.height+' density='+screen.density);

        });

        screen.onUpdate(this, function(delta) {

            quad1.rotation = (quad1.rotation + delta * 100) % 360;
            quad2.rotation = (quad2.rotation + delta * 100) % 360;

            //text.skewX = (text.skewX + delta * 100) % 360;

        });

    } //ready

} //Project
