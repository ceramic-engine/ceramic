package ceramic;

@:allow(ceramic.App)
class Screen extends Entity {

/// Properties

    /** Screen density computed from app width/height
        settings and native width/height. */
    public var density(default,null):Float = 1.0;

    /** Width used in app to position elements.
        Updated when the screen is resized. */
    public var width(default,null):Float = 0;

    /** Height used in app to position elements.
        Updated when the screen is resized. */
    public var height(default,null):Float = 0;

    /** Native width (in pixels) */
    public var nativeWidth(get,null):Float;
    inline function get_nativeWidth():Float {
        return app.backend.screen.getPixelWidth();
    }

    /** Native height (in pixels) */
    public var nativeHeight(get,null):Float;
    inline function get_nativeHeight():Float {
        return app.backend.screen.getPixelHeight();
    }

    /** Native pixel ratio/density. */
    public var nativeDensity(get,null):Float;
    inline function get_nativeDensity():Float {
        return app.backend.screen.getPixelRatio();
    }

    /** Root matrix applied to every visual.
        This is recomputed on screen resize but
        can be changed otherwise. */
    @:allow(ceramic.Visual)
    private var matrix:Transform = new Transform();

/// Events

    /** Update event is called as many times as there are frames per seconds.
        Use this event to update your contents before they get drawn again. */
    @event function update(delta:Float);

    /** Resize event occurs once at startup, then each time any
        of native width, height or density changes. */
    @event function resize();

/// Lifecycle

    function new() {

    } //new

    function backendReady():Void {

        // Track native screen resize
        app.backend.screen.onResize(this, resize);

        // Trigger resize once at startup
        onceUpdate(function(delta) resize());

    } //backendReady

    function resize():Void {

        // Update scaling
        updateScaling();

        // Emit resize event (to allow custom changes)
        emitResize();

        // Apply result as transform
        updateTransform();

    } //resize

    /** Recompute screen width, height and density from settings and native state. */
    function updateScaling():Void {

        // Update screen scaling

        var targetWidth:Float = app.settings.targetWidth > 0 ? app.settings.targetWidth : nativeWidth / nativeDensity;
        var targetHeight:Float = app.settings.targetHeight > 0 ? app.settings.targetHeight : nativeHeight / nativeDensity;

        var scale = switch (app.settings.scaling) {
            case FIT:
                Math.max(targetWidth / nativeWidth, targetHeight / nativeHeight);
            case FILL:
                Math.min(targetWidth / nativeWidth, targetHeight / nativeHeight);
        }

        // Init default values
        width = nativeWidth * scale;
        height = nativeHeight * scale;
        density = 1.0 / scale;

    } //updateScaling

    /** Recompute transform from screen width, height and density. */
    function updateTransform():Void {
        
        var targetWidth:Float = app.settings.targetWidth > 0 ? app.settings.targetWidth : nativeWidth / nativeDensity;
        var targetHeight:Float = app.settings.targetHeight > 0 ? app.settings.targetHeight : nativeHeight / nativeDensity;

        // Update transform
        matrix.identity();

        matrix.scale(density, density);

        var tx = (nativeWidth - targetWidth * density) * 0.5;
        var ty = (nativeHeight - targetHeight * density) * 0.5;
        matrix.translate(tx, ty);

    } //updateTransform

}
