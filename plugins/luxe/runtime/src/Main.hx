package;

#if web

import js.Browser.navigator;
import js.Browser.window;
import js.Browser.document;

#end

import luxe.Input;

using StringTools;

@:access(backend.Backend)
@:access(backend.Screen)
class Main extends luxe.Game {

    public static function main() {
        
        new Main();

    }

    public static var project:Project = null;

#if web

    static var electronRunner:Dynamic = null;
    static var lastResizeTime:Float = -1;
    static var lastNewWidth:Int = -1;
    static var lastNewHeight:Int = -1;

#end

    static var lastDevicePixelRatio:Float = -1;
    static var lastWidth:Float = -1;
    static var lastHeight:Float = -1;

    static var touches:Map<Int,Int> = new Map();
    static var touchIndexes:Map<Int,Int> = new Map();

    static var mouseDownButtons:Map<Int,Bool> = new Map();
    static var mouseX:Float = 0;
    static var mouseY:Float = 0;

    static var activeControllers:Map<Int,Bool> = new Map();
    static var removedControllers:Map<Int,Bool> = new Map();

    static var instance:Main;

    static var muteResizeEvent:Bool = false;

    override function config(config:luxe.GameConfig) {

        Luxe.core.auto_render = false;
        #if (linc_sdl && cpp)
        Luxe.snow.runtime.auto_swap = false;
        #end
        #if ceramic_disable_background_sleep
        Luxe.core.game_config.window.background_sleep = 0;
        #else
        Luxe.core.game_config.window.background_sleep = 1.0 / 60;
        #end

        #if (ios || android)
        Luxe.core.game_config.render.opengl.major = 3;
        Luxe.core.game_config.render.opengl.minor = 0;
        #end

#if web

        var userAgent = navigator.userAgent.toLowerCase();
        if (userAgent.indexOf(' electron/') > -1) {
            try {
                var electronApp:Dynamic = untyped __js__("require('electron').remote.require('./app.js');");
                if (electronApp.isCeramicRunner) {
                    electronRunner = electronApp;
                }
            } catch (e:Dynamic) {}
        }

        // Are we running from ceramic/electron runner
        if (electronRunner != null) {

            // Add css class in html tag to let page change its style as needed
            untyped __js__("document.getElementsByTagName('html')[0].className += ' in-electron-runner';");

            // Patch ceramic logger
            @:privateAccess ceramic.Logger._hasElectronRunner = true;

            // Override console.log
            var origConsoleLog:Dynamic = untyped console.log;
            untyped console.log = function(str) {
                electronRunner.consoleLog(str);
                origConsoleLog(str);
            };

            // Catch errors
            window.addEventListener('error', function(event:js.html.ErrorEvent) {
                var error = event.error;
                var stack = (''+error.stack).split("\n");
                var len = stack.length;
                var i = len - 1;
                var file = '';
                var line = 0;
                var isWin:Bool = untyped navigator.platform.indexOf('Win') != -1;
                
                while (i >= 0) {
                    var str = stack[i];
                    str = str.ltrim();

                    // File in haxe project
                    str = str.replace('http://localhost:' + electronRunner.serverPort + '/file:' + (isWin ? '/' : ''), '');

                    // File in compiled project
                    str = str.replace('http://localhost:' + electronRunner.serverPort + '/', electronRunner.appFiles + '/');

                    electronRunner.consoleLog('[error] ' + str);

                    i--;
                }
            });
        }

#end

        instance = this;
        project = @:privateAccess new Project(ceramic.App.init());
        var app = @:privateAccess ceramic.App.app;


#if snow_openal_manual_init
        // On ios, we didn't init OpenAL right away because
        // we need to wait for ceramic app init to be able to configure
        // which kind of AVAudioSessionCategory we are running on
        Luxe.snow.audio.module.init_al();
        Luxe.snow.audio.active = true;
#end

        // Configure luxe
        config.render.antialiasing = app.settings.antialiasing;
        config.window.borderless = false;
        if (app.settings.targetWidth > 0) config.window.width = cast app.settings.targetWidth;
        if (app.settings.targetHeight > 0) config.window.height = cast app.settings.targetHeight;
        config.window.resizable = app.settings.resizable;
        config.window.title = cast app.settings.title;
        config.render.stencil = 2;
        //config.render.depth = 16;

#if cpp
        // Uncaught error handler in native
        config.runtime.uncaught_error_handler = @:privateAccess ceramic.Errors.handleUncaughtError;
#end

#if web
        if (app.settings.backend.webParent != null) {
            config.runtime.window_parent = app.settings.backend.webParent;
        } else {
            config.runtime.window_parent = document.getElementById('ceramic-app');
        }
        config.runtime.browser_window_mousemove = true;
        config.runtime.browser_window_mouseup = true;
        if (app.settings.backend.allowDefaultKeys) {
            config.runtime.prevent_default_keys = [];
        }

        var containerElId:String = app.settings.backend.webParent != null ? app.settings.backend.webParent.id : 'ceramic-app';
        //if (app.settings.resizable) {

            var containerWidth:Int = 0;
            var containerHeight:Int = 0;
            var containerPixelRatio:Float = 0;
            var resizing = 0;
            var shouldFixSize = false;

            var appEl:js.html.CanvasElement = cast document.getElementById('app');
            if (appEl != null) {
                document.body.classList.add('ceramic-invisible');
                appEl.style.visibility = 'hidden';
            }

            /*
            var forceResize = false;
            var didForceResizeOnce = false;

            // Hacky resize stuff again.
            // Sticking with this for now until we find a smarter
            ceramic.Timer.delay(null, 0.5, () -> {
                forceResize = true;
                didForceResizeOnce = true;
            });
            */
            
            app.onUpdate(null, function(delta) {
                var containerEl = document.getElementById(containerElId);
                if (containerEl != null) {
                    var width:Int = containerEl.offsetWidth;
                    var height:Int = containerEl.offsetHeight;
                    var appEl:js.html.CanvasElement = cast document.getElementById('app');

                    /*
                    if (!didForceResizeOnce && !forceResize) {
                        appEl.style.visibility = 'hidden';
                    }
                    */

                    if (lastResizeTime != -1) {
                        if (width != lastNewWidth || height != lastNewHeight) {
                            if (lastNewWidth != -1 || lastNewHeight != -1) {
                                document.body.classList.add('ceramic-invisible');
                                appEl.style.visibility = 'hidden';
                            }
                            lastResizeTime = ceramic.Timer.now;
                            lastNewWidth = width;
                            lastNewHeight = height;
                            return;
                        }
                    }

                    if (lastResizeTime != -1 && ceramic.Timer.now - lastResizeTime < 0.1) return;

                    if (width != containerWidth || height != containerHeight || window.devicePixelRatio != containerPixelRatio) {
                        var onlyDensityChanged = (width == containerWidth && height == containerHeight);
                        var pixelRatioUndefined = containerPixelRatio == 0;
                        shouldFixSize = (onlyDensityChanged || pixelRatioUndefined);
                        containerWidth = width;
                        containerHeight = height;
                        containerPixelRatio = window.devicePixelRatio;

                        // Super hacky stuff part I: we subtract one pixel in width if only density changed
                        // This ensure proper resize events are fired and make things work. Yup.
                        // Real size is provided at next frame
                        var appEl:js.html.CanvasElement = cast document.getElementById('app');
                        appEl.style.margin = '0 0 0 0';
                        appEl.style.width = (containerWidth - (shouldFixSize ? 1 : 0)) + 'px';
                        appEl.style.height = containerHeight + 'px';
                        appEl.width = Math.round((containerWidth - (shouldFixSize ? 1 : 0)) * window.devicePixelRatio);
                        appEl.height = Math.round(containerHeight * window.devicePixelRatio);
                        muteResizeEvent = shouldFixSize;

                        // Hide weird intermediate state behind a black overlay.
                        // That's not the best option but let's get away with this for now.
                        resizing++;
                        if (lastResizeTime != -1) {
                            document.body.classList.add('ceramic-invisible');
                            appEl.style.visibility = 'hidden';
                        }
                        var fn = null;
                        fn = function() {
                            /*if (!didForceResizeOnce) {
                                ceramic.Timer.delay(null, 0.1, fn);
                                return;
                            }*/
                            if (resizing == 0) {
                                document.body.classList.remove('ceramic-invisible');
                                appEl.style.visibility = 'visible';
                            }
                        };
                        ceramic.Timer.delay(null, 0.1, () -> {
                            resizing--;
                            fn();
                        });

                        lastResizeTime = ceramic.Timer.now;
                    }
                    else if (shouldFixSize) {
                        // Hacky resize stuff part II
                        shouldFixSize = false;
                        muteResizeEvent = false;
                        appEl.style.width = containerWidth + 'px';
                        appEl.width = Math.round(containerWidth * window.devicePixelRatio);
                    }
                }
            });

        //}

        // Are we running from ceramic/electron runner
        if (electronRunner != null) {

            // Configure electron window
            electronRunner.ceramicSettings({
                'trace': function(str:String) {
                    #if debug
                    trace('app.js: ' + str);
                    #end
                },
                title: app.settings.title,
                resizable: app.settings.resizable,
                targetWidth: app.settings.targetWidth,
                targetHeight: app.settings.targetHeight
            });
        }
#end

#if (linc_sdl && cpp)
        var runtime:snow.modules.sdl.Runtime = cast Luxe.snow.runtime;
        runtime.handle_sdl_event = event -> {
            app.backend.emitSdlEvent(event);
        };
#end

        return config;

    }

    override function ready():Void {

        // Keep screen size and density value to trigger
        // resize events that might be skipped by the engine
        lastDevicePixelRatio = Luxe.screen.device_pixel_ratio;
        lastWidth = Luxe.screen.width;
        lastHeight = Luxe.screen.height;
        ceramic.App.app.backend.screen.density = lastDevicePixelRatio;
        ceramic.App.app.backend.screen.width = Std.int(lastWidth);
        ceramic.App.app.backend.screen.height = Std.int(lastHeight);

        // Background color
        Luxe.renderer.clear_color.rgb(ceramic.App.app.settings.background);

        // Camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

#if (mac && linc_sdl && cpp)
        var runtime:snow.modules.sdl.Runtime = cast Luxe.snow.runtime;
        if (runtime.window_hidden_at_startup) {
            runtime.window_hidden_at_startup = false;
            sdl.SDL.showWindow(runtime.window);
        }
#end

        // Emit ready event
        ceramic.App.app.backend.emitReady();

#if web
        if (electronRunner != null) {
            electronRunner.ceramicReady();
        }
#end

    }

    override function update(delta:Float):Void {

        // We may need to trigger resize explicitly as luxe/snow
        // doesn't seem to always detect it automatically.
        triggerResizeIfNeeded();

        // Update
        ceramic.App.app.backend.emitUpdate(delta);

    }

    override function onwindowresized(event:luxe.Screen.WindowEvent) {

        triggerResizeIfNeeded();

    }

// Only handle mouse on desktop & web, for now
#if (mac || windows || linux || web)

    override function onmousedown(event:MouseEvent) {

        if (mouseDownButtons.exists(event.button)) {
            onmouseup(event);
        }

        mouseX = event.x;
        mouseY = event.y;

        mouseDownButtons.set(event.button, true);
        ceramic.App.app.backend.screen.emitMouseDown(
            event.button,
            event.x,
            event.y
        );

    }

    override function onmouseup(event:MouseEvent) {

        if (!mouseDownButtons.exists(event.button)) {
            return;
        }

        mouseX = event.x;
        mouseY = event.y;

        mouseDownButtons.remove(event.button);
        ceramic.App.app.backend.screen.emitMouseUp(
            event.button,
            event.x,
            event.y
        );

    }

    override function onmousewheel(event:MouseEvent) {

#if (linc_sdl && cpp)
        var runtime:snow.modules.sdl.Runtime = cast Luxe.snow.runtime;
        var direction:Int = runtime.current_ev.wheel.direction;
        var sdlWheelMul = 5; // Try to have consistent behavior between web and cpp platforms
        if (direction == 1) {
            ceramic.App.app.backend.screen.emitMouseWheel(
                event.x * -1 * sdlWheelMul,
                event.y * -1 * sdlWheelMul
            );
        }
        else {
            ceramic.App.app.backend.screen.emitMouseWheel(
                event.x * -1 * sdlWheelMul,
                event.y * -1 * sdlWheelMul
            );
        }
        return;
#end

        ceramic.App.app.backend.screen.emitMouseWheel(
            event.x,
            event.y
        );

    }

    override function onmousemove(event:MouseEvent) {

        mouseX = event.x;
        mouseY = event.y;

        ceramic.App.app.backend.screen.emitMouseMove(
            event.x,
            event.y
        );

    }

#end

    override function onkeydown(event:KeyEvent) {

        ceramic.App.app.backend.emitKeyDown({
            keyCode: event.keycode,
            scanCode: event.scancode
        });

    }

    override function onkeyup(event:KeyEvent) {

        ceramic.App.app.backend.emitKeyUp({
            keyCode: event.keycode,
            scanCode: event.scancode
        });

    }

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
            event.x * lastWidth,
            event.y * lastHeight
        );

    }

    override function ontouchup(event:TouchEvent) {

        if (!touches.exists(event.touch_id)) {
            ontouchdown(event);
        }
        var index = touches.get(event.touch_id);

        ceramic.App.app.backend.screen.emitTouchUp(
            index,
            event.x * lastWidth,
            event.y * lastHeight
        );

        touches.remove(event.touch_id);
        touchIndexes.remove(index);

    }

    override function ontouchmove(event:TouchEvent) {

        if (!touches.exists(event.touch_id)) {
            ontouchdown(event);
        }
        var index = touches.get(event.touch_id);

        ceramic.App.app.backend.screen.emitTouchMove(
            index,
            event.x * lastWidth,
            event.y * lastHeight
        );

    }

#end

    override public function ongamepadaxis(event:GamepadEvent) {

        var id = event.gamepad;
        if (!activeControllers.exists(id) && !removedControllers.exists(id)) {
            activeControllers.set(id, true);
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            ceramic.App.app.backend.emitControllerEnable(id, name);
        }

        ceramic.App.app.backend.emitControllerAxis(id, event.axis, event.value);

    }

    override public function ongamepaddown(event:GamepadEvent) {

        var id = event.gamepad;
        if (!activeControllers.exists(id) && !removedControllers.exists(id)) {
            activeControllers.set(id, true);
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            ceramic.App.app.backend.emitControllerEnable(id, name);
        }

        ceramic.App.app.backend.emitControllerDown(id, event.button);

    }

    override public function ongamepadup(event:GamepadEvent) {

        var id = event.gamepad;
        if (!activeControllers.exists(id) && !removedControllers.exists(id)) {
            activeControllers.set(id, true);
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            ceramic.App.app.backend.emitControllerEnable(id, name);
        }

        ceramic.App.app.backend.emitControllerUp(id, event.button);

    }

    override public function ongamepaddevice(event:GamepadEvent) {

        var id = event.gamepad;
        if (event.type == GamepadEventType.device_removed) {
            if (activeControllers.exists(id)) {
                ceramic.App.app.backend.emitControllerDisable(id);
                activeControllers.remove(id);
                removedControllers.set(id, true);
                ceramic.App.app.onceUpdate(null, function(_) {
                    removedControllers.remove(id);
                });
            }
        }
        else if (event.type == GamepadEventType.device_added) {
            if (!activeControllers.exists(id)) {
                activeControllers.set(id, true);
                removedControllers.remove(id);
                var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
                ceramic.App.app.backend.emitControllerEnable(id, name);
            }
        }

    }

    static var backgroundStatus:Int = -1;

    static var foregroundStatus:Int = -1;

    override function onevent(event:snow.types.Types.SystemEvent) {

        switch (event.type) {
            case se_unknown:
            case se_init:
            case se_ready:
            case se_tick:
            case se_freeze:
            case se_unfreeze:
            case se_suspend:
            case se_shutdown:
            case se_window:
            case se_input:
            case se_quit:
            case se_app_terminating:
                @:privateAccess ceramic.App.app.emitTerminate();
            case se_app_lowmemory:
                @:privateAccess ceramic.App.app.emitLowMemory();
            case se_app_willenterbackground:
                #if android
                if (backgroundStatus < 0) {
                    backgroundStatus = 0;
                    foregroundStatus = -1;
                    return;
                }
                #end
                @:privateAccess ceramic.App.app.emitBeginEnterBackground();
            case se_app_didenterbackground:
                #if android
                if (backgroundStatus < 1) {
                    backgroundStatus = 1;
                    foregroundStatus = -1;
                    return;
                }
                #end
                @:privateAccess ceramic.App.app.emitFinishEnterBackground();
            case se_app_willenterforeground:
                #if android
                if (foregroundStatus < 0) {
                    foregroundStatus = 0;
                    backgroundStatus = -1;
                    return;
                }
                #end
                @:privateAccess ceramic.App.app.emitBeginEnterForeground();
            case se_app_didenterforeground:
                #if android
                if (foregroundStatus < 1) {
                    foregroundStatus = 1;
                    backgroundStatus = -1;
                    return;
                }
                #end
                @:privateAccess ceramic.App.app.emitFinishEnterForeground();
        }

    }

/// Internal

    function triggerResizeIfNeeded():Void {

        var nativeDensity = #if web window.devicePixelRatio #else Luxe.screen.device_pixel_ratio #end;
        // Ensure screen data has changed since last time we emit event
        if (   nativeDensity == lastDevicePixelRatio
            && Luxe.screen.width == lastWidth
            && Luxe.screen.height == lastHeight) return;
        
        if (muteResizeEvent) return;

        #if web
        @:privateAccess Luxe.snow.runtime.update_window_bounds();
        #end

        // Update values for next compare
        lastDevicePixelRatio = nativeDensity;
        lastWidth = Luxe.screen.width;
        lastHeight = Luxe.screen.height;
        ceramic.App.app.backend.screen.density = lastDevicePixelRatio;
        ceramic.App.app.backend.screen.width = Std.int(lastWidth);
        ceramic.App.app.backend.screen.height = Std.int(lastHeight);

        // Emit resize
        ceramic.App.app.backend.screen.emitResize();

        // Update camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * nativeDensity, Luxe.screen.height * nativeDensity);

    }

}
