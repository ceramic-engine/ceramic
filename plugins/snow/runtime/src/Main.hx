package;

import snow.Snow;
import snow.types.Types;
import snow.modules.opengl.GL;

typedef UserConfig = {}

class Main extends snow.App {

    static var lastDevicePixelRatio:Float = -1;
    static var lastWidth:Float = -1;
    static var lastHeight:Float = -1;

    static var touches:Map<Int,Int> = new Map();
    static var touchIndexes:Map<Int,Int> = new Map();

    static var mouseDownButtons:Map<Int,Bool> = new Map();
    static var mouseX:Float = 0;
    static var mouseY:Float = 0;

    static var instance:Main;

    override function config(config:AppConfig) {

#if (!completion && !display)

        instance = this;
        var ceramicApp = @:privateAccess new ceramic.App();

        // Configure luxe
        config.render.antialiasing = ceramicApp.settings.antialiasing ? 4 : 0;
        config.window.borderless = false;
        if (ceramicApp.settings.targetWidth > 0) config.window.width = cast ceramicApp.settings.targetWidth;
        if (ceramicApp.settings.targetHeight > 0) config.window.height = cast ceramicApp.settings.targetHeight;
        config.window.resizable = ceramicApp.settings.resizable;
        config.window.title = cast ceramicApp.settings.title;

#if web
        if (ceramicApp.settings.backend.webParent != null) {
            config.runtime.window_parent = ceramicApp.settings.backend.webParent;
        }
        //config.runtime.browser_window_mousemove = true;
        //config.runtime.browser_window_mouseup = true;
        if (ceramicApp.settings.backend.allowDefaultKeys) {
            config.runtime.prevent_default_keys = [];
        }
#end

#end

        return config;

    } //config

    override function ready():Void {

#if (!completion && !display)

        // Keep screen size and density value to trigger
        // resize events that might be skipped by the engine
        lastDevicePixelRatio = app.runtime.window_device_pixel_ratio();
        lastWidth = app.runtime.window_width();
        lastHeight = app.runtime.window_height();

        // Background color
        //Luxe.renderer.clear_color.rgb(ceramic.App.app.settings.background);

        // Camera size
        //Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

        // Emit ready event
        ceramic.App.app.backend.snow = app;
        ceramic.App.app.backend.emitReady();

#end

    } //ready

#if (!completion && !display)

/// Update

    override function update(delta:Float):Void {

        // We may need to trigger resize explicitly as snow
        // doesn't seem to always detect it automatically.
        triggerResizeIfNeeded();

        // Update
        ceramic.App.app.backend.emitUpdate(delta);
    
    }

/// Events

    override function onevent(event:SystemEvent) {

        if (event.window != null) {
            if (event.window.type == we_size_changed || event.window.type == we_resized) {

                triggerResizeIfNeeded();

                /*window_width = event.window.x;
                window_height = event.window.y;
                var _scale = app.runtime.window_device_pixel_ratio();
                trace('${event.window.type} / $_scale / size changed ${event.window.x}x${event.window.y}');*/
            }
        }

    } //onevent

    override function onmousedown(x:Int, y:Int, button:Int, timestamp:Float, window_id:Int) {

        if (mouseDownButtons.exists(button)) {
            onmouseup(x, y, button, timestamp, window_id);
        }

        mouseX = x;
        mouseY = y;

        mouseDownButtons.set(button, true);
        ceramic.App.app.backend.screen.emitMouseDown(
            button,
            x,
            y
        );

    } //onmousedown

    override function onmouseup(x:Int, y:Int, button:Int, timestamp:Float, window_id:Int) {

        if (!mouseDownButtons.exists(button)) {
            return;
        }

        mouseX = x;
        mouseY = y;

        mouseDownButtons.remove(button);
        ceramic.App.app.backend.screen.emitMouseUp(
            button,
            x,
            y
        );

    } //onmouseup

    override function onmousewheel(x:Float, y:Float, timestamp:Float, window_id:Int) {

        ceramic.App.app.backend.screen.emitMouseWheel(
            x,
            y
        );

    } //onmousewheel

    override function onmousemove(x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, window_id:Int) {

        mouseX = x;
        mouseY = y;

        ceramic.App.app.backend.screen.emitMouseMove(
            x,
            y
        );

    } //onmousemove

    override function onkeydown(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, window_id:Int) {

        ceramic.App.app.backend.emitKeyDown({
            keyCode: keycode,
            scanCode: scancode
        });

    } //onkeydown

    override function onkeyup(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, window_id:Int) {

        ceramic.App.app.backend.emitKeyUp({
            keyCode: keycode,
            scanCode: scancode
        });

    } //onkeyup

// Don't handle touch on desktop, for now
#if !(mac || windows || linux)

    override function ontouchdown(x:Float, y:Float, dx:Float, dy:Float, touch_id:Int, timestamp:Float) {

        var index = 0;
        while (touchIndexes.exists(index)) {
            index++;
        }
        touches.set(touch_id, index);
        touchIndexes.set(index, touch_id);

        ceramic.App.app.backend.screen.emitTouchDown(
            index,
            x,
            y
        );

    } //ontouchdown

    override function ontouchup(x:Float, y:Float, dx:Float, dy:Float, touch_id:Int, timestamp:Float) {

        if (!touches.exists(touch_id)) {
            ontouchdown(x, y, dx, dy, touch_id, timestamp);
        }
        var index = touches.get(touch_id);

        ceramic.App.app.backend.screen.emitTouchUp(
            index,
            x,
            y
        );

        touches.remove(touch_id);
        touchIndexes.remove(index);

    } //ontouchup

    override function ontouchmove(x:Float, y:Float, dx:Float, dy:Float, touch_id:Int, timestamp:Float) {

        if (!touches.exists(touch_id)) {
            ontouchdown(x, y, dx, dy, touch_id, timestamp);
        }
        var index = touches.get(touch_id);

        ceramic.App.app.backend.screen.emitTouchMove(
            index,
            x,
            y
        );

    } //ontouchmove

#end

#end

/// Internal

    function triggerResizeIfNeeded():Void {
        
#if (!completion && !display)

        // Ensure screen data has changed since last time we emit event
        if (   app.runtime.window_device_pixel_ratio() == lastDevicePixelRatio
            && app.runtime.window_width() == lastWidth
            && app.runtime.window_height() == lastHeight) return;

        // Update values for next compare
        lastDevicePixelRatio = app.runtime.window_device_pixel_ratio();
        lastWidth = app.runtime.window_width();
        lastHeight = app.runtime.window_height();

        // Emit resize
        ceramic.App.app.backend.screen.emitResize();

        // Update camera size
        //Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

#end

    }

}