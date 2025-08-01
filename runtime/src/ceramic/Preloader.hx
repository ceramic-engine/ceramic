package ceramic;

import ceramic.Assert.assert;
import ceramic.Shortcuts.*;

/**
 * A scene that displays loading progress for preloadable resources.
 * 
 * The Preloader scene provides a visual loading screen with:
 * - An animated Ceramic logo
 * - A progress bar showing loading progress
 * - Automatic transition to the loaded scene on completion
 * 
 * This is typically used as the initial scene when loading game assets
 * or other resources that implement the Preloadable interface.
 * 
 * Example usage:
 * ```haxe
 * // Create a preloader for your main scene
 * var preloader = new Preloader(() -> {
 *     return new MainScene();
 * });
 * 
 * // The preloader will:
 * // 1. Display the Ceramic logo with animation
 * // 2. Initialize the preloadable (MainScene)
 * // 3. Show a progress bar
 * // 4. Automatically transition to MainScene when loaded
 * 
 * app.scenes.main = preloader;
 * ```
 * 
 * @see Preloadable
 * @see PreloadStatus
 */
class Preloader extends Scene {

    /**
     * Event emitted when the preloadable has successfully finished loading.
     * The preloader will automatically transition to the loaded scene after this event.
     */
    @event function success();

    /**
     * The preloadable object being loaded.
     * This is set automatically when the preloader initializes.
     */
    public var preloadable(default, null):Preloadable = null;

    /**
     * Current loading progress value (0 to total).
     */
    public var progress(default, null):Int = 0;

    /**
     * Total expected progress value.
     * Progress percentage can be calculated as: progress / total * 100
     */
    public var total(default, null):Int = 0;

    /**
     * Current loading status.
     * @see PreloadStatus
     */
    public var preloadStatus(default, null):PreloadStatus = NONE;

    /**
     * The Ceramic logo visual displayed during loading.
     * This is created automatically but can be accessed for customization.
     */
    public var ceramicLogo(default, null):CeramicLogo = null;

    /**
     * The foreground (filled) portion of the progress bar.
     * Its width is updated to reflect loading progress.
     */
    public var progressForeground(default, null):Quad = null;

    /**
     * The background (empty) portion of the progress bar.
     */
    public var progressBackground(default, null):Quad = null;

    var getPreloadable:()->Preloadable = null;

    // Just used internally to wrap `updatePreload()`
    // in a `Dynamic` once and avoid doing it at each call.
    var _updatePreload:(progress:Int, total:Int, status:PreloadStatus)->Void = null;

    var didCallUpdatePreload:Bool = false;

    var preloaderIndex:Int = -1;

    var didSucceed:Bool = false;

    static var _nextIndex:Int = 1;

    /**
     * Create a new preloader.
     * 
     * @param getPreloadable A function that returns the preloadable object to load.
     *                       This function is called after the logo animation completes.
     *                       The returned object must implement the Preloadable interface.
     */
    public function new(getPreloadable:()->Preloadable) {

        super();

        transparent = false;
        color = 0x000000;
        preloaderIndex = _nextIndex++;

        _updatePreload = (progress:Int, total:Int, status:PreloadStatus) -> {
            updatePreload(progress, total, status);
            didCallUpdatePreload = true;
        };
        this.getPreloadable = getPreloadable;

    }

    /**
     * Called when the scene is created.
     * Initializes the loading screen graphics.
     */
    override function create():Void {

        createGraphics();

    }

    /**
     * Create the loading screen graphics.
     * Override this method to customize the loading screen appearance.
     */
    function createGraphics():Void {

        createCeramicLogo();

    }

    /**
     * Create and animate the Ceramic logo.
     * The logo is centered horizontally and positioned at 42% of screen height.
     * After the animation completes, the preloadable is initialized and the progress bar is created.
     */
    function createCeramicLogo():Void {

        if (ceramicLogo != null)
            return;

        ceramicLogo = new CeramicLogo();
        ceramicLogo.pos(width * 0.5, height * 0.42);
        ceramicLogo.anchor(0.5, 0.5);
        add(ceramicLogo);

        final targetScale = Math.min(width * 0.2 / ceramicLogo.width, height * 0.2 / ceramicLogo.height);
        animateScale(ceramicLogo, targetScale, () -> {
            initPreloadable();
            createProgressBar();
        });

    }

    /**
     * Animate a visual's scale and alpha with an elastic ease effect.
     * 
     * @param visual The visual to animate
     * @param targetScale The final scale value
     * @param complete Optional callback when animation completes
     */
    function animateScale(visual:Visual, targetScale:Float, ?complete:()->Void) {

        visual.alpha = 0;
        visual.scale(targetScale * 0.0001);

        final t = visual.tween(ELASTIC_EASE_IN_OUT, 0.75, 0.0001, 1.0, (value, time) -> {
            visual.alpha = value;
            visual.scale(targetScale * value);
        });

        if (complete != null) {
            t.onceComplete(this, complete);
        }

    }

    /**
     * Create a progress bar that will be updated from current progress
     * @param yRatio The vertical position of the progress bar, relative to screen height (from `0` (top) to `1` (bottom))
     * @param widthRatio The progress bar width, relative to screen width (`1` meaning full width, `0.5` half width)
     * @param backgroundColor The progress bar background color
     * @param foregroundColor The progress bar foreground color
     */
    function createProgressBar(yRatio:Float = -1, widthRatio:Float = -1, backgroundColor:Color = 0x444444, foregroundColor:Color = 0xFFFFFF):Void {

        if (progressForeground != null)
            return;

        if (yRatio == -1) {
            if (height > 0 && ceramicLogo != null) {
                // Default value based on Ceramic Logo dimensions
                final targetScale = Math.min(width * 0.2 / ceramicLogo.width, height * 0.2 / ceramicLogo.height);
                yRatio = (ceramicLogo.y + ceramicLogo.height * (1 - ceramicLogo.anchorY) * (targetScale + 0.5)) / height;
            }
            else {
                yRatio = 0.55;
            }
        }

        if (widthRatio == -1) {
            if (width > 0 && ceramicLogo != null) {
                // Default value based on Ceramic Logo dimensions
                final targetScale = Math.min(width * 0.2 / ceramicLogo.width, height * 0.2 / ceramicLogo.height);
                widthRatio = Math.min(0.4, (ceramicLogo.width * targetScale * 2.5) / width);
            }
            else {
                widthRatio = 0.4;
            }
        }

        final progressWidth = width * widthRatio;
        final progressHeight = Math.max(2, Math.round(height * 0.006));

        progressBackground = new Quad();
        progressBackground.color = backgroundColor;
        progressBackground.depth = 1;
        progressBackground.roundTranslation = 1;
        progressBackground.anchor(0, 0.5);
        progressBackground.size(progressWidth, progressHeight);
        progressBackground.pos(
            (width - progressWidth) * 0.5,
            height * yRatio
        );
        add(progressBackground);

        progressForeground = new Quad();
        progressForeground.color = foregroundColor;
        progressForeground.depth = 2;
        progressForeground.roundTranslation = 1;
        progressForeground.anchor(0, 0.5);
        progressForeground.size(0, progressHeight);
        progressForeground.pos(
            progressBackground.x, progressBackground.y
        );
        add(progressForeground);

        updateProgressBar();

    }

    /**
     * Update the progress bar visual to reflect current loading progress.
     * The foreground width is scaled proportionally to the progress/total ratio.
     */
    function updateProgressBar():Void {

        if (progressForeground == null)
            return;

        if (total >= 1) {
            if (progress > total)
                progress = total;
            progressForeground.width = progressBackground.width * (progress * 1.0 / total);
        }

    }

    /**
     * Initialize the preloadable object.
     * If the preloadable is a Scene, it's registered with the scene manager.
     */
    function initPreloadable():Void {

        if (getPreloadable == null)
            return;

        preloadable = getPreloadable();
        getPreloadable = null;

        if (preloadable != null && preloadable is Scene) {
            final preloadableScene:Scene = cast preloadable;
            app.scenes.set('preload#$preloaderIndex', preloadableScene);
        }

    }

    /**
     * Update method called every frame.
     * Requests progress updates from the preloadable object.
     * 
     * @param delta Time elapsed since last frame in seconds
     */
    override function update(delta:Float):Void {

        if (preloadable != null) {
            didCallUpdatePreload = false;
            preloadable.requestPreloadUpdate(_updatePreload);
            assert(didCallUpdatePreload, 'Preloader\'s updatePreload() method hasn\'t been called when Preloadable\'s requestPreloadUpdate() was executed.');
        }

    }

    /**
     * Update the preloader with current loading progress.
     * This method is called by the preloadable object to report its progress.
     * 
     * @param progress Current progress value (0 to total)
     * @param total Total expected progress value
     * @param status Current loading status
     */
    public function updatePreload(progress:Int, total:Int, status:PreloadStatus):Void {

        this.progress = progress;
        this.total = total;
        this.preloadStatus = status;

        updateProgressBar();

        if (status == SUCCESS && !didSucceed) {
            didSucceed = true;
            emitSuccess();
        }

    }

    /**
     * Called before the success event is emitted.
     * If the preloadable is a Scene, this triggers a scene transition to replace
     * the preloader with the loaded scene.
     */
    function willEmitSuccess() {

        if (preloadable != null && preloadable is Scene) {
            final preloadableScene:Scene = cast preloadable;
            emitReplace(preloadableScene);
        }

    }

}
