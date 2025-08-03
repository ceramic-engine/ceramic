package backend;

// Import needed to make reflection work as expected
import backend.FieldLookup;

using ceramic.Extensions;

#if !no_backend_docs
/**
 * Unity-specific implementation of the Ceramic backend interface.
 * 
 * This class serves as the central hub for all Unity platform functionality,
 * providing implementations for rendering, audio, input, file I/O, and more.
 * It implements the spec.Backend interface to ensure compatibility with the
 * Ceramic framework while leveraging Unity's native capabilities.
 * 
 * The backend is responsible for:
 * - Managing subsystem instances (audio, draw, textures, etc.)
 * - Handling the main application lifecycle (init, update, render)
 * - Processing Unity-specific events and callbacks
 * - Providing platform-specific optimizations
 * 
 * Each subsystem is lazily initialized and provides Unity-specific implementations:
 * - `io`: File I/O using Unity's Application.persistentDataPath
 * - `audio`: Unity AudioSource and AudioMixer integration
 * - `draw`: Optimized mesh rendering with command buffers
 * - `textures`: Texture2D management with format conversions
 * - `screen`: Unity window and display management
 * - `input`: Unity Input System integration
 * 
 * @see spec.Backend The interface this class implements
 * @see Main The Unity MonoBehaviour that drives this backend
 */
#end
@:allow(Main)
@:allow(backend.Textures)
class Backend implements tracker.Events implements spec.Backend {

/// Public API

    #if !no_backend_docs
    /**
     * File I/O operations using Unity's persistent data path.
     * Handles save data and configuration files.
     */
    #end
    public var io(default,null) = new backend.IO();

    #if !no_backend_docs
    /**
     * Platform and system information provider.
     * Reports Unity-specific capabilities and metadata.
     */
    #end
    public var info(default,null) = new backend.Info();

    #if !no_backend_docs
    /**
     * Audio playback and mixing system.
     * Integrates with Unity's AudioSource and AudioMixer.
     */
    #end
    public var audio(default,null) = new backend.Audio();

    #if !no_backend_docs
    /**
     * Optimized 2D rendering system.
     * Uses Unity command buffers and mesh batching.
     */
    #end
    public var draw(default,null) = new backend.Draw();

    #if !no_backend_docs
    /**
     * Text file loading from Resources and StreamingAssets.
     */
    #end
    public var texts(default,null) = new backend.Texts();

    #if !no_backend_docs
    /**
     * Binary file loading from Resources and StreamingAssets.
     */
    #end
    public var binaries(default,null) = new backend.Binaries();

    #if !no_backend_docs
    /**
     * Texture loading and management.
     * Handles Texture2D creation and format conversions.
     */
    #end
    public var textures(default,null) = new backend.Textures();

    #if !no_backend_docs
    /**
     * Shader compilation and management.
     * Supports custom shaders via Unity's shader system.
     */
    #end
    public var shaders(default,null) = new backend.Shaders();

    #if !no_backend_docs
    /**
     * Window and display management.
     * Handles Unity's screen settings and events.
     */
    #end
    public var screen(default,null) = new backend.Screen();

    #if plugin_http
    #if !no_backend_docs
    /**
     * HTTP networking operations.
     * Uses UnityWebRequest for cross-platform support.
     */
    #end
    public var http(default,null) = new backend.Http();
    #end

    #if !no_backend_docs
    /**
     * Keyboard and gamepad input handling.
     * Integrates with Unity's Input System.
     */
    #end
    public var input(default, null) = new backend.Input();

    #if !no_backend_docs
    /**
     * Text input field management.
     * Handles IME and virtual keyboard support.
     */
    #end
    public var textInput(default,null) = new backend.TextInput();

    #if !no_backend_docs
    /**
     * System clipboard operations.
     * Provides copy/paste functionality.
     */
    #end
    public var clipboard(default,null) = new backend.Clipboard();

    #if !no_backend_docs
    /**
     * Creates a new Unity backend instance.
     * Subsystems are created immediately but not fully initialized.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Initializes the backend with the Ceramic application.
     * Ensures reflection data is preserved for dynamic field access.
     * 
     * @param app The main Ceramic application instance
     */
    #end
    public function init(app:ceramic.App) {

        FieldLookup.keep();

    }

    #if !no_backend_docs
    /**
     * Sets Unity's target frame rate.
     * 
     * @param fps Target frames per second (0 or negative for vsync)
     */
    #end
    public function setTargetFps(fps:Int):Void {

        unityengine.Application.targetFrameRate = fps > 0 ? fps : -1;

    }

/// Events

    #if !no_backend_docs
    /**
     * Fired when the backend is fully initialized and ready.
     * All subsystems are available after this event.
     */
    #end
    @event function ready();

    #if !no_backend_docs
    /**
     * Fired every frame with the time elapsed since last update.
     * This is where game logic and physics updates occur.
     * 
     * @param delta Time in seconds since the last update
     */
    #end
    @event function update(delta:Float);

    #if !no_backend_docs
    /**
     * Fired when it's time to render the current frame.
     * Drawing commands should be issued during this event.
     */
    #end
    @event function render();

/// Internal update logic

    #if !no_backend_docs
    /**
     * Called before emitting the update event.
     * Processes any callbacks scheduled for the next update.
     * 
     * @param delta Time since last update
     */
    #end
    inline function willEmitUpdate(delta:Float) {

        flushNextUpdateCallbacks();

    }

    #if !no_backend_docs
    /**
     * Called after emitting the update event.
     * Currently unused but available for post-update processing.
     * 
     * @param delta Time since last update
     */
    #end
    inline function didEmitUpdate(delta:Float) {

        //

    }

    #if !no_backend_docs
    /**
     * Callbacks scheduled to run on the next update.
     */
    #end
    var _nextUpdateCallbacks:Array<Void->Void> = [];
    
    #if !no_backend_docs
    /**
     * Temporary array used during callback iteration to avoid issues
     * if callbacks modify the main array.
     */
    #end
    var _nextUpdateCallbacksIterate:Array<Void->Void> = [];

    #if !no_backend_docs
    /**
     * Schedules a callback to run once on the next update.
     * Useful for deferring operations that need to happen after the current frame.
     * 
     * @param cb The callback to execute on next update
     */
    #end
    function onceNextUpdate(cb:Void->Void):Void {

        _nextUpdateCallbacks.push(cb);

    }

    #if !no_backend_docs
    /**
     * Executes all callbacks scheduled for the next update.
     * Uses a temporary array to safely iterate even if callbacks
     * schedule new callbacks during execution.
     */
    #end
    function flushNextUpdateCallbacks():Void {

        var len = _nextUpdateCallbacks.length;
        for (i in 0...len) {
            _nextUpdateCallbacksIterate[i] = _nextUpdateCallbacks.unsafeGet(i);
        }
        _nextUpdateCallbacks.setArrayLength(0);
        for (i in 0...len) {
            var cb = _nextUpdateCallbacksIterate.unsafeGet(i);
            _nextUpdateCallbacksIterate.unsafeSet(i, null);
            cb();
        }

    }

}
