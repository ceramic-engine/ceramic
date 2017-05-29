package;

import luxe.Input;

class Main extends luxe.Game {

    static var lastDevicePixelRatio:Float = -1;
    static var lastWidth:Float = -1;
    static var lastHeight:Float = -1;

    static var touches:Map<Int,Int> = new Map();
    static var touchIndexes:Map<Int,Int> = new Map();

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
        lastDevicePixelRatio = Luxe.screen.device_pixel_ratio;
        lastWidth = Luxe.screen.width;
        lastHeight = Luxe.screen.height;

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

    override function onmousedown(event:MouseEvent) {

        ceramic.App.app.backend.screen.emitMouseDown(
            event.button,
            event.x,
            event.y
        );

    } //onmousedown

    override function onmouseup(event:MouseEvent) {

        ceramic.App.app.backend.screen.emitMouseUp(
            event.button,
            event.x,
            event.y
        );

    } //onmouseup

    override function onmousewheel(event:MouseEvent) {

        ceramic.App.app.backend.screen.emitMouseWheel(
            event.x,
            event.y
        );

    } //onmousewheel

    override function onmousemove(event:MouseEvent) {

        ceramic.App.app.backend.screen.emitMouseMove(
            event.x,
            event.y
        );

    } //onmousemove

    override function onkeydown(event:KeyEvent) {

        ceramic.App.app.backend.emitKeyDown({
            keyCode: event.keycode,
            scanCode: event.scancode
        });

    } //onkeydown

    override function onkeyup(event:KeyEvent) {

        ceramic.App.app.backend.emitKeyUp({
            keyCode: event.keycode,
            scanCode: event.scancode
        });

    } //onkeyup

// Don't handle touch on desktop, for now
#if !(mac || windows || linux)

    override function ontouchdown(event:TouchEvent) {

        var index = 0;
        while (touchIndexes.exists(index)) {
            index++;
        }
        touches.set(event.touch_id, index);
        touchIndexes.set(index, event.touch_id);

        ceramic.App.app.backend.screen.emitTouchDown(
            index,
            event.x,
            event.y
        );

    } //ontouchdown

    override function ontouchup(event:TouchEvent) {

        if (!touches.exists(event.touch_id)) {
            ontouchdown(event);
        }
        var index = touches.get(event.touch_id);

        ceramic.App.app.backend.screen.emitTouchUp(
            index,
            event.x,
            event.y
        );

        touches.remove(event.touch_id);
        touchIndexes.remove(index);

    } //ontouchup

    override function ontouchmove(event:TouchEvent) {

        if (!touches.exists(event.touch_id)) {
            ontouchdown(event);
        }
        var index = touches.get(event.touch_id);

        ceramic.App.app.backend.screen.emitTouchMove(
            index,
            event.x,
            event.y
        );

    } //ontouchmove

#end

/// Internal

    function triggerResizeIfNeeded():Void {
        
#if (!completion && !display)

        // Ensure screen data has changed since last time we emit event
        if (   Luxe.screen.device_pixel_ratio == lastDevicePixelRatio
            && Luxe.screen.width == lastWidth
            && Luxe.screen.height == lastHeight) return;

        // Update values for next compare
        lastDevicePixelRatio = Luxe.screen.device_pixel_ratio;
        lastWidth = Luxe.screen.width;
        lastHeight = Luxe.screen.height;

        // Emit resize
        ceramic.App.app.backend.screen.emitResize();

        // Update camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

#end

    }

}