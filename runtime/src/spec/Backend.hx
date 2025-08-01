package spec;

/**
 * Main backend interface that provides access to all platform-specific functionality.
 * 
 * This is the central contract that all backend implementations (Clay, Unity, Headless, Web)
 * must fulfill to run Ceramic applications. Each backend provides concrete implementations
 * of the various subsystem interfaces (audio, graphics, input, etc.).
 * 
 * The backend is initialized early in the application lifecycle and provides the bridge
 * between Ceramic's platform-agnostic code and the underlying platform APIs.
 */
interface Backend {

    /**
     * Initializes the backend with the main application instance.
     * This is called once during application startup, before any other backend methods.
     * The backend should set up platform-specific systems and prepare for operation.
     * @param app The main Ceramic application instance
     */
    function init(app:ceramic.App):Void;

    /**
     * Sets the target frame rate for the application.
     * The backend should attempt to maintain this frame rate, though actual FPS
     * may vary based on system performance and vsync settings.
     * @param fps The target frames per second (typically 30, 60, or 120)
     */
    function setTargetFps(fps:Int):Void;

    /**
     * File system and asset loading operations.
     * Handles reading/writing files and loading assets from various sources.
     */
    var io(default,null):backend.IO;

    /**
     * System and platform information.
     * Provides details about the runtime environment, platform capabilities, and system state.
     */
    var info(default,null):backend.Info;

    /**
     * Audio playback and processing system.
     * Manages sound loading, playback, effects, and bus routing.
     */
    var audio(default,null):backend.Audio;

    /**
     * Graphics rendering system.
     * Handles all drawing operations, shader management, and GPU communication.
     */
    var draw(default,null):backend.Draw;

    /**
     * Text rendering and font management.
     * Provides text measurement, rendering, and font handling capabilities.
     */
    var texts(default,null):backend.Texts;

    /**
     * Binary data loading and management.
     * Handles loading raw binary files and data buffers.
     */
    var binaries(default,null):backend.Binaries;

    /**
     * Texture loading and management.
     * Handles image loading, texture creation, and GPU texture operations.
     */
    var textures(default,null):backend.Textures;

    /**
     * Screen and window management.
     * Controls display properties, window state, and screen-related events.
     */
    var screen(default,null):backend.Screen;

    #if plugin_http
    /**
     * HTTP networking operations (optional plugin).
     * Provides HTTP request/response functionality when the http plugin is enabled.
     */
    var http(default,null):backend.Http;
    #end

    /**
     * Text input and IME (Input Method Editor) support.
     * Handles keyboard text entry, virtual keyboards, and international input methods.
     */
    var textInput(default,null):backend.TextInput;

    /**
     * System clipboard operations.
     * Provides copy/paste functionality for text and data.
     */
    var clipboard(default,null):backend.Clipboard;

}