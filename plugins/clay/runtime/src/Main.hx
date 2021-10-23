package;

import backend.ClayEvents;
import backend.ElectronRunner;
import ceramic.Path;
import ceramic.ScreenOrientation;
import clay.Clay;
import haxe.ValueException;

using StringTools;

class Main {

    static var project:Project = null;

    static var events:ClayEvents = null;

    static var app:ceramic.App;

    #if web

    static var lastResizeTime:Float = -1;

    static var lastNewWidth:Int = -1;

    static var lastNewHeight:Int = -1;

    static var readyToDisplay:Bool = false;

    static var resizing:Int = 0;

    #end

    public static function main() {

        events = @:privateAccess new ClayEvents(ready);

        @:privateAccess new Clay(configure, events);

    }

    static function configure(config:clay.Config) {

        // TODO we could probably tidy this file at some point :D

        #if clay_sdl
        config.runtime.autoSwap = true;
        #end
        #if ceramic_disable_background_sleep
        config.window.backgroundSleep = 0;
        #else
        config.window.backgroundSleep = 1.0 / 60;
        #end

        #if (ios || android)
        config.render.opengl.major = 3;
        config.render.opengl.minor = 0;
        #end

        #if web
        var userAgent = js.Browser.navigator.userAgent.toLowerCase();
        if (userAgent.indexOf(' electron/') > -1) {
            try {
                var electronApp:Dynamic = untyped js.Syntax.code("require('electron').remote.require('./app.js');");
                if (electronApp.isCeramicRunner) {
                    ElectronRunner.electronRunner = electronApp;
                }
            } catch (e:Dynamic) {}
        }

        // Are we running from ceramic/electron runner
        if (ElectronRunner.electronRunner != null) {

            // Add css class in html tag to let page change its style as needed
            untyped js.Syntax.code("document.getElementsByTagName('html')[0].className += ' in-electron-runner';");

            // Patch ceramic logger
            @:privateAccess ceramic.Logger._hasElectronRunner = true;

            // Override console.log
            var origConsoleLog:Dynamic = untyped console.log;
            untyped console.log = function(str) {
                ElectronRunner.electronRunner.consoleLog(str);
                origConsoleLog(str);
            };

            // Catch errors
            js.Browser.window.addEventListener('error', function(event:js.html.ErrorEvent) {
                var error = event.error;

                // This seems needed to make exception dumping work as expected in some cases
                if (Std.isOfType(error, ValueException)) {
                    var valueException:ValueException = cast error;
                    var _stack = valueException.stack;
                }

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
                    str = str.replace('http://localhost:' + ElectronRunner.electronRunner.serverPort + '/file:' + (isWin ? '/' : ''), '');

                    // File in compiled project
                    str = str.replace('http://localhost:' + ElectronRunner.electronRunner.serverPort + '/', ElectronRunner.electronRunner.appFiles + '/');

                    ElectronRunner.electronRunner.consoleLog('[error] ' + str);

                    i--;
                }
            });
        }
        #end

        project = @:privateAccess new Project(ceramic.App.init());
        app = @:privateAccess ceramic.App.app;

        #if web
        if (ElectronRunner.electronRunner == null) {
            // If running on web without electron, disable fullscreen.
            // It needs to be explicitly requested by the user.
            if (app.settings.fullscreen) {
                app.settings.fullscreen = false;
            }
        }
        #end

        #if (ios || tvos || android)
        // Force fullscreen on mobile
        app.settings.fullscreen = true;
        #end

        config.render.antialiasing = app.settings.antialiasing;

        if (app.settings.windowWidth > 0)
            config.window.width = app.settings.windowWidth;
        else if (app.settings.targetWidth > 0)
            config.window.width = app.settings.targetWidth;
        if (app.settings.windowHeight > 0)
            config.window.height = app.settings.windowHeight;
        else if (app.settings.targetHeight > 0)
            config.window.height = app.settings.targetHeight;

        config.window.fullscreen = app.settings.fullscreen;
        config.window.resizable = app.settings.resizable;
        config.window.title = app.settings.title;
        config.render.stencil = 2;
        config.render.depth = 16;

        configureOrientation();

        #if cpp
        // Uncaught error handler in native
        config.runtime.uncaughtErrorHandler = @:privateAccess ceramic.Errors.handleUncaughtError;
        #end

        #if web
        if (app.settings.backend.webParent != null) {
            config.runtime.windowParent = app.settings.backend.webParent;
        } else {
            config.runtime.windowParent = js.Browser.document.getElementById('ceramic-app');
        }
        config.runtime.mouseUseBrowserWindowEvents = true;
        if (app.settings.backend.allowDefaultKeys) {
            config.runtime.preventDefaultKeys = [];
        }

        var containerElId:String = app.settings.backend.webParent != null ? app.settings.backend.webParent.id : 'ceramic-app';
        //if (app.settings.resizable) {

            var containerWidth:Int = 0;
            var containerHeight:Int = 0;
            var containerPixelRatio:Float = 0;
            var shouldFixSize = false;

            js.Browser.document.body.classList.add('ceramic-invisible');

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
                var containerEl = js.Browser.document.getElementById(containerElId);
                if (containerEl != null) {
                    var width:Int = containerEl.offsetWidth;
                    var height:Int = containerEl.offsetHeight;
                    var appEl:js.html.CanvasElement = cast js.Browser.document.getElementById('app');

                    /*
                    if (!didForceResizeOnce && !forceResize) {
                        appEl.style.visibility = 'hidden';
                    }
                    */

                    if (lastResizeTime != -1) {
                        if (width != lastNewWidth || height != lastNewHeight) {
                            if (lastNewWidth != -1 || lastNewHeight != -1) {
                                js.Browser.document.body.classList.add('ceramic-invisible');
                            }
                            lastResizeTime = ceramic.Timer.now;
                            lastNewWidth = width;
                            lastNewHeight = height;
                            return;
                        }
                    }

                    if (lastResizeTime != -1 && ceramic.Timer.now - lastResizeTime < 0.1) return;

                    if (width != containerWidth || height != containerHeight || js.Browser.window.devicePixelRatio != containerPixelRatio) {
                        var onlyDensityChanged = (width == containerWidth && height == containerHeight);
                        var pixelRatioUndefined = containerPixelRatio == 0;
                        shouldFixSize = (onlyDensityChanged || pixelRatioUndefined);
                        containerWidth = width;
                        containerHeight = height;
                        containerPixelRatio = js.Browser.window.devicePixelRatio;

                        // Super hacky stuff part I: we subtract one pixel in width if only density changed
                        // This ensure proper resize events are fired and make things work. Yup.
                        // Real size is provided at next frame
                        var appEl:js.html.CanvasElement = cast js.Browser.document.getElementById('app');
                        appEl.style.margin = '0 0 0 0';
                        appEl.style.width = (containerWidth - (shouldFixSize ? 1 : 0)) + 'px';
                        appEl.style.height = containerHeight + 'px';
                        appEl.width = Math.round((containerWidth - (shouldFixSize ? 1 : 0)) * js.Browser.window.devicePixelRatio);
                        appEl.height = Math.round(containerHeight * js.Browser.window.devicePixelRatio);
                        events.muteResizeEvent = shouldFixSize;

                        // Hide weird intermediate state behind a black overlay.
                        // That's not the best option but let's get away with this for now.
                        resizing++;
                        if (lastResizeTime != -1) {
                            js.Browser.document.body.classList.add('ceramic-invisible');
                        }
                        var fn = null;
                        fn = function() {
                            /*if (!didForceResizeOnce) {
                                ceramic.Timer.delay(null, 0.1, fn);
                                return;
                            }*/
                            if (resizing == 0 && readyToDisplay) {
                                js.Browser.document.body.classList.remove('ceramic-invisible');
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
                        events.muteResizeEvent = false;
                        appEl.style.width = containerWidth + 'px';
                        appEl.width = Math.round(containerWidth * js.Browser.window.devicePixelRatio);
                    }
                }
            });

        //}

        // Are we running from ceramic/electron runner
        if (ElectronRunner.electronRunner != null) {

            if (ElectronRunner.electronRunner.ceramicSettings != null) {
                // Configure electron window
                ElectronRunner.electronRunner.ceramicSettings({
                    'trace': function(str:String) {
                        #if debug
                        trace('app.js: ' + str);
                        #end
                    },
                    title: app.settings.title,
                    fullscreen: app.settings.fullscreen,
                    resizable: app.settings.resizable,
                    targetWidth: app.settings.windowWidth > 0 ? app.settings.windowWidth : app.settings.targetWidth,
                    targetHeight: app.settings.windowHeight > 0 ? app.settings.windowHeight : app.settings.targetHeight
                });
            }

            // Bind some events
            if (ElectronRunner.electronRunner.listenFullscreen != null) {
                // Fullscreen events
                ElectronRunner.electronRunner.listenFullscreen(
                    function(e) {
                        ceramic.App.app.settings.fullscreen = true;
                    },
                    function(e) {
                        ceramic.App.app.settings.fullscreen = false;
                    }
                );
            }
        }
        #end

    }

    @:allow(backend.ClayEvents)
    static function ready():Void {

        app.backend.io.initKeyValueIfNeeded();

        #if web

        var ext;
        ext = clay.opengl.GL.gl.getExtension('OES_standard_derivatives');

        if (ElectronRunner.electronRunner != null) {
            ElectronRunner.electronRunner.ceramicReady();
        }

        // Remove "ceramic-invisible" class once we are ready to display
        var intervalId:Dynamic = null;
        function checkSizeReady() {
            var containerElId:String = app.settings.backend.webParent != null ? app.settings.backend.webParent.id : 'ceramic-app';
            var containerEl = js.Browser.document.getElementById(containerElId);
            var appEl:js.html.CanvasElement = cast js.Browser.document.getElementById('app');
            if (appEl.offsetWidth == containerEl.offsetWidth) {
                // If container size is different than app size, that means layout
                // is not at a stable state and we should wait more
                readyToDisplay = true;
                js.Browser.window.clearInterval(intervalId);
            }
            if (readyToDisplay && resizing == 0) {
                js.Browser.document.body.classList.remove('ceramic-invisible');
            }
        }
        intervalId = js.Browser.window.setInterval(checkSizeReady, 500);
        #end

    }

/// Internal

    static function configureOrientation() {

        #if (linc_sdl && cpp)
        var app = ceramic.App.app;

        if (app.settings.orientation != NONE) {

            // Tell SDL which orientation(s) to use, if any is provided

            var hint = [];
            if ((app.settings.orientation & ScreenOrientation.PORTRAIT_UPRIGHT) != 0) {
                hint.push('Portrait');
            }
            if ((app.settings.orientation & ScreenOrientation.PORTRAIT_UPSIDE_DOWN) != 0) {
                hint.push('PortraitUpsideDown');
            }
            if ((app.settings.orientation & ScreenOrientation.LANDSCAPE_LEFT) != 0) {
                hint.push('LandscapeLeft');
            }
            if ((app.settings.orientation & ScreenOrientation.LANDSCAPE_RIGHT) != 0) {
                hint.push('LandscapeRight');
            }


            sdl.SDL.setHint(SDL_HINT_ORIENTATIONS, hint.join(' '));

        }
        #end

    }

}
