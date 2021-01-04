package clay.sdl;

import clay.Config;

import sdl.SDL;
import timestamp.Timestamp;

#if clay_use_glew
import glew.GLEW;
#end

#if (!clay_no_initial_glclear && linc_opengl)
import opengl.WebGL as GL;
#end

/**
 * Native runtime, using SDL to operate
 */
@:access(clay.Clay)
class SDLRuntime extends clay.base.BaseRuntime {

/// Properties

    /**
     * The SDL GL context
     */
    public var gl:sdl.GLContext;

    /**
     * The SDL window handle
     */
    public var window:sdl.Window;

    /**
     * Toggle auto window swap
     */
    public var autoSwap:Bool = true;

    /**
     * Current SDL event being handled, if any
     */
    public var currentSdlEvent:sdl.Event = null;

    /**
     * Whether the window was hidden at startup
     */
    public var windowHiddenAtStartup:Bool = false;

    /**
     * Clay app
     */
    public var app(default, null):Clay;

/// Internal

    var timestampStart:Float;

    var windowWidth:Int;

    var windowHeight:Int;

    var windowDpr:Float = 1.0;

/// Lifecycle

    function new(app:Clay) {

        this.app = app;

    }

    override function init() {

        timestampStart = Timestamp.now();
        name = 'sdl';

        initSDL();
        initCwd();

    }

    override function handleReady() {

        createWindow();

        Log.debug('SDL / ready');
        
    }

    override function run():Bool {

        var done = true;

        #if (ios || tvos)

        done = false;
        Log.debug('SDL / attaching iOS CADisplayLink loop');
        SDL.iPhoneSetAnimationCallback(window, 1, loop, null);

        #else

        Log.debug('SDL / running main loop');

        while (!app.shuttingDown) {
            loop(0);
        }

        #end

        return done;

    }

    override function shutdown(immediate:Bool = false) {

        if (!immediate) {
            SDL.quit();
            Log.debug('SDL / shutdown');
        } else {
            Log.debug('SDL / shutdown immediate');
        }

    }

/// Internal

    function initSDL() {

        // Init SDL
        var status = SDL.init(SDL_INIT_TIMER);
        if (status != 0) {
            throw 'SDL / Failed to init: ${SDL.getError()}';
        }

        // Init video
        var status = SDL.initSubSystem(SDL_INIT_VIDEO);
        if (status != 0) {
            throw 'SDL / Failed to init video: ${SDL.getError()}';
        }
        else {
            Log.debug('SDL / init video');
        }

        // Init controllers
        var status = SDL.initSubSystem(SDL_INIT_GAMECONTROLLER);
        if (status == -1) {
            Log.warning('SDL / Failed to init controller: ${SDL.getError()}');
        }
        else {
            Log.debug('SDL / init controller');
        }

        // Init joystick
        var status = SDL.initSubSystem(SDL_INIT_JOYSTICK);
        if (status == -1) {
            Log.warning('SDL / Failed to init joystick: ${SDL.getError()}');
        }
        else {
            Log.debug('SDL / init joystick');
        }

        // Init haptic
        var status = SDL.initSubSystem(SDL_INIT_HAPTIC);
        if (status == -1) {
            Log.warning('SDL / Failed to init haptic: ${SDL.getError()}');
        }
        else {
            Log.debug('SDL / init haptic');
        }

        // Mobile events
        #if (android || ios || tvos)
        SDL.addEventWatch(handleSdlEventWatch, null);
        #end

        Log.success('SDL / init success');

    }

    function initCwd() {

        var appPath = app.io.appPath();

        Log.debug('Runtime / init with app path $appPath');
        if (appPath != null && appPath != '') {
            Sys.setCwd(appPath);
        }
        else {
            Log.debug('Runtime / no need to change cwd');
        }

    }

    function createWindow() {

        Log.debug('SDL / create window');

        var config = app.config;
        var windowConfig = config.window;

        applyGLAttributes(config.render);

        windowWidth = windowConfig.width;
        windowHeight = windowConfig.height;

        // Init SDL video subsystem
        var status = SDL.initSubSystem(SDL_INIT_VIDEO);
        if (status != 0) {
            throw 'SDL / failed to init video: ${SDL.getError()}';
        }
        else {
            Log.debug('SDL / init video');
        }

        #if windows
        // Get DPI info (needed on windows to adapt window size)
        var dpiInfo:Array<cpp.Float32> = [];
        SDL.getDisplayDPI(0, dpiInfo);
        var createWindowWidth:Int = Std.int(windowConfig.width * dpiInfo[1] / dpiInfo[3]);
        var createWindowHeight:Int = Std.int(windowConfig.height * dpiInfo[2] / dpiInfo[3]);
        #else
        var createWindowWidth:Int = windowConfig.width;
        var createWindowHeight:Int = windowConfig.height;
        #end

        // Create window
        window = SDL.createWindow('' + windowConfig.title, windowConfig.x, windowConfig.y, createWindowWidth, createWindowHeight, windowFlags(windowConfig));

        if (window == null) {
            throw 'SDL / failed to create window: ${SDL.getError()}';
        }

        var windowId:Int = SDL.getWindowID(window);

        Log.debug('SDL / created window with id: $windowId');
        Log.debug('SDL / creating render context...');

        if (!createRenderContext(window)) {
            throw 'SDL / failed to create render context: ${SDL.getError()}';
        }

        postRenderContext(window);

        var actualConfig = app.copyWindowConfig(windowConfig);
        var actualRender = app.copyRenderConfig(app.config.render);

        actualConfig = updateWindowConfig(window, actualConfig);
        actualRender = updateRenderConfig(window, actualRender);

    }

    function applyGLAttributes(render:RenderConfig) {

        Log.debug('SDL / GL / RBGA / ${render.redBits} ${render.greenBits} ${render.blueBits} ${render.alphaBits}');

        SDL.GL_SetAttribute(SDL_GL_RED_SIZE,     render.redBits);
        SDL.GL_SetAttribute(SDL_GL_GREEN_SIZE,   render.greenBits);
        SDL.GL_SetAttribute(SDL_GL_BLUE_SIZE,    render.blueBits);
        SDL.GL_SetAttribute(SDL_GL_ALPHA_SIZE,   render.alphaBits);
        SDL.GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

        if (render.depth > 0) {
            Log.debug('SDL / GL / depth / ${render.depth}');
            SDL.GL_SetAttribute(SDL_GL_DEPTH_SIZE, render.depth);
        }

        if (render.stencil > 0) {
            Log.debug('SDL / GL / stencil / ${render.stencil}');
            SDL.GL_SetAttribute(SDL_GL_STENCIL_SIZE, render.stencil);
        }

        if (render.antialiasing > 0) {
            Log.debug('SDL / GL / MSAA / ${render.antialiasing}');
            SDL.GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
            SDL.GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, render.antialiasing);
        }

        Log.debug('SDL / GL / profile / ${render.opengl.profile}');

        switch render.opengl.profile {

            case COMPATIBILITY:
                SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDLGLprofile.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);

            case CORE:
                SDL.GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);
                SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDLGLprofile.SDL_GL_CONTEXT_PROFILE_CORE);

            case GLES:
                SDL.GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);
                SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDLGLprofile.SDL_GL_CONTEXT_PROFILE_ES);

                if (render.opengl.major == 0) {
                    render.opengl.major = 2;
                    render.opengl.minor = 0;
                }
        }

        if (render.opengl.major != 0) {
            Log.debug('SDL / GL / version / ${render.opengl.major}.${render.opengl.minor}');
            SDL.GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, render.opengl.major);
            SDL.GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, render.opengl.minor);
        }

    }

    function windowFlags(config:WindowConfig) {

        var flags:SDLWindowFlags = 0;

        flags |= SDL_WINDOW_OPENGL;
        flags |= SDL_WINDOW_ALLOW_HIGHDPI;

        #if mac
        windowHiddenAtStartup = true;
        flags |= SDL_WINDOW_HIDDEN;
        #end

        if (config.resizable)  flags |= SDL_WINDOW_RESIZABLE;
        if (config.borderless) flags |= SDL_WINDOW_BORDERLESS;

        if (config.fullscreen) {
            if (!config.trueFullscreen) {
                flags |= SDL_WINDOW_FULLSCREEN_DESKTOP;
            } else {
                #if !mac
                flags |= SDL_WINDOW_FULLSCREEN;
                #end
            }
        }

        return flags;

    }

    function createRenderContext(window:sdl.Window):Bool {

        gl = SDL.GL_CreateContext(window);

        var success = (gl.isnull() == false);

        if (success) {
            Log.success('SDL / GL init success');
        }
        else {
            Log.error('SDL / GL init error');
        }

        return success;

    }

    function postRenderContext(window:sdl.Window) {

        SDL.GL_MakeCurrent(window, gl);

        #if clay_use_glew
        var result = GLEW.init();
        if (result != GLEW.OK) {
            throw 'SDL / failed to setup created render context: ${GLEW.error(result)}';
        } else {
            Log.debug('SDL / GLEW init / ok');
        }
        #end

        // Also clear the garbage in both front/back buffer
        #if (!clay_no_initial_glclear && linc_opengl)

        var color = app.config.render.defaultClear;

        GL.clearDepth(1.0);
        GL.clearStencil(0);
        GL.clearColor(color.r, color.g, color.b, color.a);
        GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT | GL.STENCIL_BUFFER_BIT);
        windowSwap();
        GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT | GL.STENCIL_BUFFER_BIT);

        #end

    }

    function updateWindowConfig(window:sdl.Window, config:WindowConfig):WindowConfig {

        if (config.fullscreen) {
            if (config.trueFullscreen) {
                #if mac
                SDL.setWindowFullscreen(window, SDL_WINDOW_FULLSCREEN);
                #end
            }
        }

        var size = SDL.GL_GetDrawableSize(window, { w: config.width, h: config.height });
        var pos = SDL.getWindowPosition(window, { x: config.x, y: config.y });

        config.x = pos.x;
        config.y = pos.y;
        config.width = windowWidth = size.w;
        config.height = windowHeight = size.h;

        windowDpr = windowDevicePixelRatio();
        Log.debug('SDL / window / x=${config.x} y=${config.y} w=${config.width} h=${config.height} scale=$windowDpr');

        return config;

    }

    function updateRenderConfig(window:sdl.Window, render:RenderConfig):RenderConfig {

        render.antialiasing = SDL.GL_GetAttribute(SDL_GL_MULTISAMPLESAMPLES);
        render.redBits      = SDL.GL_GetAttribute(SDL_GL_RED_SIZE);
        render.greenBits    = SDL.GL_GetAttribute(SDL_GL_GREEN_SIZE);
        render.blueBits     = SDL.GL_GetAttribute(SDL_GL_BLUE_SIZE);
        render.alphaBits    = SDL.GL_GetAttribute(SDL_GL_ALPHA_SIZE);
        render.depth        = SDL.GL_GetAttribute(SDL_GL_DEPTH_SIZE);
        render.stencil      = SDL.GL_GetAttribute(SDL_GL_STENCIL_SIZE);

        render.opengl.major = SDL.GL_GetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION);
        render.opengl.minor = SDL.GL_GetAttribute(SDL_GL_CONTEXT_MINOR_VERSION);

        var profile:SDLGLprofile = SDL.GL_GetAttribute(SDL_GL_CONTEXT_PROFILE_MASK);
        switch profile {

            case SDL_GL_CONTEXT_PROFILE_COMPATIBILITY:
               render.opengl.profile = COMPATIBILITY;

            case SDL_GL_CONTEXT_PROFILE_CORE:
               render.opengl.profile = CORE;

            case SDL_GL_CONTEXT_PROFILE_ES:
               render.opengl.profile = GLES;

        }

        return render;

    }

    static var _sdlSize:SDLSize = { w:0, h:0 };

/// Public API

    override function windowDevicePixelRatio():Float {

        _sdlSize = SDL.GL_GetDrawableSize(window, _sdlSize);
        var pixelHeight = _sdlSize.w;

        _sdlSize = SDL.getWindowSize(window, _sdlSize);
        var deviceHeight = _sdlSize.w;

        return pixelHeight / deviceHeight;

    }

    public function windowSwap() {

        SDL.GL_SwapWindow(window);

    }

    function loop(_) {

        inline function _loop() {

            while (SDL.hasAnEvent()) {

                var e = SDL.pollEvent();

                currentSdlEvent = e;

                handleInputEvent(e);
                handleWindowEvent(e);

                app.events.sdlEvent(e);

                if (e.type == SDL_QUIT) {
                    app.handleQuit();
                }

                currentSdlEvent = null;

            }

            app.handleTick();

            if (autoSwap && !app.hasShutdown) {
                windowSwap();
            }

        }
            
        if (app.config.runtime.uncaughtErrorHandler != null) {
            try {
                _loop();
            } catch (e:Dynamic) {
                app.config.runtime.uncaughtErrorHandler(e);
            }
        }
        else {
            _loop();
        }

    }

/// Helpers

    inline public static function timestamp():Float {

        return haxe.Timer.stamp();

    }

}
