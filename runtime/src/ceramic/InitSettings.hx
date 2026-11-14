package ceramic;

/**
 * Same as Settings, but for app startup (inside Project.new(settings)).
 * Read-only values can still be edited at that stage.
 *
 * InitSettings provides write access to all application settings during
 * the initialization phase. This includes settings that are normally
 * read-only after startup, such as window dimensions, antialiasing,
 * and backend configuration.
 *
 * This class wraps the Settings instance and provides setters for
 * properties that are immutable after initialization. It's only
 * available in the Project constructor.
 *
 * Example usage:
 * ```haxe
 * class Project extends App {
 *     function new(settings:InitSettings) {
 *         settings.targetWidth = 1920;
 *         settings.targetHeight = 1080;
 *         settings.windowWidth = 1280;
 *         settings.windowHeight = 720;
 *         settings.antialiasing = 4;
 *         settings.title = "My Game";
 *
 *         super();
 *     }
 * }
 * ```
 *
 * @see Settings
 * @see App
 */
class InitSettings {

    /**
     * App settings
     */
    private var settings:Settings;

    @:allow(ceramic.App)
    private function new(settings:Settings) {

        this.settings = settings;

    }

    /**
     * Target width. Affects window size at startup
     * and affects screen scaling at any time.
     * Ignored if set to 0 (default)
     */
    public var targetWidth(get,set):Int;
    inline function get_targetWidth():Int {
        return settings.targetWidth;
    }
    inline function set_targetWidth(targetWidth:Int):Int {
        return settings.targetWidth = targetWidth;
    }

    /**
     * Target height. Affects window size at startup
     * and affects screen scaling at any time.
     * Ignored if set to 0 (default)
     */
    public var targetHeight(get,set):Int;
    inline function get_targetHeight():Int {
        return settings.targetHeight;
    }
    inline function set_targetHeight(targetHeight:Int):Int {
        return settings.targetHeight = targetHeight;
    }

    /**
     * Target width and height. Affects window size at startup
     * and affects screen scaling at any time.
     * Ignored if set to 0 (default)
     * @param targetWidth Target width
     * @param targetHeight Target height
     */
    inline public function targetSize(targetWidth:Int, targetHeight:Int):Void {
        settings.targetWidth = targetWidth;
        settings.targetHeight = targetHeight;
    }

    /**
     * Target window width at startup
     * Uses `targetWidth` as fallback if set to 0 (default)
     */
    public var windowWidth(get,set):Int;
    inline function get_windowWidth():Int {
        return settings.windowWidth;
    }
    inline function set_windowWidth(windowWidth:Int):Int {
        return settings.windowWidth = windowWidth;
    }

    /**
     * Target window height at startup
     * Uses `targetHeight` as fallback if set to 0 (default)
     */
    public var windowHeight(get,set):Int;
    inline function get_windowHeight():Int {
        return settings.windowHeight;
    }
    inline function set_windowHeight(windowHeight:Int):Int {
        return settings.windowHeight = windowHeight;
    }

    /**
     * Target window width and height at startup
     * Uses `targetWidth` and `targetHeight` as fallback if set to 0 (default)
     * @param windowWidth Window width
     * @param windowHeight Window height
     */
    inline public function windowSize(windowWidth:Int, windowHeight:Int):Void {
        settings.windowSize(windowWidth, windowHeight);
    }

    /**
     * Target density. Affects the quality of textures
     * being loaded. Changing it at runtime will update
     * texture quality if needed.
     * Ignored if set to 0 (default)
     */
    public var targetDensity(get,set):Int;
    inline function get_targetDensity():Int {
        return settings.targetDensity;
    }
    inline function set_targetDensity(targetDensity:Int):Int {
        return settings.targetDensity = targetDensity;
    }

    /**
     * Background color.
     */
    public var background(get,set):Color;
    inline function get_background():Color {
        return settings.background;
    }
    inline function set_background(background:Color):Color {
        return settings.background = background;
    }

    /**
     * Screen scaling (FIT, FILL, RESIZE, FIT_RESIZE).
     */
    public var scaling(get,set):ScreenScaling;
    inline function get_scaling():ScreenScaling {
        return settings.scaling;
    }
    inline function set_scaling(scaling:ScreenScaling):ScreenScaling {
        return settings.scaling = scaling;
    }

    /**
     * App window title.
     */
    public var title(get,set):String;
    inline function get_title():String {
        return settings.title;
    }
    inline function set_title(title:String):String {
        return settings.title = title;
    }

    /**
     * Fullscreen enabled or not.
     */
    public var fullscreen(get,set):Bool;
    inline function get_fullscreen():Bool {
        return settings.fullscreen;
    }
    inline function set_fullscreen(fullscreen:Bool):Bool {
        return settings.fullscreen = fullscreen;
    }

    /**
     * Mouse cursor shown or hidden while over the app.
     */
    public var cursorVisible(get,set):Bool;
    inline function get_cursorVisible():Bool {
        return settings.cursorVisible;
    }
    inline function set_cursorVisible(cursorVisible:Bool):Bool {
        return settings.cursorVisible = cursorVisible;
    }

    /**
     * Target FPS. Using default FPS if value < 1 or try to match the given value if >= 1.
     */
    public var targetFps(get,set):Int;
    inline function get_targetFps():Int {
        return settings.targetFps;
    }
    inline function set_targetFps(targetFps:Int):Int {
        return settings.targetFps = targetFps;
    }

    /**
     * Maximum app update delta time.
     * During app update (at each frame), `app.delta` will be capped to `maxDelta`
     * if its value is above `maxDelta`.
     * If needed, use `app.realDelta` to get real elapsed time since last frame.
     */
    public var maxDelta(get,set):Float;
    inline function get_maxDelta():Float {
        return settings.maxDelta;
    }
    inline function set_maxDelta(maxDelta:Float):Float {
        return settings.maxDelta = maxDelta;
    }

    /**
     * Override app update delta time.
     * This can be used to ignore completely the actual elapsed time between frames
     * and replace it with an explicit delta time of your choice.
     * This will affect timers, tween, systems update etc...
     * Use with caution.
     */
    public var overrideDelta(get,set):Float;
    inline function get_overrideDelta():Float {
        return settings.overrideDelta;
    }
    inline function set_overrideDelta(overrideDelta:Float):Float {
        return settings.overrideDelta = overrideDelta;
    }

    /**
     * Render on demand (default `false`): when `true`, a frame is drawn only when
     * something requested it. See `Settings.renderOnDemand`.
     */
    public var renderOnDemand(get,set):Bool;
    inline function get_renderOnDemand():Bool {
        return settings.renderOnDemand;
    }
    inline function set_renderOnDemand(renderOnDemand:Bool):Bool {
        return settings.renderOnDemand = renderOnDemand;
    }

    /**
     * With `renderOnDemand`: draw a frame each time a timer, a main thread callback or
     * an input event ran app code (default `true`). See `Settings.renderOnDemandCallbacks`.
     */
    public var renderOnDemandCallbacks(get,set):Bool;
    inline function get_renderOnDemandCallbacks():Bool {
        return settings.renderOnDemandCallbacks;
    }
    inline function set_renderOnDemandCallbacks(renderOnDemandCallbacks:Bool):Bool {
        return settings.renderOnDemandCallbacks = renderOnDemandCallbacks;
    }


    /**
     * If set to `true` (default). Default mouse wheel events
     * will be prevented. This is relevant when running the ceramic
     * app from an `iframe` inside a page that can scroll.
     */
    public var preventDefaultMouseWheel(get,set):Bool;
    inline function get_preventDefaultMouseWheel():Bool {
        return settings.preventDefaultMouseWheel;
    }
    inline function set_preventDefaultMouseWheel(preventDefaultMouseWheel:Bool):Bool {
        return settings.preventDefaultMouseWheel = preventDefaultMouseWheel;
    }

    /**
     * Web only: deliver smooth scrolling on the beat of the frames when the browser
     * dispatches it unevenly (Safari). See `Settings.webWheelResampling`.
     */
    public var webWheelResampling(get,set):Bool;
    inline function get_webWheelResampling():Bool {
        return settings.webWheelResampling;
    }
    inline function set_webWheelResampling(webWheelResampling:Bool):Bool {
        return settings.webWheelResampling = webWheelResampling;
    }

    /**
     * If set to `true` (default). Default touch events
     * will be prevented. This is relevant when running the ceramic
     * app from an `iframe` inside a page that can scroll,
     * on a touchscreen device.
     */
    public var preventDefaultTouches(get,set):Bool;
    inline function get_preventDefaultTouches():Bool {
        return settings.preventDefaultTouches;
    }
    inline function set_preventDefaultTouches(preventDefaultTouches:Bool):Bool {
        return settings.preventDefaultTouches = preventDefaultTouches;
    }

    /**
     * Setup screen orientation. Default is `NONE`,
     * meaning nothing is enforced and project defaults will be used.
     */
    public var orientation(get,set):ScreenOrientation;
    inline function get_orientation():ScreenOrientation {
        return settings.orientation;
    }
    inline function set_orientation(orientation:ScreenOrientation):ScreenOrientation {
        return @:privateAccess settings.orientation = orientation;
    }

    /**
     * Antialiasing value (0 means disabled).
     */
    public var antialiasing(get,set):Int;
    inline function get_antialiasing():Int {
        return settings.antialiasing;
    }
    inline function set_antialiasing(antialiasing:Int):Int {
        return @:privateAccess settings.antialiasing = antialiasing;
    }

    // Native loop (clay backend, macOS): drawables, wait for the drawable first, frame pacing

    /**
     * Number of drawables of the Metal layer the app renders to (macOS): 2 or 3, 0 to leave it alone. Default: 2. See `Settings.maxDrawables`.
     */
    public var maxDrawables(get,set):Int;
    inline function get_maxDrawables():Int {
        return settings.maxDrawables;
    }
    inline function set_maxDrawables(maxDrawables:Int):Int {
        return @:privateAccess settings.maxDrawables = maxDrawables;
    }

    /**
     * Wait for the drawable at the start of the frame, before input is read (macOS). Default: true. See `Settings.waitDrawableFirst`.
     */
    public var waitDrawableFirst(get,set):Bool;
    inline function get_waitDrawableFirst():Bool {
        return settings.waitDrawableFirst;
    }
    inline function set_waitDrawableFirst(waitDrawableFirst:Bool):Bool {
        return @:privateAccess settings.waitDrawableFirst = waitDrawableFirst;
    }

    /**
     * Slow frames in a row that stop the wait for the drawable first. Unit: frames. Default: 3. See `Settings.waitDrawableFirstSlowFrames`.
     */
    public var waitDrawableFirstSlowFrames(get,set):Int;
    inline function get_waitDrawableFirstSlowFrames():Int {
        return settings.waitDrawableFirstSlowFrames;
    }
    inline function set_waitDrawableFirstSlowFrames(waitDrawableFirstSlowFrames:Int):Int {
        return @:privateAccess settings.waitDrawableFirstSlowFrames = waitDrawableFirstSlowFrames;
    }

    /**
     * Fast frames in a row that resume the wait for the drawable first. Unit: frames. Default: 8. See `Settings.waitDrawableFirstFastFrames`.
     */
    public var waitDrawableFirstFastFrames(get,set):Int;
    inline function get_waitDrawableFirstFastFrames():Int {
        return settings.waitDrawableFirstFastFrames;
    }
    inline function set_waitDrawableFirstFastFrames(waitDrawableFirstFastFrames:Int):Int {
        return @:privateAccess settings.waitDrawableFirstFastFrames = waitDrawableFirstFastFrames;
    }

    /**
     * Longest run of fast frames needed to resume the wait for the drawable first. Unit: seconds. Default: 2.0. See `Settings.waitDrawableFirstBackoffCap`.
     */
    public var waitDrawableFirstBackoffCap(get,set):Float;
    inline function get_waitDrawableFirstBackoffCap():Float {
        return settings.waitDrawableFirstBackoffCap;
    }
    inline function set_waitDrawableFirstBackoffCap(waitDrawableFirstBackoffCap:Float):Float {
        return @:privateAccess settings.waitDrawableFirstBackoffCap = waitDrawableFirstBackoffCap;
    }

    /**
     * Margin frame pacing (macOS). Default: true. See `Settings.framePacing`.
     */
    public var framePacing(get,set):Bool;
    inline function get_framePacing():Bool {
        return settings.framePacing;
    }
    inline function set_framePacing(framePacing:Bool):Bool {
        return @:privateAccess settings.framePacing = framePacing;
    }

    /**
     * Fixed part of the frame pacing margin. Unit: seconds. Default: 0.004. See `Settings.framePacingFloor`.
     */
    public var framePacingFloor(get,set):Float;
    inline function get_framePacingFloor():Float {
        return settings.framePacingFloor;
    }
    inline function set_framePacingFloor(framePacingFloor:Float):Float {
        return @:privateAccess settings.framePacingFloor = framePacingFloor;
    }

    /**
     * Multiple of the worst recent work in the frame pacing margin. Default: 2.0. See `Settings.framePacingMultiple`.
     */
    public var framePacingMultiple(get,set):Float;
    inline function get_framePacingMultiple():Float {
        return settings.framePacingMultiple;
    }
    inline function set_framePacingMultiple(framePacingMultiple:Float):Float {
        return @:privateAccess settings.framePacingMultiple = framePacingMultiple;
    }

    /**
     * Largest number of frames over which the worst work is taken for the frame pacing margin. Unit: frames. Default: 120. See `Settings.framePacingWindow`.
     */
    public var framePacingWindow(get,set):Int;
    inline function get_framePacingWindow():Int {
        return settings.framePacingWindow;
    }
    inline function set_framePacingWindow(framePacingWindow:Int):Int {
        return @:privateAccess settings.framePacingWindow = framePacingWindow;
    }

    /**
     * Smallest number of frames over which the worst work is taken for the frame pacing margin. Unit: frames. Default: 8. See `Settings.framePacingMinWindow`.
     */
    public var framePacingMinWindow(get,set):Int;
    inline function get_framePacingMinWindow():Int {
        return settings.framePacingMinWindow;
    }
    inline function set_framePacingMinWindow(framePacingMinWindow:Int):Int {
        return @:privateAccess settings.framePacingMinWindow = framePacingMinWindow;
    }

    /**
     * App collections.
     */
    public var collections(get,set):Void->AutoCollections;
    inline function get_collections():Void->AutoCollections {
        return settings.collections;
    }
    inline function set_collections(collections:Void->AutoCollections):Void->AutoCollections {
        return @:privateAccess settings.collections = collections;
    }

    /**
     * App info (useful when dynamically loaded, not needed otherwise).
     */
    public var appInfo(get,set):Dynamic;
    inline function get_appInfo():Dynamic {
        return settings.appInfo;
    }
    inline function set_appInfo(appInfo:Dynamic):Dynamic {
        return @:privateAccess settings.appInfo = appInfo;
    }

    /**
     * Whether the window can be resized or not.
     */
    public var resizable(get,set):Bool;
    inline function get_resizable():Bool {
        return settings.resizable;
    }
    inline function set_resizable(resizable:Bool):Bool {
        return @:privateAccess settings.resizable = resizable;
    }

    /**
     * Assets path.
     */
    public var assetsPath(get,set):String;
    inline function get_assetsPath():String {
        return settings.assetsPath;
    }
    inline function set_assetsPath(assetsPath:String):String {
        return @:privateAccess settings.assetsPath = assetsPath;
    }

    /**
     * Settings passed to backend.
     */
    public var backend(get,set):Dynamic;
    inline function get_backend():Dynamic {
        return settings.backend;
    }
    inline function set_backend(backend:Dynamic):Dynamic {
        return @:privateAccess settings.backend = backend;
    }

    /**
     * Default font asset
     */
    public var defaultFont(get,set):AssetId<String>;
    inline function get_defaultFont():AssetId<String> {
        return settings.defaultFont;
    }
    inline function set_defaultFont(defaultFont:AssetId<String>):AssetId<String> {
        return @:privateAccess settings.defaultFont = defaultFont;
    }

    /**
     * Default shader asset
     */
    public var defaultShader(get,set):Class<shade.Shader>;
    inline function get_defaultShader():Class<shade.Shader> {
        return settings.defaultShader;
    }
    inline function set_defaultShader(defaultShader:Class<shade.Shader>):Class<shade.Shader> {
        return @:privateAccess settings.defaultShader = defaultShader;
    }

}
