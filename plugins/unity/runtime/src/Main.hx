package;

import ceramic.Path;
import unityengine.AudioMixer;
import unityengine.MonoBehaviour;

/**
 * Main entry point for the Unity backend integration.
 * Handles initialization, update loop, and synchronization with Unity's lifecycle.
 * Supports both standard Unity and Universal Render Pipeline (URP) configurations.
 */
class Main {

    /**
     * The Ceramic project instance.
     */
    public static var project:Project = null;

    /**
     * Timestamp of the last update, used for delta time calculation.
     */
    static var _lastUpdateTime:Float = 0;

    /**
     * Timestamp of the last regular update (URP only).
     * Used for input and screen updates in render pipeline.
     */
    #if unity_urp
    static var _lastRegularUpdateTime:Float = 0;

    /**
     * Whether the URP render pass ran since the last regular update.
     */
    static var _renderPassRan:Bool = false;

    /**
     * Number of consecutive regular updates without any URP render pass.
     */
    static var _framesWithoutRenderPass:Int = 0;

    /**
     * Whether the app runs in batch mode (`-batchmode`), read once.
     */
    static var _isBatchMode:Bool = untyped __cs__('UnityEngine.Application.isBatchMode');

    /**
     * Batch mode with a graphics device: whether the main camera is rendered
     * explicitly every frame (it does not render by itself in batch mode).
     */
    static var _batchExplicitRender:Bool = false;

    /**
     * Batch mode: whether rendering the main camera explicitly was tried
     * and ran no render pass (then the app is updated without rendering).
     */
    static var _batchRenderFailed:Bool = false;
    #end

    /**
     * Flag indicating if a critical error has occurred.
     * Prevents further updates when true.
     */
    static var _hasCriticalError:Bool = false;

    /**
     * Unity MonoBehaviour instance for coroutines and Unity API access.
     */
    public static var monoBehaviour:MonoBehaviour = null;

    /**
     * Unity AudioMixer for global audio processing.
     */
    public static var audioMixer:AudioMixer = null;

    /**
     * Synchronizes with Unity components and initializes Ceramic if needed.
     * Called from Unity's C# side to establish the connection.
     * @param monoBehaviour Unity MonoBehaviour for lifecycle hooks
     * @param audioMixer Unity AudioMixer for audio processing
     */
    @:keep public static function sync(monoBehaviour:MonoBehaviour, audioMixer:AudioMixer):Void {

        Main.monoBehaviour = monoBehaviour;
        Main.audioMixer = audioMixer;

        if (ceramic.App.app == null || ceramic.App.app.backend == null) {
            main();
        }

    }

    /**
     * Main initialization function for the Ceramic Unity backend.
     * Sets up project settings, initializes the app, and starts the update loop.
     */
    @:keep public static function main():Void {

        // Force to sync app fps with screen fps
        var isEditor:Bool = untyped __cs__('UnityEngine.Application.isEditor');
        untyped __cs__('UnityEngine.QualitySettings.vSyncCount = 1');

        // Ceramic textures are sampled with plain bilinear (or nearest)
        // filtering, like on its other backends. Unity's quality levels can
        // force anisotropic filtering on every texture (`Forced On`, the
        // setting of the High and Ultra levels of the default project), which
        // changes the samples of scaled sprites and text: keep it per texture
        // (Ceramic textures leave it off)
        untyped __cs__('if (UnityEngine.QualitySettings.anisotropicFiltering == UnityEngine.AnisotropicFiltering.ForceEnable) UnityEngine.QualitySettings.anisotropicFiltering = UnityEngine.AnisotropicFiltering.Enable');

        var settings = ceramic.App.init();
        if (isEditor) {
            settings.targetFps = 60;
        }
        project = @:privateAccess new Project(settings);
        ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..'])); // Fix this TODO

        // Init last update time
        _lastUpdateTime = Sys.cpuTime();

        // Emit ready event
        ceramic.App.app.backend.emitReady();

    }

    #if unity_urp

    /**
     * Regular update for Universal Render Pipeline.
     * Handles screen and input updates separately from rendering.
     */
    @:keep public static function regularUpdate() {

        if (_hasCriticalError)
            return;

        var time:Float = Sys.cpuTime();
        var delta = (time - _lastRegularUpdateTime);
        _lastRegularUpdateTime = time;

        ceramic.App.app.backend.screen.update();
        ceramic.App.app.backend.input.update(delta);

        // Batch frame driver: in batch mode (`-batchmode`, with or without
        // `-nographics`) no camera may render, so the URP render pass that
        // updates and renders the app never runs. With a graphics device, the
        // main camera renders into an offscreen target of the screen size
        // (screenshots read it), explicitly when it does not render by
        // itself. Without one (or when even that runs no render pass), after
        // two frames without a render pass, update the app from here and drop
        // the draw commands that no render pass will consume.
        if (_isBatchMode) {
            var screen = ceramic.App.app.backend.screen;
            // The previous frame is rendered: take the screenshots it asked for
            screen.flushBatchScreenshots();
            var hasTarget = screen.updateBatchTarget();
            if (_batchExplicitRender && hasTarget) {
                _renderPassRan = false;
                screen.renderBatchTarget();
                if (!_renderPassRan) {
                    updateWithoutRenderPass();
                }
                _renderPassRan = false;
                return;
            }
            if (_renderPassRan) {
                _framesWithoutRenderPass = 0;
            }
            else {
                _framesWithoutRenderPass++;
            }
            _renderPassRan = false;
            if (_framesWithoutRenderPass >= 2) {
                if (hasTarget && !_batchRenderFailed) {
                    screen.renderBatchTarget();
                    if (_renderPassRan) {
                        _batchExplicitRender = true;
                        _renderPassRan = false;
                        return;
                    }
                    _batchRenderFailed = true;
                    ceramic.Shortcuts.log.warning('Batch mode: rendering the main camera ran no render pass, the app updates without rendering');
                }
                updateWithoutRenderPass();
            }
        }

    }

    /**
     * Batch mode without any render pass: updates the app and drops the draw
     * commands that no render pass will consume.
     */
    static function updateWithoutRenderPass():Void {

        update();
        if (ceramic.App.app.backend.draw != null) {
            ceramic.App.app.backend.draw.discardPendingCommandBuffers();
        }

    }

    /**
     * Render pass update for Universal Render Pipeline.
     * Called during the render pass to update and render the app.
     */
    @:keep public static function renderPassUpdate() {

        if (_hasCriticalError)
            return;

        _renderPassRan = true;
        update();

    }

    #end

    /**
     * Main update loop for the Ceramic app.
     * Processes input, updates app state, and triggers rendering.
     * Includes error handling to mark critical errors.
     */
    @:keep public static function update() {

        if (_hasCriticalError)
            return;

        #if !ceramic_no_unity_catch_exit
        try {
        #end

            var time:Float = Sys.cpuTime();
            var delta = (time - _lastUpdateTime);
            _lastUpdateTime = time;

            #if !unity_urp
            ceramic.App.app.backend.screen.update();
            ceramic.App.app.backend.input.update(delta);
            #end

            // Update
            ceramic.App.app.backend.emitUpdate(delta);
            ceramic.App.app.backend.emitRender();

        #if !ceramic_no_unity_catch_exit
        }
        catch (e:Dynamic) {

            markCriticalError();
            untyped __cs__('throw');

        }
        #end

    }

    /**
     * Checks if a critical error has occurred.
     * @return True if the app has encountered a critical error
     */
    @:noCompletion public static function hasCriticalError():Bool {

        return _hasCriticalError;

    }

    /**
     * Marks that a critical error has occurred.
     * This will prevent further updates from running.
     */
    @:noCompletion public static function markCriticalError():Void {

        _hasCriticalError = true;

    }

}
