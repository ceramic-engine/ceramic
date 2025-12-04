package ceramic;

import tracker.Observable;

/**
 * Central configuration hub for Ceramic applications.
 *
 * Settings provides both compile-time and runtime configuration options that control
 * various aspects of your application, from window properties to rendering behavior.
 * Many settings are observable, allowing the app to react to changes dynamically.
 *
 * Settings are typically configured during app initialization but many can be
 * modified at runtime to adjust behavior on the fly.
 *
 * Key configuration areas:
 * - **Display**: Window size, fullscreen, scaling modes
 * - **Performance**: Target FPS, delta time handling
 * - **Rendering**: Background color, antialiasing, shaders
 * - **Assets**: Default assets, asset paths
 * - **Input**: Touch and mouse wheel behavior
 *
 * Example usage:
 * ```haxe
 * // Configure display
 * settings.targetWidth = 1280;
 * settings.targetHeight = 720;
 * settings.scaling = FIT;
 *
 * // Set performance options
 * settings.targetFps = 60;
 * settings.maxDelta = 0.1;
 *
 * // Configure rendering
 * settings.background = Color.GRAY;
 * settings.antialiasing = 4;
 * ```
 *
 * @see App#settings
 * @see ScreenScaling
 * @see Screen
 */
class Settings implements Observable {

    @:allow(ceramic.App)
    private function new() {}

    /**
     * Target width. Affects window size at startup (unless `windowWidth` is specified)
     * and affects screen scaling at any time.
     * Ignored if set to 0 (default)
     */
    @observe public var targetWidth:Int = 0;

    /**
     * Target height. Affects window size at startup (unless `windowHeight` is specified)
     * and affects screen scaling at any time.
     * Ignored if set to 0 (default)
     */
    @observe public var targetHeight:Int = 0;

    /**
     * Target width and height. Affects window size at startup
     * and affects screen scaling at any time.
     * Ignored if set to 0 (default)
     * @param targetWidth Target width
     * @param targetHeight Target height
     */
    inline public function targetSize(targetWidth:Int, targetHeight:Int):Void {
        this.targetWidth = targetWidth;
        this.targetHeight = targetHeight;
    }

    /**
     * Target window width at startup
     * Uses `targetWidth` as fallback if set to 0 (default)
     */
    #if ceramic_4k_window
    @observe public var windowWidth(default,null):Int = 3840;
    #elseif ceramic_hd_window
    @observe public var windowWidth(default,null):Int = 1920;
    #else
    @observe public var windowWidth(default,null):Int = 0;
    #end

    /**
     * Target window height at startup
     * Uses `targetHeight` as fallback if set to 0 (default)
     */
    #if ceramic_4k_window
    @observe public var windowHeight(default,null):Int = 2160;
    #elseif ceramic_hd_window
    @observe public var windowHeight(default,null):Int = 1080;
    #else
    @observe public var windowHeight(default,null):Int = 0;
    #end

    /**
     * Target density. Affects the quality of textures
     * being loaded. Changing it at runtime will update
     * texture quality if needed.
     * Ignored if set to 0 (default)
     */
    @observe public var targetDensity:Int = 0;

    /**
     * Background color.
     */
    @observe public var background:Color = Color.BLACK;

    /**
     * Screen scaling (FIT, FILL, RESIZE or FIT_RESIZE).
     */
    @observe public var scaling:ScreenScaling = FIT;

    /**
     * App window title.
     */
    @observe public var title:String = 'App';

    /**
     * Fullscreen enabled or not.
     */
    @observe public var fullscreen:Bool = false;

    /**
     * Target frames per second for the application.
     *
     * Controls the desired frame rate:
     * - Values < 1: Use platform default (usually 60 FPS)
     * - Values >= 1: Attempt to match the specified FPS
     *
     * Note: Actual FPS may vary based on device performance and vsync settings.
     * Higher values may increase CPU/GPU usage.
     */
    @observe public var targetFps:Int = -1;

    /**
     * Maximum delta time per frame to prevent large time jumps.
     *
     * Caps the time step between frames to prevent issues when the app
     * is paused/resumed or experiences frame drops. This helps maintain
     * stable physics, animations, and game logic.
     *
     * When actual frame time exceeds maxDelta:
     * - `app.delta` is capped to this value
     * - `app.realDelta` contains the actual elapsed time
     *
     * Default: 0.1 seconds (100ms)
     */
    @observe public var maxDelta:Float = 0.1;

    /**
     * Forces a fixed delta time for all updates, ignoring actual frame timing.
     *
     * When set to a positive value, all time-based operations (animations,
     * physics, timers) will use this fixed time step instead of real elapsed time.
     *
     * Use cases:
     * - Deterministic simulations
     * - Replay systems
     * - Debug/testing with consistent timing
     *
     * Values:
     * - < 0: Disabled, use actual frame time (default)
     * - > 0: Fixed time step in seconds
     *
     * **Warning**: This affects all time-based systems. Use with caution.
     */
    @observe public var overrideDelta:Float = -1;

    /**
     * Controls whether mouse wheel events are consumed by the app.
     *
     * When true (default), prevents mouse wheel events from bubbling to
     * the browser, stopping page scrolling when the app has focus.
     * This is especially important for apps embedded in iframes or
     * scrollable web pages.
     *
     * Set to false if you want wheel events to scroll the parent page.
     *
     * Can be overridden at compile time with `-D ceramic_allow_default_mouse_wheel`
     */
    @observe public var preventDefaultMouseWheel:Bool = #if ceramic_allow_default_mouse_wheel false #else true #end;

    /**
     * Controls whether touch events are consumed by the app.
     *
     * When true (default), prevents touch events from triggering browser
     * behaviors like scrolling, zooming, or text selection. Essential for
     * touch-based games and apps to function properly on mobile devices.
     *
     * Set to false if you need touch events to trigger default browser
     * behaviors (rare).
     *
     * Can be overridden at compile time with `-D ceramic_allow_default_mouse_wheel`
     */
    @observe public var preventDefaultTouches:Bool = #if ceramic_allow_default_mouse_wheel false #else true #end;

    /**
     * Supported screen orientations for mobile devices.
     *
     * Controls which orientations the app supports on mobile platforms.
     * Multiple orientations can be combined using bitwise OR.
     *
     * Desktop platforms typically ignore this setting.
     *
     * Default: NONE (use platform defaults)
     *
     * @see ScreenOrientation
     */
    public var orientation(default,null):ScreenOrientation = NONE;

    /**
     * Factory function for creating app-wide collections.
     *
     * When set, this function is called to create collection instances
     * that can be accessed throughout the application. Collections provide
     * organized storage for game entities, assets, or other data.
     *
     * Typically set during app initialization.
     */
    public var collections(default,null):Void->AutoCollections = null;

    /**
     * Dynamic application metadata.
     *
     * Can store arbitrary application information, particularly useful
     * when the app is loaded dynamically or needs to pass configuration
     * from a loader or parent application.
     *
     * The structure is application-specific.
     */
    public var appInfo(default,null):Dynamic = null;

    /**
     * Multisample antialiasing (MSAA) level.
     *
     * Reduces jagged edges on rendered graphics:
     * - 0: Disabled (best performance)
     * - 2: 2x MSAA (light smoothing)
     * - 4: 4x MSAA (good quality/performance balance)
     * - 8: 8x MSAA (high quality, more GPU intensive)
     *
     * Higher values provide smoother edges but impact performance.
     * Support varies by platform and GPU.
     */
    public var antialiasing(default,null):Int = 0;

    /**
     * Controls whether the application window can be resized by the user.
     *
     * Only applies to desktop platforms. When true, users can drag
     * window edges/corners to resize. The app should handle resize
     * events appropriately.
     *
     * Mobile and web platforms ignore this setting.
     *
     * Default: false (fixed window size)
     */
    public var resizable(default,null):Bool = false;

    /**
     * Root directory path for loading assets.
     *
     * All asset loading is relative to this path. Can be:
     * - Relative path: 'assets' (default)
     * - Absolute path: '/usr/share/myapp/assets'
     * - URL: 'https://cdn.example.com/assets' (web platform)
     *
     * Change this to load assets from custom locations.
     */
    public var assetsPath(default,null):String = 'assets';

    /**
     * Platform-specific backend configuration.
     *
     * Allows passing custom settings to the underlying backend (Clay, Web, Unity).
     * The structure and available options depend on the current backend.
     *
     * Examples might include:
     * - OpenGL context settings
     * - Platform-specific window flags
     * - Audio backend configuration
     *
     * Consult backend documentation for available options.
     */
    public var backend(default,null):Dynamic = {};

    /**
     * Default font asset used for text rendering.
     *
     * This font is used when creating Text visuals without specifying
     * a font. The font must be available in the assets directory.
     *
     * Format: 'font:FontName' where FontName matches a font asset file.
     *
     * Default: 'font:RobotoMedium' (Roboto Medium font)
     */
    public var defaultFont(default,null):AssetId<String> = 'font:RobotoMedium';

    /**
     * Default shader program for rendering.
     *
     * Used for all visuals that don't explicitly specify a shader.
     * The shader must support basic textured quad rendering with
     * color tinting and alpha blending.
     *
     * Format: 'shader:ShaderName' where ShaderName matches a shader asset.
     *
     * Default: 'shader:textured' (standard textured shader)
     */
    public var defaultShader(default,null):AssetId<String> = 'shader:textured';

}
