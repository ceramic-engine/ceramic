package ceramic;

import ceramic.Assert.assert;
import ceramic.Shortcuts.*;

class Preloader extends Scene {

    @event function success();

    public var preloadable(default, null):Preloadable = null;

    public var progress(default, null):Int = 0;

    public var total(default, null):Int = 0;

    public var preloadStatus(default, null):PreloadStatus = NONE;

    public var ceramicLogo(default, null):CeramicLogo = null;

    public var progressForeground(default, null):Quad = null;

    public var progressBackground(default, null):Quad = null;

    var getPreloadable:()->Preloadable = null;

    // Just used internally to wrap `updatePreload()`
    // in a `Dynamic` once and avoid doing it at each call.
    var _updatePreload:(progress:Int, total:Int, status:PreloadStatus)->Void = null;

    var didCallUpdatePreload:Bool = false;

    var preloaderIndex:Int = -1;

    var didSucceed:Bool = false;

    static var _nextIndex:Int = 1;

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

    override function create():Void {

        createGraphics();

    }

    function createGraphics():Void {

        createCeramicLogo();

    }

    function createCeramicLogo():Void {

        if (ceramicLogo != null)
            return;

        ceramicLogo = new CeramicLogo();
        ceramicLogo.pos(width * 0.5, height * 0.42);
        ceramicLogo.anchor(0.5, 0.5);
        add(ceramicLogo);

        final targetScale = Math.min(width * 0.2 / ceramicLogo.width, height * 0.4 / ceramicLogo.height);
        animateScale(ceramicLogo, targetScale, () -> {
            initPreloadable();
            createProgressBar();
        });

    }

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
    function createProgressBar(yRatio:Float = 0.55, widthRatio:Float = 0.4, backgroundColor:Color = 0x444444, foregroundColor:Color = 0xFFFFFF):Void {

        if (progressForeground != null)
            return;

        final progressWidth = width * widthRatio;
        final progressHeight = Math.max(2, height * 0.005);

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

    function updateProgressBar():Void {

        if (progressForeground == null)
            return;

        if (total >= 1) {
            if (progress > total)
                progress = total;
            progressForeground.width = progressBackground.width * (progress * 1.0 / total);
        }

    }

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

    override function update(delta:Float):Void {

        if (preloadable != null) {
            didCallUpdatePreload = false;
            preloadable.requestPreloadUpdate(_updatePreload);
            assert(didCallUpdatePreload, 'Preloader\'s updatePreload() method hasn\'t been called when Preloadable\'s requestPreloadUpdate() was executed.');
        }

    }

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

    function willEmitSuccess() {

        if (preloadable != null && preloadable is Scene) {
            final preloadableScene:Scene = cast preloadable;
            emitReplace(preloadableScene);
        }

    }

}
