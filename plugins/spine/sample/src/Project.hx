package;

import ceramic.InitSettings;

import ceramic.Spine;
import ceramic.Spines;

class Project extends Entity {

    var assets = new Assets();

    function new(settings:InitSettings) {

        settings.antialiasing = true;
        settings.background = Color.GRAY;
        settings.targetWidth = 800;
        settings.targetHeight = 600;
        settings.scaling = FILL;
        settings.resizable = false;

        app.onceReady(ready);

    } //new

    function ready() {

        assets.add(Spines.STRETCHYMAN, { scale: 0.8 });
        assets.onceComplete(this, function(_success) {

            if (!_success) {
                error('Failed to load some resources');
            } else {
                success('Finished loading');
            }

            var anim = new Spine();
            anim.spineData = assets.spine(Spines.STRETCHYMAN);
            anim.pos(0, screen.height * 0.9);
            anim.animate(Spines.STRETCHYMAN.SNEAK, true);

        });

        assets.load();

    } //ready

}
