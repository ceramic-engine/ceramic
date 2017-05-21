package ceramic;

@:allow(ceramic.App)
class Screen extends Entity {

/// Properties

    /** Screen density computed from app's logical width/height
        settings and native width/height. */
    public var density(default,null):Float = 1.0;

    /** Logical width used in app to position elements.
        Updated when the screen is resized. */
    public var width(default,null):Float = 0;

    /** Logical height used in app to position elements.
        Updated when the screen is resized. */
    public var height(default,null):Float = 0;

    /** Native width */
    public var nativeWidth(get,null):Float;
    inline function get_nativeWidth():Float {
        return app.backend.screen.getWidth();
    }

    /** Native height */
    public var nativeHeight(get,null):Float;
    inline function get_nativeHeight():Float {
        return app.backend.screen.getHeight();
    }

    /** Native pixel ratio/density. */
    public var nativeDensity(get,null):Float;
    inline function get_nativeDensity():Float {
        return app.backend.screen.getDensity();
    }

    /** Ideal textures density, computed from settings
        targetDensity and current screen state. */
    @observable public var texturesDensity:Float = 1.0;

    /** Root matrix applied to every visual.
        This is recomputed on screen resize but
        can be changed otherwise. */
    @:allow(ceramic.Visual)
    private var matrix:Transform = new Transform();

    /** Internal inverted matrix computed from root matrix. */
    private var reverseMatrix:Transform = new Transform();

    /** In order to prevent nested resizes. */
    private var resizing:Bool = false;

/// Events

    /** Resize event occurs once at startup, then each time any
        of native width, height or density changes. */
    @event function resize();

    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    @event function mouseWheel(x:Float, y:Float);
    @event function mouseMove(x:Float, y:Float);

    @event function touchDown(touchId:Int, x:Float, y:Float);
    @event function touchUp(touchId:Int, x:Float, y:Float);
    @event function touchMove(touchId:Int, x:Float, y:Float);

/// Lifecycle

    function new() {

    } //new

    function backendReady():Void {

        // Track native screen resize
        app.backend.screen.onResize(this, resize);

        // Trigger resize once at startup
        resize();
        
        // Observe visual settings
        //
        settings.onBackgroundChange(this, function(background, prevBackground) {
            log('Setting background=$background');
            app.backend.screen.setBackground(background);
        });
        settings.onScalingChange(this, function(scaling, prevScaling) {
            log('Setting scaling=$scaling');
            resize();
        });
        settings.onTargetWidthChange(this, function(targetWidth, prevTargetWidth) {
            log('Setting targetWidth=$targetWidth');
            resize();
        });
        settings.onTargetHeightChange(this, function(targetHeight, prevTargetWidth) {
            log('Setting targetHeight=$targetHeight');
            resize();
        });
        settings.onTargetDensityChange(this, function(targetDensity, prevtargetDensity) {
            log('Setting targetDensity=$targetDensity');
            updateTexturesDensity();
        });

        // Update inverted matrix when root one changes
        //
        matrix.onChange(this, function() {
            reverseMatrix.identity();
            reverseMatrix.concat(matrix);
            reverseMatrix.invert();
            reverseMatrix.emitChange();
        });

        // Handle mouse events
        //
        app.backend.screen.onMouseDown(this, function(buttonId, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitMouseDown(buttonId, x1, y1);
            });
        });
        app.backend.screen.onMouseUp(this, function(buttonId, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitMouseUp(buttonId, x1, y1);
            });
        });
        app.backend.screen.onMouseMove(this, function(x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitMouseMove(x1, y1);
            });
        });
        app.backend.screen.onMouseWheel(this, function(x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitMouseWheel(x1, y1);
            });
        });

        // Handle touch events
        //
        app.backend.screen.onTouchDown(this, function(touchId, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitTouchDown(touchId, x1, y1);
            });
        });
        app.backend.screen.onTouchUp(this, function(touchId, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitTouchUp(touchId, x1, y1);
            });
        });
        app.backend.screen.onTouchMove(this, function(touchId, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitTouchMove(touchId, x1, y1);
            });
        });

    } //backendReady

    function resize():Void {

        // Already resizing?
        if (resizing) return;
        resizing = true;

        // Update scaling
        updateScaling();

        // Emit resize event (to allow custom changes)
        emitResize();

        // Apply result as transform
        updateTransform();

        // Update textures density
        updateTexturesDensity();

        // Resize finished
        resizing = false;

    } //resize

    function updateTexturesDensity():Void {

        texturesDensity = (settings.targetDensity > 0) ?
            settings.targetDensity
        :
            density
        ;

    } //updateTexturesDensity

    /** Recompute screen width, height and density from settings and native state. */
    function updateScaling():Void {

        // Update screen scaling

        var targetWidth:Float = app.settings.targetWidth > 0 ? app.settings.targetWidth : nativeWidth;
        var targetHeight:Float = app.settings.targetHeight > 0 ? app.settings.targetHeight : nativeHeight;

        var scale = switch (app.settings.scaling) {
            case FIT:
                Math.max(targetWidth / (nativeWidth * nativeDensity), targetHeight / (nativeHeight * nativeDensity));
            case FILL:
                Math.min(targetWidth / (nativeWidth * nativeDensity), targetHeight / (nativeHeight * nativeDensity));
        }

        // Init default values
        width = nativeWidth * nativeDensity * scale;
        height = nativeHeight * nativeDensity * scale;
        density = 1.0 / scale;

    } //updateScaling

    /** Recompute transform from screen width, height and density. */
    function updateTransform():Void {
        
        var targetWidth:Float = app.settings.targetWidth > 0 ? app.settings.targetWidth : nativeWidth;
        var targetHeight:Float = app.settings.targetHeight > 0 ? app.settings.targetHeight : nativeHeight;

        // Update transform
        matrix.identity();

        matrix.scale(density, density);

        var tx = (nativeWidth * nativeDensity - targetWidth * density) * 0.5;
        var ty = (nativeHeight * nativeDensity - targetHeight * density) * 0.5;
        matrix.translate(tx, ty);

        // Force visuals to recompute their matrix and take
        // screen matrix in account
        for (visual in app.visuals) {
            visual.matrixDirty = true;
        }

    } //updateTransform

/// Touch/Mouse events

    inline function didEmitMouseDown(buttonId:Int, x:Float, y:Float):Void {



    } //didEmitMouseDown

}
