package clay;

import clay.Config;

/**
 * Clay app
 */
class Clay {

/// Properties

    /**
     * Get Clay instance from anywhere with `Clay.app`
     */
    public static var app(default, null):Clay;

    /**
     * Clay config
     */
    public var config(default, null):Config;

    /**
     * Clay events handler
     */
    public var events(default, null):Events;

    /**
     * Clay io
     * (implementation varies depending on the target)
     */
    public var io(default, null):IO;

    /**
     * Clay runtime
     * (implementation varies depending on the target)
     */
    public var runtime(default, null):Runtime;

    /** `true` if shut down has begun */
    public var shuttingDown:Bool = false;

    /** `true` if shut down has completed  */
    public var hasShutdown:Bool = false;

    public var immediateShutdown:Bool = false;

    /** Whether or not we are frozen, ignoring events i.e backgrounded/paused */
    public var freeze(default, set):Bool = false;
    function set_freeze(freeze:Bool):Bool {
        this.freeze = freeze;
        if (freeze) {
            events.freeze();
        }
        else {
            events.unfreeze();
        }
        return freeze;
    }

    /** Whether or not the ready state has been reached */
    public var ready(default, null):Bool = false;

/// Lifecycle

    /**
     * Create a new Clay app
     * @param config Configuration to setup Clay app
     * @param events Events handler to get feedback from Clay
     */
    function new(configure:(config:Config)->Void, events:Events) {

        Clay.app = this;

        this.config = defaultConfig();
        configure(this.config);

        this.events = events;

        @:privateAccess io = new IO();
        Immediate.flush();

        @:privateAccess runtime = new Runtime(this);
        Immediate.flush();

        init();

    }

    function init() {

        Log.debug('Clay / init');

        io.init();
        Immediate.flush();

        runtime.init();
        Immediate.flush();

        Log.debug('Clay / ready');
        runtime.handleReady();
        Immediate.flush();

        var shouldExit = runtime.run();
        if (shouldExit && !(hasShutdown || shuttingDown)) {
            shutdown();
        }

    }

    function shutdown() {

        if (shuttingDown) {
            Log.debug('Clay / shutdown() called again, already shutting down - ignoring');
            return;
        }
        
        if (hasShutdown == false) {
            throw 'Clay / calling shutdown() more than once is disallowed';
        }

        shuttingDown = true;

        runtime.shutdown(immediateShutdown);

        hasShutdown = true;

    }

/// Internal events

    function handleQuit():Void {

        shutdown();

    }

    function handleTick():Void {

        if (freeze)
            return;

        #if clay_native
        if (windowInBackground && config.window.backgroundSleep != 0) {
            Sys.sleep(config.window.backgroundSleep);
        }
        #end

        Immediate.flush();

        if (!shuttingDown && ready) {
            events.tick();
        }

    }

/// Internal

    var windowInBackground = false;

    function defaultConfig():Config {

        return {
            runtime: null,
            window: defaultWindowConfig(),
            render: defaultRenderConfig()
        };

    }

    function defaultWindowConfig():WindowConfig {

        var window:WindowConfig = {
            trueFullscreen: false,
            fullscreen: false,
            borderless: false,
            resizable: true,
            x: 0x1FFF0000,
            y: 0x1FFF0000,
            width: 960,
            height: 640,
            title: 'clay app',
            noInput: false,
            backgroundSleep: 1/15
        };

        #if (ios || android)
        window.fullscreen = true;
        window.borderless = true;
        #end

        return window;
        
    }

    function defaultRenderConfig():RenderConfig {

        return {
            depth: 0,
            stencil: 0,
            antialiasing: 0,
            redBits: 8,
            greenBits: 8,
            blueBits: 8,
            alphaBits: 8,
            defaultClear: { r:0, g:0, b:0, a:1 },
            #if clay_sdl
            opengl: {
            #if (ios || android)
                major: 2, minor: 0,
                profile: OpenGLProfile.GLES
            #else
                major: 0, minor: 0,
                profile: OpenGLProfile.COMPATIBILITY
            #end
            },
            #elseif clay_web
            webgl: {
                version: 1
            }
            #end
        };
        
    }

    @:noCompletion public function copyWindowConfig(config:WindowConfig):WindowConfig {

        return {
            fullscreen: config.fullscreen,
            trueFullscreen: config.trueFullscreen,
            resizable: config.resizable,
            borderless: config.borderless,
            x: config.x,
            y: config.y,
            width: config.width,
            height: config.height,
            title: '' + config.title,
            noInput: config.noInput,
            backgroundSleep: config.backgroundSleep
        };

    }

    @:noCompletion public function copyRenderConfig(config:RenderConfig):RenderConfig {

        return {
            depth: config.depth,
            stencil: config.stencil,
            antialiasing: config.antialiasing,
            redBits: config.redBits,
            greenBits: config.greenBits,
            blueBits: config.blueBits,
            alphaBits: config.alphaBits,
            defaultClear: { 
                r: config.defaultClear.r,
                g: config.defaultClear.g,
                b: config.defaultClear.b,
                a: config.defaultClear.a
            },
            #if clay_sdl
            opengl: {
                major: config.opengl.major,
                minor: config.opengl.minor,
                profile: config.opengl.profile
            }
            #elseif clay_web
            webgl: {
                version: config.webgl.version
            }
            #end
        }

    }

}
