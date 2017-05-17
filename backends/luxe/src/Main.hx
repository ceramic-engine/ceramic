package;

class Main extends luxe.Game {

    override function config(config:luxe.GameConfig) {

#if (!completion && !display)

        var app = @:privateAccess new ceramic.App();

        // Configure luxe
        config.render.antialiasing = app.settings.antialiasing ? 4 : 0;
        config.window.borderless = false;
        if (app.settings.width > 0) config.window.width = cast app.settings.width;
        if (app.settings.height > 0) config.window.height = cast app.settings.height;
        config.window.resizable = app.settings.resizable;
        config.window.title = cast app.settings.title;

#end

        return config;

    } //config

    override function ready():Void {

#if (!completion && !display)

        // Background color
        Luxe.renderer.clear_color.rgb(ceramic.App.app.settings.background);

        // Camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

        ceramic.App.app.backend.emitReady();

#end

    } //ready

    override function update(delta:Float):Void {

#if (!completion && !display)

        ceramic.App.app.backend.emitUpdate(delta);

#end

    } //update

    override function onwindowresized(event:luxe.Screen.WindowEvent) {
        
#if (!completion && !display)

        ceramic.App.app.backend.screen.emitResize();

        // Update camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

#end

    } //onwindowresized

}