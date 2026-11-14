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
     * Window width.
     * At startup, this is the requested window width, using `targetWidth`
     * as fallback if set to 0 (default).
     * Once the app is running, it follows the actual width of the window
     * (when the user resizes it for instance) and can be changed to resize the window.
     * Changing it has no effect on mobile, in a regular web browser, or while fullscreen
     * (in that last case, the new size is applied when leaving fullscreen).
     */
    #if ceramic_4k_window
    @observe public var windowWidth:Int = 3840;
    #elseif ceramic_hd_window
    @observe public var windowWidth:Int = 1920;
    #else
    @observe public var windowWidth:Int = 0;
    #end

    /**
     * Window height.
     * At startup, this is the requested window height, using `targetHeight`
     * as fallback if set to 0 (default).
     * Once the app is running, it follows the actual height of the window
     * (when the user resizes it for instance) and can be changed to resize the window.
     * Changing it has no effect on mobile, in a regular web browser, or while fullscreen
     * (in that last case, the new size is applied when leaving fullscreen).
     */
    #if ceramic_4k_window
    @observe public var windowHeight:Int = 2160;
    #elseif ceramic_hd_window
    @observe public var windowHeight:Int = 1080;
    #else
    @observe public var windowHeight:Int = 0;
    #end

    /**
     * Window width and height. Same as assigning `windowWidth` and `windowHeight`:
     * sets the window size at startup, and resizes the window once the app is running.
     * @param windowWidth Window width
     * @param windowHeight Window height
     */
    inline public function windowSize(windowWidth:Int, windowHeight:Int):Void {
        this.windowWidth = windowWidth;
        this.windowHeight = windowHeight;
    }

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
     * Mouse cursor shown or hidden while over the app.
     */
    @observe public var cursorVisible:Bool = true;

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
     * Render on demand: a frame is drawn only when something asked for it.
     *
     * When `false` (default), every frame is drawn, as always. When `true`, the app
     * still updates at every frame, but a frame where nothing requested a render is
     * not drawn and not presented: the screen keeps the last image. This lowers the
     * latency of the next drawn frame and the power used at rest.
     *
     * A render is requested automatically by:
     * - a visual added or removed, or any visual change that raises a dirty flag
     *   (position, scale, rotation, alpha, visibility, depth, content of a `Text`
     *   or any visual with `contentDirty`, render target, clip);
     * - the setters of `Visual.width` / `height`, `Visual.blending`, `Visual.shader`,
     *   `Quad.texture`, `Mesh.texture` and `Mesh.color`;
     * - an active `Tween`;
     * - every input event (keys, text, pointer, wheel, gamepad);
     * - any frame where a `Timer` callback, a callback given to `Runner.runInMain()` or
     *   an `app.onceXUpdates()` callback ran;
     * - the end of an asset load;
     * - every window or screen event (resize, density, expose, restore, display change,
     *   focus, system appearance) and a change of `settings.background`;
     * - a `RenderTexture` marked with `renderDirty = true`, `stamp()`, `Filter.render()`;
     * - a listener waiting in `app.onceBeginDraw()` / `app.onceFinishDraw()` (used by
     *   screenshots, pixel reads, `stamp()` and `Filter.render()`). A permanent
     *   listener (`app.onBeginDraw()` / `app.onFinishDraw()`) requests nothing: it is
     *   called on drawn frames only.
     *
     * What is NOT detected (plain fields, without a dirty flag) when changed outside of
     * the cases above, for instance at every frame from `app.onUpdate`:
     * - `Quad.color`, `Quad.frameX` / `frameY`;
     * - the arrays of a `Mesh` (`vertices`, `indices`, `colors`, `uvs`);
     * - shader uniforms;
     * - a `RenderTexture` with `autoRender` whose content must change by itself, and
     *   the pixels of a texture.
     *
     * In those cases, call `app.requestRender()` after the change, or hold
     * `app.requestContinuousRender(owner)` while the animation runs.
     *
     * In debug, the define `ceramic_verify_render_on_demand` checks the skipped frames:
     * when a visual changed without a request, a warning names it and the frame is
     * drawn. The check does not see the content of a custom `Renderable`, shader
     * uniforms or texture pixels.
     *
     * Verified on macOS and web. Ignored by the Unity backend (every frame is drawn
     * there). Can be changed at any time.
     */
    public var renderOnDemand:Bool = false;

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
     * Web only: deliver smooth scrolling on the beat of the frames when the browser
     * dispatches it unevenly.
     *
     * Some browsers (Safari) dispatch wheel events on a clock of their own instead of
     * aligning them with the animation frames: a frame now and then receives no
     * `mouseScroll` / `mouseWheel` event and the next one receives two, so content that
     * follows the deltas stops for a frame and then jumps twice as far. When this is
     * enabled, pixel deltas (trackpads, smooth wheels) of such browsers are resampled at
     * each frame from the event times, a little behind the newest event (about one event
     * interval plus the delivery delay of the browser, measured: about one frame), so each
     * frame gets an even step. The total distance stays exactly the sum of the deltas.
     * Line and page deltas (notched mouse wheels) are never changed. While the browser
     * delivers wheel input aligned with the frames (Chromium), events go through as they
     * come and no latency is added. See `clay.WheelResampler`.
     *
     * Default: `true` in Safari and the other WebKit browsers of iOS (see
     * `Utils.isSafari()`), whose wheel events have this issue, `false` elsewhere.
     * An app can still set it either way.
     */
    @observe public var webWheelResampling:Bool = Utils.isSafari();

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

    // Native loop (clay backend, macOS and iOS): drawables, wait for the drawable first, frame pacing

    /**
     * Number of drawables of the Metal layer the app renders to (macOS and iOS): 2 or 3.
     *
     * macOS gives 3 by default: with vsync, a frame then waits behind two older ones
     * before it is shown. With 2 it waits behind one, so what is on screen is one frame
     * more recent. 0 leaves the layer as the system made it. Ignored on other targets.
     *
     * Default: 2
     */
    public var maxDrawables(default,null):Int = 2;

    /**
     * Wait for the drawable at the start of the frame, before input is read, instead of in
     * the first draw call after the update (macOS and iOS, ignored elsewhere; compiled out
     * with `ceramic_no_clay_wait_drawable_first`). What is drawn is then one vsync more recent.
     *
     * A frame that starts when the drawable is there has `period - framePacingFloor` for its
     * work (12.7 ms at 60 Hz with the default floor). This is the deadline used by the
     * `waitDrawableFirst*` settings below: when frames take longer, waiting first would cost
     * a whole period per frame, so the loop stops waiting first while frames are slow.
     *
     * Default: true
     */
    public var waitDrawableFirst(default,null):Bool = true;

    /**
     * Number of frames in a row whose work exceeds the deadline (`period - framePacingFloor`)
     * after which the loop stops waiting for the drawable first. One isolated long frame
     * (a GC pause, a loading step) changes nothing.
     *
     * Unit: frames. Default: 3
     */
    public var waitDrawableFirstSlowFrames(default,null):Int = 3;

    /**
     * Number of frames in a row whose work is within the deadline (`period - framePacingFloor`)
     * after which the loop waits for the drawable first again. A slow frame restarts the count.
     *
     * Against flapping, this number doubles each time waiting first is stopped again less
     * than a second after it resumed (up to `waitDrawableFirstBackoffCap`), and halves after
     * each 5 seconds without a stop.
     *
     * Unit: frames. Default: 8
     */
    public var waitDrawableFirstFastFrames(default,null):Int = 8;

    /**
     * Longest run of fast frames needed to wait for the drawable first again, once doubled
     * by the backoff of `waitDrawableFirstFastFrames`.
     *
     * Unit: seconds of frames (2.0 is 120 frames at 60 Hz, 240 at 120 Hz). Default: 2.0
     */
    public var waitDrawableFirstBackoffCap(default,null):Float = 2.0;

    /**
     * Margin frame pacing (macOS, where the loop waits for the drawable first; ignored elsewhere).
     *
     * Once the drawable is there (a vsync), the loop sleeps until `next vsync - margin` before
     * it reads input, so the input shown is as recent as possible, with
     * `margin = framePacingFloor + framePacingMultiple x worst recent work`.
     * It engages only when that margin fits in the period, and stops by itself when frames
     * miss their vsync. Not used when `targetFps` is set.
     *
     * Default: true
     */
    public var framePacing(default,null):Bool = true;

    /**
     * Fixed part of the frame pacing margin: the lead the system compositor needs before a
     * vsync, plus what is not measured (GPU time after the submit, wake up jitter).
     * It also defines the deadline of a frame, `period - framePacingFloor`, used by
     * `waitDrawableFirst`.
     *
     * Unit: seconds. Default: 0.004
     */
    public var framePacingFloor(default,null):Float = 0.004;

    /**
     * The worst recent work time of a frame is multiplied by this in the frame pacing margin.
     * Pacing engages only when `framePacingFloor + framePacingMultiple x worst work <= period`:
     * with the defaults at 60 Hz, up to 6.3 ms of work per frame. It applies to pacing only,
     * not to `waitDrawableFirst`.
     *
     * Default: 2.0
     */
    public var framePacingMultiple(default,null):Float = 2.0;

    /**
     * Largest number of frames over which the worst work time is taken for the frame pacing
     * margin. A frame over the deadline counts as one full period: pacing stays off while
     * such a frame is in the window. The window used starts at `framePacingMinWindow` and
     * doubles, up to this, each time pacing fails less than a second after it engaged again.
     *
     * Unit: frames, not time (120 is 2 seconds at 60 Hz, 1 second at 120 Hz). Default: 120
     */
    public var framePacingWindow(default,null):Int = 120;

    /**
     * Smallest number of frames over which the worst work time is taken for the frame pacing
     * margin: after a long frame (a GC pause, a loading step), pacing is tried again this
     * many frames later, plus the 5 consistent vsync signals it needs to lock. The window
     * halves back towards this after each 5 seconds without a frame over the deadline or a
     * paced frame that missed its vsync.
     *
     * Unit: frames. Default: 8
     */
    public var framePacingMinWindow(default,null):Int = 8;

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
    public var defaultShader(default,null):Class<shade.Shader> = shaders.Textured;

}
