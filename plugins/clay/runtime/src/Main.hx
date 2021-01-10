package;

import backend.ClayEvents;
import clay.Clay;
import ceramic.Path;

class Main {

    public static var project:Project = null;

    public static var events:ClayEvents = null;

    #if web
    
    static var electronRunner:Dynamic = null;

    static var lastResizeTime:Float = -1;

    static var lastNewWidth:Int = -1;

    static var lastNewHeight:Int = -1;
    
    #end

    public static function main() {
        
        events = @:privateAccess new ClayEvents();

        @:privateAccess new Clay(configure, events);

    }

    static function configure(config:clay.Config) {

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
        var userAgent = navigator.userAgent.toLowerCase();
        if (userAgent.indexOf(' electron/') > -1) {
            try {
                var electronApp:Dynamic = untyped js.Syntax.code("require('electron').remote.require('./app.js');");
                if (electronApp.isCeramicRunner) {
                    electronRunner = electronApp;
                }
            } catch (e:Dynamic) {}
        }

        // Are we running from ceramic/electron runner
        if (electronRunner != null) {

            // Add css class in html tag to let page change its style as needed
            untyped js.Syntax.code("document.getElementsByTagName('html')[0].className += ' in-electron-runner';");

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

        project = @:privateAccess new Project(ceramic.App.init());
        var app = @:privateAccess ceramic.App.app;

        config.render.antialiasing = app.settings.antialiasing;
        if (app.settings.windowWidth > 0)
            config.window.width = app.settings.windowWidth;
        else if (app.settings.targetWidth > 0)
            config.window.width = app.settings.targetWidth;
        if (app.settings.windowHeight > 0)
            config.window.height = app.settings.windowHeight;
        else if (app.settings.targetHeight > 0)
            config.window.height = app.settings.targetHeight;
        config.window.resizable = app.settings.resizable;
        config.window.title = app.settings.title;
        config.render.stencil = 2;
        config.render.depth = 16;

        #if cpp
        // Uncaught error handler in native
        config.runtime.uncaughtErrorHandler = @:privateAccess ceramic.Errors.handleUncaughtError;
        #end

        #if web
        if (app.settings.backend.webParent != null) {
            config.runtime.windowParent = app.settings.backend.webParent;
        } else {
            config.runtime.windowParent = document.getElementById('ceramic-app');
        }
        config.runtime.browserWindowMousemove = true;
        config.runtime.browserWindowMouseup = true;
        if (app.settings.backend.allowDefaultKeys) {
            config.runtime.preventDefaultKeys = [];
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
                targetWidth: app.settings.windowWidth > 0 ? app.settings.windowWidth : app.settings.targetWidth,
                targetHeight: app.settings.windowHeight > 0 ? app.settings.windowHeight : app.settings.targetHeight
            });
        }
        #end

    }

    // static var _lastUpdateTime:Float = -1;

    // public static function main():Void {

    //     project = @:privateAccess new Project(ceramic.App.init());
        
    //     #if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
    //     ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..']));
    //     #end

    //     #if js
    //     _lastUpdateTime = untyped __js__('new Date().getTime()');
    //     untyped __js__('setInterval({0}, 100)', update);
    //     #end

    //     // Emit ready event
    //     ceramic.App.app.backend.emitReady();

    // }

    // static function update() {

    //     #if js
    //     var time:Float = untyped __js__('new Date().getTime()');
    //     var delta = (time - _lastUpdateTime) * 0.001;
    //     _lastUpdateTime = time;

    //     // Update
    //     ceramic.App.app.backend.emitUpdate(delta);
    //     #end

    // }

}
