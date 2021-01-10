package backend;

import clay.Clay;

class ClayEvents extends clay.Events {

    var backend:backend.Backend;

    var lastDensity:Float = -1;
    var lastWidth:Float = -1;
    var lastHeight:Float = -1;

    function new() {}

    override function ready() {

        backend = ceramic.App.app.backend;

        // Keep screen size and density value to trigger
        // resize events that might be skipped by the engine
        lastDensity = Clay.app.screenDensity;
        lastWidth = Clay.app.screenWidth;
        lastHeight = Clay.app.screenHeight;

        // TODO
        // Background color
        //Luxe.renderer.clear_color.rgb(ceramic.App.app.settings.background);

        // Camera size
        //Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

        backend.emitReady();

    }

    override function tick(delta:Float) {

        backend.emitUpdate(delta);

    }

}
