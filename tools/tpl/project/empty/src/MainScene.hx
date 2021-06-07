package;

import ceramic.Text;
import ceramic.Quad;
import ceramic.Scene;

class MainScene extends Scene {

    var logo:Quad;

    var text:Text;
    
    override function preload() {

        // Add any asset you want to load here
        
        assets.add(Images.CERAMIC);

    }

    override function create() {

        // Called when scene has finished preloading
        
        // Display logo
        logo = new Quad();
        logo.texture = assets.texture(Images.CERAMIC);
        logo.anchor(0.5, 0.5);
        logo.pos(width * 0.5, height * 0.5);
        logo.scale(0.0001);
        logo.alpha = 0;
        add(logo);

        // Create some logo scale "in" animation
        logo.tween(ELASTIC_EASE_IN_OUT, 0.75, 0.0001, 1.0, function(value, time) {
            logo.alpha = value;
            logo.scale(value);
        });

        // Print some log
        log.success('Hello from ceramic :)');

    }

    override function update(delta:Float) {
        
        // Here, you can add code that will be executed at every frame

    }

    override function resize(width:Float, height:Float) {

        // Called everytime the scene size has changed

    }

    override function destroy() {

        // Perform any cleanup before final destroy

        super.destroy();

    }
    
}
