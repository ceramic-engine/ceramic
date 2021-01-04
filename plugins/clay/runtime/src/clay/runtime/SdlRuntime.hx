package clay.runtime;

import sdl.SDL;
import timestamp.Timestamp;

#if clay_use_glew
import glew.GLEW;
#end

/**
 * Native runtime, using SDL to operate
 */
class SdlRuntime extends BaseRuntime {

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

/// Internal

    var timestampStart:Float;

/// Lifecycle

    function new() {}

    override function init() {

        timestampStart = Timestamp.now();
        name = 'sdl';

        initSDL();
        initCwd();

    }

    override function handleReady() {

        createWindow();
        
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

        var appPath = Clay.app.io.appPath();

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

        var config = Clay.app.config.window;

        // TODO

    }

/// Helpers

    inline public static function timestamp():Float {

        return haxe.Timer.stamp();

    }

}
