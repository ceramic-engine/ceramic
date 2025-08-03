package backend;

#if (ios || tvos || android)
import haxe.atomic.AtomicBool;
#end

#if clay_sdl
import clay.sdl.SDL;
#end

#if clay_sdl
@:headerCode('#include "linc_sdl.h"')
#end
@:allow(backend.Main)
@:allow(backend.Textures)
@:allow(backend.ClayEvents)
/**
 * Clay backend implementation for Ceramic framework.
 *
 * The Clay backend is the main native rendering backend that provides cross-platform
 * support for desktop (Windows, Mac, Linux) and mobile (iOS, Android) targets.
 * It uses SDL for windowing/input and OpenGL/ANGLE for rendering.
 *
 * This class implements the Ceramic backend specification and serves as the main
 * entry point for all backend services including rendering, audio, input, and
 * platform-specific functionality.
 */
class Backend implements tracker.Events implements spec.Backend {

/// Public API

    /**
     * File I/O operations backend service.
     * Handles reading/writing files and persistent key-value storage.
     */
    public var io(default,null) = new backend.IO();

    /**
     * Platform information backend service.
     * Provides system information like platform type, version, etc.
     */
    public var info(default,null) = new backend.Info();

    /**
     * Audio backend service.
     * Handles sound loading, playback, and audio filters.
     */
    public var audio(default,null) = new backend.Audio();

    /**
     * Rendering backend service.
     * Handles OpenGL/WebGL drawing operations, shaders, and render targets.
     */
    public var draw(default,null) = new backend.Draw();

    /**
     * Text loading backend service.
     * Handles loading and processing of text files.
     */
    public var texts(default,null) = new backend.Texts();

    /**
     * Binary data loading backend service.
     * Handles loading and processing of binary files.
     */
    public var binaries(default,null) = new backend.Binaries();

    /**
     * Texture management backend service.
     * Handles loading, creating, and managing OpenGL textures.
     */
    public var textures(default,null) = new backend.Textures();

    /**
     * Shader management backend service.
     * Handles loading, compiling, and managing OpenGL shaders.
     */
    public var shaders(default,null) = new backend.Shaders();

    /**
     * Screen/display backend service.
     * Handles window management, fullscreen, resolution, and display properties.
     */
    public var screen(default,null) = new backend.Screen();

    #if plugin_http
    /**
     * HTTP networking backend service.
     * Handles HTTP requests and responses (when http plugin is enabled).
     */
    public var http(default,null) = new backend.Http();
    #end

    /**
     * Input handling backend service.
     * Handles keyboard, mouse, touch, and gamepad input events.
     */
    public var input(default,null) = new backend.Input();

    /**
     * Text input backend service.
     * Handles on-screen keyboards and text input controls.
     */
    public var textInput(default,null) = new backend.TextInput();

    /**
     * Clipboard backend service.
     * Handles system clipboard operations for cut/copy/paste functionality.
     */
    public var clipboard(default,null) = new backend.Clipboard();

    /**
     * Creates a new Clay backend instance.
     * All backend services are automatically instantiated.
     */
    public function new() {}

    /**
     * Initializes the Clay backend with the given Ceramic application.
     *
     * This method performs platform-specific initialization including:
     * - SDL binding (on SDL-enabled platforms)
     * - Disabling momentum scrolling on macOS
     * - Platform-specific native initialization
     *
     * @param app The Ceramic application instance to initialize with
     */
    public function init(app:ceramic.App) {

        #if clay_sdl
        SDL.bind();
        #end

        #if mac
        NativeMac.setAppleMomentumScrollSupported(false);
        #end

        #if windows
        NativeWindows.init();
        #end

        #if android
        NativeAndroid.init();
        #end

    }

    /**
     * Sets the target framerate for the application.
     *
     * Controls the application update rate and minimum frame time:
     * - Updates Clay's update rate configuration
     * - Sets minimum frame time to 75% of target frame time on desktop platforms
     * - Use 0 or negative FPS to disable frame rate limiting
     *
     * @param fps Target frames per second (0 or negative to disable limiting)
     */
    public function setTargetFps(fps:Int):Void {

        clay.Clay.app.config.updateRate = fps > 0 ? 1.0 / fps : 0;

        #if (mac || windows || linux)
        clay.Clay.app.runtime.minFrameTime = fps > 0 ? (1.0 / fps) * 0.75 : 0.005;
        #end

    }

/// Events

    /**
     * Fired when the backend is ready and fully initialized.
     * This event is emitted after all backend services are set up.
     */
    @event function ready();

    /**
     * Fired every frame during the update phase.
     *
     * @param delta Time elapsed since the last update in seconds
     */
    @event function update(delta:Float);

    /**
     * Fired every frame during the render phase.
     * This event is emitted after the update phase is complete.
     */
    @event function render();

#if clay_sdl
    /**
     * Fired when an SDL event is received (SDL platforms only).
     * Provides direct access to low-level SDL events for advanced use cases.
     *
     * @param event The SDL event data
     */
    @event function sdlEvent(event:SDLEvent);
#end

/// Internal flags

#if (ios || tvos || android)
    /**
     * Thread-safe flag indicating if the mobile app is currently in background.
     * Used to prevent GPU operations when the app is backgrounded on mobile platforms.
     */
    var mobileInBackground:AtomicBool = new AtomicBool(false);
#end

}
