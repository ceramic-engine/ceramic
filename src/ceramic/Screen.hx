package ceramic;

import ceramic.internal.ReadOnlyPoint as Point;
import ceramic.Shortcuts.*;

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

    /** Pointer x coordinate, computed from mouse and touch events.
        When using multiple touch inputs at the same time, x will be
        the mean value of all touches x value. Use this as a
        convenience when you don't want to deal with multiple positions. */
    public var pointerX(default,null):Float = 0;

    /** Pointer y coordinate, computed from mouse and touch events.
        When using multiple touch inputs at the same time, y will be
        the mean value of all touches y value. Use this as a
        convenience when you don't want to deal with multiple positions. */
    public var pointerY(default,null):Float = 0;

    /** Mouse x coordinate, computed from mouse events. */
    public var mouseX(default,null):Float = 0;

    /** Mouse y coordinate, computed from mouse events. */
    public var mouseY(default,null):Float = 0;

    /** Touches x and y coordinates by touch index. */
    public var touches(default,null):Touches = new Touches();

    /** Ideal textures density, computed from settings
        targetDensity and current screen state. */
    @observable public var texturesDensity:Float = 1.0;

    /** Root matrix applied to every visual.
        This is recomputed on screen resize but
        can be changed otherwise. */
    @:allow(ceramic.Visual)
    private var matrix:Transform = new Transform();

    /** Internal inverted matrix computed from root matrix. */
    @:allow(ceramic.Visual)
    private var reverseMatrix:Transform = new Transform();

    /** In order to prevent nested resizes. */
    private var resizing:Bool = false;

    /** Whether the screen is between a `down` and an `up` event or not. */
    public var isDown(get,null):Bool;
    var _numDown:Int = 0;
    inline function get_isDown():Bool { return _numDown > 0; }

/// Events

    /** Resize event occurs once at startup, then each time any
        of native width, height or density changes. */
    @event function resize();

    // Mouse events
    //
    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    @event function mouseWheel(x:Float, y:Float);
    @event function mouseMove(x:Float, y:Float);

    // Touch events
    //
    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    @event function touchMove(touchIndex:Int, x:Float, y:Float);

    // Generic (unified) events
    //
    @event function down(info:TouchInfo);
    @event function up(info:TouchInfo);
    @event function move(info:TouchInfo);

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
                _numDown++;
                if (_numDown == 1) {
                    emitDown({
                        touchIndex: -1,
                        buttonId: buttonId,
                        x: x1,
                        y: y1,
                        hits: x1 >= 0 && x1 < width && y1 >= 0 && y1 < height
                    });
                }
            });
        });
        app.backend.screen.onMouseUp(this, function(buttonId, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitMouseUp(buttonId, x1, y1);
                _numDown--;
                if (_numDown == 0) {
                    emitUp({
                        touchIndex: -1,
                        buttonId: buttonId,
                        x: x1,
                        y: y1,
                        hits: x1 >= 0 && x1 < width && y1 >= 0 && y1 < height
                    });
                }
            });
        });
        app.backend.screen.onMouseMove(this, function(x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitMouseMove(x1, y1);
                emitMove({
                    touchIndex: -1,
                    buttonId: MouseButton.NONE,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 < width && y1 >= 0 && y1 < height
                });
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
        app.backend.screen.onTouchDown(this, function(touchIndex, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitTouchDown(touchIndex, x1, y1);
                _numDown++;
                if (_numDown == 1) {
                    emitDown({
                        touchIndex: touchIndex,
                        buttonId: -1,
                        x: x1,
                        y: y1,
                        hits: x1 >= 0 && x1 < width && y1 >= 0 && y1 < height
                    });
                }
            });
        });
        app.backend.screen.onTouchUp(this, function(touchIndex, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitTouchUp(touchIndex, x1, y1);
                _numDown--;
                if (_numDown == 0) {
                    emitUp({
                        touchIndex: touchIndex,
                        buttonId: -1,
                        x: x1,
                        y: y1,
                        hits: x1 >= 0 && x1 < width && y1 >= 0 && y1 < height
                    });
                }
            });
        });
        app.backend.screen.onTouchMove(this, function(touchIndex, x, y) {
            app.beginUpdateCallbacks.push(function() {
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);
                emitTouchMove(touchIndex, x1, y1);
                emitMove({
                    touchIndex: touchIndex,
                    buttonId: -1,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 < width && y1 >= 0 && y1 < height
                });
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

/// Match visuals to x,y

    function matchFirstDownListener(x:Float, y:Float):Visual {

        var visuals = app.visuals;
        var i = visuals.length - 1;
        while (i >= 0) {

            var visual = visuals[i];
            if (visual.listensDown() && visual.hits(x, y)) {
                return visual;
            }

            i--;
        }

        return null;

    } //matchFirstDownListener

    function matchFirstOverListener(x:Float, y:Float):Visual {

        var visuals = app.visuals;
        var i = visuals.length - 1;
        while (i >= 0) {

            var visual = visuals[i];
            if (visual.listensOver() && visual.hits(x, y)) {
                return visual;
            }

            i--;
        }

        return null;

    } //matchFirstOverListener

/// Touch/Mouse events

    inline function willEmitDown(info:TouchInfo):Void {

        if (info.buttonId != -1) {
            // Mouse
            mouseX = info.x;
            mouseY = info.y;
        }
        
        if (info.touchIndex != -1) {
            // Touch
            var pointer = touches.get(info.touchIndex);
            if (pointer == null) {
                pointer = { x: info.x, y: info.y };
                touches.set(info.touchIndex, pointer);
            } else {
                pointer.x = info.x;
                pointer.y = info.y;
            }
        }

        updatePointer();

    } //willEmitDown

    inline function willEmitUp(info:TouchInfo):Void {

        if (info.buttonId != -1) {
            // Mouse
            mouseX = info.x;
            mouseY = info.y;
        }

        if (info.touchIndex != -1) {
            // Touch
            var pointer = touches.get(info.touchIndex);
            if (pointer == null) {
                pointer = { x: info.x, y: info.y };
                touches.set(info.touchIndex, pointer);
            } else {
                pointer.x = info.x;
                pointer.y = info.y;
            }
        }

        updatePointer();

        if (info.touchIndex != -1) {
            // Touch
            touches.remove(info.touchIndex);
        }

    } //willEmitUp

    inline function willEmitMove(info:TouchInfo):Void {

        if (info.buttonId != -1) {
            // Mouse
            mouseX = info.x;
            mouseY = info.y;
        }

        if (info.touchIndex != -1) {
            // Touch
            var pointer = touches.get(info.touchIndex);
            if (pointer == null) {
                pointer = { x: info.x, y: info.y };
                touches.set(info.touchIndex, pointer);
            } else {
                pointer.x = info.x;
                pointer.y = info.y;
            }
        }

        updatePointer();

    } //willEmitMove

    inline function updatePointer():Void {

        // Touches?
        //
        var numTouchPointers = 0;
        var pX = 0.0;
        var pY = 0.0;
        for (pointer in touches) {
            if (pointer == null) continue; // Why does this happen?
            numTouchPointers++;
            pX += pointer.x;
            pY += pointer.y;
        }
        if (numTouchPointers > 0) {
            pointerX = pX / numTouchPointers;
            pointerY = pY / numTouchPointers;
        }

        // Or mouse
        //
        pointerX = mouseX;
        pointerY = mouseY;

        // TODO REMOVE
        //trace('pointer $pointerX, $pointerY');

    } //updatePointer

    var matchedDownListeners:Map<Int,Visual> = new Map();

    var matchedOverListeners:Map<Int,Visual> = new Map();

    inline function didEmitMouseDown(buttonId:Int, x:Float, y:Float):Void {

        var matched = matchFirstDownListener(x, y);
        if (matched != null) {
            matched._numDown++;
            if (matched._numDown == 1 || matched.multiTouch) {
                matched.emitDown({
                    touchIndex: -1,
                    buttonId: buttonId,
                    x: x,
                    y: y,
                    hits: true
                });
            }
        }
        var id = 10000 + buttonId;
        matchedDownListeners.set(id, matched);

    } //didEmitMouseDown

    inline function didEmitMouseUp(buttonId:Int, x:Float, y:Float):Void {

        var id = 10000 + buttonId;
        var matched = matchedDownListeners.get(id);
        if (matched != null && !matched.destroyed && matched._numDown > 0) {
            matched._numDown--;
            if (matched._numDown == 0 || matched.multiTouch) {
                matched.emitUp({
                    touchIndex: -1,
                    buttonId: buttonId,
                    x: x,
                    y: y,
                    hits: matched.hits(x, y)
                });
            }
        }
        matchedDownListeners.remove(id);

    } //didEmitMouseUp

    inline function didEmitMouseMove(x:Float, y:Float):Void {

        var id = 10000;
        var prevMatched = matchedOverListeners.get(id);
        var matched = matchFirstOverListener(x, y);
        if (matched != prevMatched) {
            if (matched != null) {
                matchedOverListeners.set(id, matched);
            } else {
                matchedOverListeners.remove(id);
            }
        }
        if (prevMatched != null && prevMatched != matched && !prevMatched.destroyed && prevMatched._numOver > 0) {
            prevMatched._numOver--;
            if (prevMatched._numOver == 0 || prevMatched.multiTouch) {
                prevMatched.emitOut({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: false
                });
            }
        }
        if (matched != null) {
            matched._numOver++;
            if (matched._numOver == 1 || matched.multiTouch) {
                matched.emitOver({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: true
                });
            }
        }

    } //didEmitMouseMove

    inline function didEmitTouchDown(touchIndex:Int, x:Float, y:Float):Void {

        var matched = matchFirstDownListener(x, y);
        if (matched != null) {
            matched._numDown++;
            if (matched._numDown == 1 || matched.multiTouch) {
                matched.emitDown({
                    touchIndex: touchIndex,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: true
                });
            }
        }
        var id = 20000 + touchIndex;
        matchedDownListeners.set(id, matched);

    } //didEmitTouchDown

    inline function didEmitTouchUp(touchIndex:Int, x:Float, y:Float):Void {

        var id = 20000 + touchIndex;
        var matched = matchedDownListeners.get(id);
        if (matched != null && !matched.destroyed && matched._numDown > 0) {
            matched._numDown--;
            if (matched._numDown == 0 || matched.multiTouch) {
                matched.emitUp({
                    touchIndex: touchIndex,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: matched.hits(x, y)
                });
            }
        }
        matchedDownListeners.remove(id);

    } //didEmitTouchUp

    inline function didEmitTouchMove(touchIndex:Int, x:Float, y:Float):Void {

        var id = 20000 + touchIndex;
        var prevMatched = matchedOverListeners.get(id);
        var matched = matchFirstOverListener(x, y);
        if (matched != prevMatched) {
            if (matched != null) {
                matchedOverListeners.set(id, matched);
            } else {
                matchedOverListeners.remove(id);
            }
        }
        if (prevMatched != null && prevMatched != matched && !prevMatched.destroyed && prevMatched._numOver > 0) {
            prevMatched._numOver--;
            if (prevMatched._numOver == 0 || prevMatched.multiTouch) {
                prevMatched.emitOut({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: false
                });
            }
        }
        if (matched != null) {
            matched._numOver++;
            if (matched._numOver == 1 || matched.multiTouch) {
                matched.emitOver({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: true
                });
            }
        }

    } //didEmitTouchMove

}
