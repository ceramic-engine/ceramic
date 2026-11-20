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
     * Value of `windowX` and `windowY` when the position of the window is
     * left to the system.
     */
    public static inline final WINDOW_POSITION_UNDEFINED:Int = 0x1FFF0000;

    /**
     * Horizontal position of the window (the left of its content area), in
     * the desktop coordinates of the system: points on macOS and Wayland,
     * pixels on Windows and X11 (see `screen.windowDesktopScale`). Negative
     * values are valid (a display on the left of the main one).
     * At startup, this is the requested position, the system choosing it when
     * set to `WINDOW_POSITION_UNDEFINED` (default).
     * Once the app is running, it follows the actual position of the window
     * (when the user moves it for instance) and can be changed to move the window.
     * Changing it has no effect on mobile, in a web browser, with Unity, or
     * while fullscreen. Use `screen.displayBounds()` to keep a restored
     * position inside the display.
     */
    @observe public var windowX:Int = WINDOW_POSITION_UNDEFINED;

    /**
     * Vertical position of the window (the top of its content area).
     * See `windowX`.
     */
    @observe public var windowY:Int = WINDOW_POSITION_UNDEFINED;

    /**
     * Window position. Same as assigning `windowX` and `windowY`:
     * sets the window position at startup, and moves the window once the app is running.
     * @param windowX Horizontal position of the window
     * @param windowY Vertical position of the window
     */
    inline public function windowPosition(windowX:Int, windowY:Int):Void {
        this.windowX = windowX;
        this.windowY = windowY;
    }

    /**
     * Smallest width the user can give to the window, in the same unit as
     * `windowWidth` (0, the default: no minimum). Can be set at startup and
     * changed while the app is running. Desktop native builds only.
     */
    @observe public var windowMinWidth:Int = 0;

    /**
     * Smallest height the user can give to the window, in the same unit as
     * `windowHeight` (0, the default: no minimum). Can be set at startup and
     * changed while the app is running. Desktop native builds only.
     */
    @observe public var windowMinHeight:Int = 0;

    /**
     * Minimum window width and height. Same as assigning `windowMinWidth`
     * and `windowMinHeight`.
     * @param windowMinWidth Minimum window width
     * @param windowMinHeight Minimum window height
     */
    inline public function windowMinSize(windowMinWidth:Int, windowMinHeight:Int):Void {
        this.windowMinWidth = windowMinWidth;
        this.windowMinHeight = windowMinHeight;
    }

    /**
     * Whether the window has no border and no title bar of the system
     * (default: false). Can be set at startup and changed while the app is
     * running. An app that draws its own title bar and borders gives the
     * regions that move and resize the window with `screen.setWindowHitRegions`.
     * Desktop native builds only.
     */
    @observe public var windowBorderless:Bool = false;

    /**
     * Whether a borderless window (`windowBorderless`) keeps the shadow of
     * the system around it and, from Windows 11, its rounded corners and
     * thin border, like the window of an app that draws its own title bar
     * (default: false, a bare rectangle). Read when the app starts.
     * Windows native builds only: ignored elsewhere (a borderless window of
     * macOS keeps its shadow anyway).
     */
    public var windowBorderlessShadow(default,null):Bool = false;

    /**
     * How the title bar of the window is shown (default: `DEFAULT`, the
     * title bar of the system). `OVERLAY` extends the content under a
     * transparent title bar with a hidden title, keeping the window buttons.
     * Can be set at startup and changed while the app is running.
     * macOS native builds only: ignored elsewhere.
     */
    @observe public var titleBarStyle:TitleBarStyle = TitleBarStyle.DEFAULT;

    /**
     * With `titleBarStyle` set to `OVERLAY` on macOS: distance from the left
     * edge of the window to the left of the close button, in points.
     * Negative (default): the place the system gives.
     */
    @observe public var trafficLightX:Float = -1;

    /**
     * With `titleBarStyle` set to `OVERLAY` on macOS: distance from the top
     * edge of the window to the top of the window buttons, in points.
     * Negative (default): the place the system gives.
     */
    @observe public var trafficLightY:Float = -1;

    /**
     * Position of the window buttons (close, minimize, zoom) of an `OVERLAY`
     * title bar on macOS. Same as assigning `trafficLightX` and
     * `trafficLightY`. The position is kept when the window is resized or
     * leaves fullscreen.
     * @param trafficLightX Left of the close button from the left edge of the window
     * @param trafficLightY Top of the buttons from the top edge of the window
     */
    inline public function trafficLightPosition(trafficLightX:Float, trafficLightY:Float):Void {
        this.trafficLightX = trafficLightX;
        this.trafficLightY = trafficLightY;
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
     * Verified on macOS and web. On Unity, a skipped frame is a frame Unity is asked
     * not to render (`OnDemandRendering`). Can be changed at any time.
     */
    public var renderOnDemand:Bool = false;

    /**
     * With `renderOnDemand`: whether a frame is also drawn each time app code ran
     * outside of what Ceramic can track (default `true`): a timer callback, a main
     * thread callback coming back from a thread (`Runner`), a `onceXUpdates` callback,
     * an input event (key, text, pointer, wheel, gamepad).
     *
     * This is a safety net for code that changes, from such a callback, a field that
     * raises no dirty flag (`Quad.color`, `Mesh` arrays, shader uniforms): the frame is
     * drawn anyway, so the change shows.
     *
     * Set it to `false` when everything on screen requests its own renders (an app made
     * of Glaze views does) or when the app calls `requestRender()` itself: frames where
     * such a callback ran but nothing changed are then not drawn. An editor like
     * Cityscape runs many timers and thread callbacks after each key: with the safety
     * net it draws about 7 frames per key, without it fewer than 2, and the next key
     * finds the app at rest more often.
     *
     * Window and screen events (resize, focus, display change), finished asset loads,
     * tweens and dirty visuals always request a render, whatever this setting.
     */
    public var renderAfterTimersAndInput:Bool = true;

    /**
     * With `renderOnDemand`: the most updates per second while the app is at rest or its
     * window is in the background (default `0`: no cap, the loop runs as without it).
     *
     * An app that renders on demand still updates at the rate of the display when nothing
     * is drawn (timers, `onUpdate` listeners, threads coming back). With a rate above 0
     * (10 is a good value for a desktop tool), the loop is throttled to that rate:
     * - after `idleDelay` seconds without activity, for the updates that draw nothing (a
     *   frame drawn because something changed is always followed by an update at the
     *   normal rate, so animations are never throttled);
     * - at once when the window loses the focus, for every update, until an input event
     *   comes (mouse moves over an unfocused window included) or the focus comes back;
     * - at once while the window is hidden or minimized, for every update.
     *
     * Activity is any input event (keys, text, mouse moves and buttons, wheel, touches,
     * gamepads), a window event, work posted with `Runner.runInMain` and, while the window
     * has the focus, a continuous render request (`app.requestContinuousRender()`) or an
     * active tween. The first input event after a rest is handled at once (the native loop
     * wakes on any event, a thread posting work wakes it too) and the loop goes back to the
     * normal rate. Timers are not delayed: a throttled loop wakes when the next one is due.
     * Code that polls the time in `app.onUpdate` sees updates at this rate only.
     *
     * When the window loses the focus, this replaces the native sleep made at each update
     * (`ceramic_disable_background_sleep` has no effect then). Web: animation frames are
     * skipped (no update, no draw) until the interval passed; the update made by
     * `ceramic_web_update_in_background` in a hidden page follows the same rate.
     *
     * Note: an update further apart than `maxDelta` gets `maxDelta` as its delta: keep the
     * rate at `1 / maxDelta` (10 with the default) or above, or app time runs slower than
     * real time while throttled. Can be changed at any time.
     */
    public var idleUpdateRate:Float = 0;

    /**
     * With `idleUpdateRate`: seconds at the normal rate after the last activity (default
     * `0.5`). Short enough for the app to go to rest between two blinks of a text cursor,
     * long enough to cover the pauses inside a gesture (between two keys, two moves of the
     * mouse). Can be changed at any time.
     */
    public var idleDelay:Float = 0.5;

    /**
     * Seconds after the app window stops being visible (hidden, minimized, fully covered by
     * other windows, on another space) before the app sleeps (default `-1`: never, the
     * loop runs as without it).
     *
     * While asleep, the native loop makes no update at all: it waits for an event of the
     * system without a timeout. Work posted from another thread (`Runner.runInMain`) wakes
     * it for one update, then it sleeps again. Timers and tweens are frozen: none fires
     * while asleep (a timer due during the sleep fires once the window is visible again).
     * When the window is visible again, the normal rhythm (or `idleUpdateRate`) resumes at
     * once. The first update after a sleep gets `maxDelta` as its delta, like any long
     * pause: app time (`Timer.now`) does not jump, so no burst of stale timers and no
     * animation skips to its end. `Timer.timestamp` follows the real time.
     *
     * Visibility comes from the window events of the system (`screen.windowVisible`). Works
     * with or without `renderOnDemand`. Web: no effect, the browser already stops the
     * animation frames of a hidden page (`ceramic_web_update_in_background` keeps its
     * background updates). Can be changed at any time.
     */
    public var hiddenSleepDelay:Float = -1;

    /**
     * With `renderOnDemand`: handle a discrete input event (key, text, mouse button,
     * touch down or up) at once while nothing renders continuously, instead of at the
     * next frame (default `true`).
     *
     * Web: the update and the draw of the event are run from its DOM event handler, at
     * most once per refresh period of the display, and the browser shows the result at
     * its next frame. Without it the event waits for the next animation frame (8 ms on
     * average at 60 Hz) before anything is computed. It only happens when
     * `renderOnDemand` is `true`, no owner holds `app.requestContinuousRender()`, no
     * tween is active, the last frames were not all drawn and `targetFps` is not set:
     * an app that draws every frame keeps ticking on the animation frames only, and so
     * does any app when this is `false`. Such an update gets the time really passed
     * since the last one as its delta, which can be shorter than a display period.
     *
     * Native: nothing to set, the native loop already ticks at once for a discrete
     * event while idle.
     *
     * Must be set at startup (`InitSettings`).
     */
    public var earlyTickOnInput(default,null):Bool = true;

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
     * Deliver smooth scrolling (pixel deltas: trackpads, smooth wheels, Magic Mouse) on
     * the beat of the frames when the platform dispatches it unevenly against them.
     *
     * Some platforms dispatch scroll events on a clock of their own instead of aligning
     * them with the frames: Safari on the web, and macOS for native apps (about one event
     * per frame, but out of phase). Now and then a frame receives no `mouseScroll` /
     * `mouseWheel` event and the next one receives two, so content that follows the
     * deltas stops for a frame and then jumps twice as far. When this is enabled, pixel
     * deltas are resampled at each frame from the event times, a little behind the newest
     * event (about one event interval plus the delivery delay, measured: about one frame),
     * so each frame gets an even step. The total distance stays exactly the sum of the
     * deltas. Line and page deltas (notched mouse wheels) are never changed. While the
     * events come evenly (Chromium aligns them with the frames), they go through as they
     * come and no latency is added. See `clay.WheelResampler`.
     *
     * Applies on the web and on macOS native builds; other platforms ignore it.
     *
     * Default: `true` in Safari and the other WebKit browsers of iOS (see
     * `Utils.isSafari()`), `false` elsewhere. An app can still set it either way.
     */
    @observe public var wheelResampling:Bool = Utils.isSafari();

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
     * Whether the window has a depth buffer (clay backend).
     *
     * Ceramic's 2D renderer never tests depth on the window: visuals are ordered by
     * `depth` on the CPU. Set to `false` to create the window without a depth buffer
     * and save its memory (about 4 bytes per pixel when it is packed with the stencil,
     * 19 MB for a 2560 x 1898 window). Render textures keep their own `depth` setting.
     * Native: asks the GL or EGL context for a depth size of 0. Web: WebGL context
     * attribute `depth: false`. Unity: ignored (Unity owns the camera target).
     * Read once, when the window is created.
     *
     * Default: true
     */
    public var windowDepthBuffer(default,null):Bool = true;

    /**
     * Whether the window has a stencil buffer (clay backend).
     *
     * The stencil buffer is used by `Visual.clip` when the clip is not a regular
     * rectangle (rotated, skewed or a mesh) and the clipped visual draws directly on
     * the window. Clips into a `RenderTexture` or a `Filter` use the stencil of that
     * texture instead, and regular rectangle clips use the scissor. Set to `false` to
     * create the window without a stencil buffer and save its memory: such clips then
     * draw unclipped on the window (a warning is logged once).
     * Native: asks the GL or EGL context for a stencil size of 0. Web: WebGL context
     * attribute `stencil: false`. Unity: ignored (Unity owns the camera target).
     * Read once, when the window is created.
     *
     * Default: true
     */
    public var windowStencilBuffer(default,null):Bool = true;

    // Native loop (clay backend, macOS): drawables, wait for the drawable first, frame pacing

    /**
     * Number of drawables of the Metal layer the app renders to (macOS): 2 or 3.
     *
     * macOS gives 3 by default: with vsync, a frame then waits behind two older ones
     * before it is shown. With 2 it waits behind one, so what is on screen is one frame
     * more recent. 0 leaves the layer as the system made it. Ignored on other targets,
     * iOS included: its loop is a display link callback, which two drawables slow down
     * to half the frame rate.
     *
     * Default: 2
     */
    public var maxDrawables(default,null):Int = 2;

    /**
     * Wait for the drawable at the start of the frame, before input is read, instead of in
     * the first draw call after the update (macOS, ignored elsewhere; compiled out
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
     * When true, the window is created hidden and shown right after the
     * first frame presented once the app is ready, so that the user never
     * sees an empty or half drawn window at launch.
     *
     * Only applies to desktop native builds. Hidden test windows
     * (`clay_sdl_headless`) stay hidden.
     *
     * Default: false (the window is visible as soon as it is created)
     */
    public var windowStartsHidden(default,null):Bool = false;

    /**
     * macOS native builds: whether trackpad and Magic Mouse scrolling keeps
     * its momentum after the fingers leave the surface (the scroll events
     * the system sends then, with the `MOMENTUM_*` phases of
     * `Screen.mouseScrollPhase`), like other macOS apps. When false, a
     * scroll stops when the fingers leave.
     *
     * An init setting: it applies when the app launches (SDL reads it once,
     * when it starts) and cannot change afterwards. Other platforms ignore
     * it (browsers and the other systems apply their own momentum, or none).
     *
     * Default: true
     */
    public var scrollMomentum(default,null):Bool = true;

    /**
     * Whether audio is initialized. When false, the app runs without
     * audio: native builds create no audio device and no audio thread
     * (SoLoud and SDL audio are not started), the web creates no audio
     * context. Audio calls stay safe and do nothing: sounds load as empty
     * placeholders (duration 0), `play` returns a player that plays
     * nothing, filters are ignored, and the first such call logs a
     * warning that audio is disabled.
     *
     * An init setting: it applies when the app launches and cannot change
     * afterwards. The headless and Unity backends ignore it.
     *
     * Default: true
     */
    public var audio(default,null):Bool = true;

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
