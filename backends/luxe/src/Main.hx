package;

class Main extends luxe.Game {

    var prevDevicePixelRatio:Float = -1;
    var prevWidth:Float = -1;
    var prevHeight:Float = -1;

    override function config(config:luxe.GameConfig) {

#if (!completion && !display)

        var app = @:privateAccess new ceramic.App();

        // Configure luxe
        config.render.antialiasing = app.settings.antialiasing ? 4 : 0;
        config.window.borderless = false;
        if (app.settings.targetWidth > 0) config.window.width = cast app.settings.targetWidth;
        if (app.settings.targetHeight > 0) config.window.height = cast app.settings.targetHeight;
        config.window.resizable = app.settings.resizable;
        config.window.title = cast app.settings.title;

#end

        return config;

    } //config

    override function ready():Void {

#if (!completion && !display)

        // Keep screen size and density value to trigger
        // resize events that might be skipped by the engine
        prevDevicePixelRatio = Luxe.screen.device_pixel_ratio;
        prevWidth = Luxe.screen.width;
        prevHeight = Luxe.screen.height;

        // Background color
        Luxe.renderer.clear_color.rgb(ceramic.App.app.settings.background);

        // Camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

        // Emit ready event
        ceramic.App.app.backend.emitReady();

        // In some cases (web), we may want to check ourselves
        // If screen size or density has changed and trigger
        // And event if it happens.
        // Let's check every second (the check is cheap).
        Luxe.timer.schedule(1.0, function() {
            triggerResizeIfNeeded();
        }, true);

#end

    } //ready

    override function update(delta:Float):Void {

#if (!completion && !display)

        ceramic.App.app.backend.emitUpdate(delta);

#end

    } //update

    override function onwindowresized(event:luxe.Screen.WindowEvent) {
        
#if (!completion && !display)

        triggerResizeIfNeeded();

#end

    } //onwindowresized

/// Internal

    function triggerResizeIfNeeded():Void {
        
#if (!completion && !display)

        // Ensure screen data has changed since last time we emit event
        if (   Luxe.screen.device_pixel_ratio == prevDevicePixelRatio
            && Luxe.screen.width == prevWidth
            && Luxe.screen.height == prevHeight) return;

        // Update values for next compare
        prevDevicePixelRatio = Luxe.screen.device_pixel_ratio;
        prevWidth = Luxe.screen.width;
        prevHeight = Luxe.screen.height;

        // Emit resize
        ceramic.App.app.backend.screen.emitResize();

        // Update camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

#end

    }

}