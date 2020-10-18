package ceramic;

import ceramic.Shortcuts.*;
import tracker.Observable;

using ceramic.Extensions;

@:allow(ceramic.App)
#if lua
@dynamicEvents
@:dce
#end
class Screen extends Entity implements Observable {

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

    /** The actual width available on screen, including offsets, in the same unit as `width`.
        Updated when the screen is resized. */
    public var actualWidth(default,null):Float = 0;

    /** The actual height available on screen, including offsets, in the same unit as `width`.
        Updated when the screen is resized. */
    public var actualHeight(default,null):Float = 0;

    /** Logical x offset.
        Updated when the screen is resized. */
    public var offsetX(default,null):Float = 0;

    /** Logical y offset.
        Updated when the screen is resized. */
    public var offsetY(default,null):Float = 0;

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
    public var touches(default,null):Touches = new Touches(8, 0.5, false);

    /** Focused visual */
    public var focusedVisual(default,set):Visual = null;
    function set_focusedVisual(focusedVisual:Visual):Visual {
        if (this.focusedVisual == focusedVisual) return focusedVisual;

        var prevFocused = this.focusedVisual;
        this.focusedVisual = focusedVisual;

        if (prevFocused != null) {
            emitBlur(prevFocused);
            prevFocused.emitBlur();
        }

        if (focusedVisual != null) {
            emitFocus(focusedVisual);
            focusedVisual.emitFocus();
        }

        return focusedVisual;
    }

    /** Ideal textures density, computed from settings
        targetDensity and current screen state. */
    @observe public var texturesDensity:Float = 1.0;

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

    /** Whether the screen is between a `pointer down` and an `pointer up` event or not. */
    public var isPointerDown(get,null):Bool;
    var _numPointerDown:Int = 0;
    inline function get_isPointerDown():Bool { return _numPointerDown > 0; }

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
    @event function pointerDown(info:TouchInfo);
    @event function pointerUp(info:TouchInfo);
    @event function pointerMove(info:TouchInfo);

    // Generic (unified & multitouch) events
    //
    @event function multiTouchPointerDown(info:TouchInfo);
    @event function multiTouchPointerUp(info:TouchInfo);
    @event function multiTouchPointerMove(info:TouchInfo);

    // Focused visual events
    //
    @event function focus(visual:Visual);
    @event function blur(visual:Visual);

/// Lifecycle

    function new() {

        super();

    }

    function backendReady():Void {

        // Track native screen resize
        app.backend.screen.onResize(this, resize);

        // Trigger resize once at startup
        resize();
        
        // Observe visual settings
        //
        settings.onBackgroundChange(this, function(background, prevBackground) {
            #if debug log.info('Setting background=$background'); #end
            app.backend.screen.setBackground(background);
        });
        settings.onTitleChange(this, function(title, prevTitle) {
            #if debug log.info('Setting title=$title'); #end
            app.backend.screen.setWindowTitle(title);
        });
        settings.onScalingChange(this, function(scaling, prevScaling) {
            #if debug log.info('Setting scaling=$scaling'); #end
            resize();
        });
        settings.onTargetWidthChange(this, function(targetWidth, prevTargetWidth) {
            #if debug log.info('Setting targetWidth=$targetWidth'); #end
            resize();
        });
        settings.onTargetHeightChange(this, function(targetHeight, prevTargetWidth) {
            #if debug log.info('Setting targetHeight=$targetHeight'); #end
            resize();
        });
        settings.onTargetDensityChange(this, function(targetDensity, prevTargetDensity) {
            #if debug log.info('Setting targetDensity=$targetDensity'); #end
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
                app.flushImmediate();

                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);

                var info:TouchInfo = {
                    touchIndex: -1,
                    buttonId: buttonId,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 <= width && y1 >= 0 && y1 <= height
                };
                prepareMultiTouchPointerDown(info);

                emitMouseDown(buttonId, x1, y1);
                _numPointerDown++;
                emitMultiTouchPointerDown(info);
                if (_numPointerDown == 1) {
                    emitPointerDown(info);
                }
            });
        });
        app.backend.screen.onMouseUp(this, function(buttonId, x, y) {
            app.beginUpdateCallbacks.push(function() {
                app.flushImmediate();
                
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);

                var info:TouchInfo = {
                    touchIndex: -1,
                    buttonId: buttonId,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 <= width && y1 >= 0 && y1 <= height
                };
                prepareMultiTouchPointerUp(info);

                emitMouseUp(buttonId, x1, y1);
                _numPointerDown--;
                emitMultiTouchPointerUp(info);
                if (_numPointerDown == 0) {
                    emitPointerUp(info);
                }
            });
        });
        app.backend.screen.onMouseMove(this, function(x, y) {
            app.beginUpdateCallbacks.push(function() {
                app.flushImmediate();
                
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);

                var info:TouchInfo = {
                    touchIndex: -1,
                    buttonId: MouseButton.NONE,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 <= width && y1 >= 0 && y1 <= height
                };
                prepareMultiTouchPointerMove(info);

                emitMouseMove(x1, y1);
                emitMultiTouchPointerMove(info);
                emitPointerMove(info);
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
                app.flushImmediate();
                
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);

                var info:TouchInfo = {
                    touchIndex: touchIndex,
                    buttonId: -1,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 <= width && y1 >= 0 && y1 <= height
                };
                prepareMultiTouchPointerDown(info);

                emitTouchDown(touchIndex, x1, y1);
                _numPointerDown++;
                emitMultiTouchPointerDown(info);
                if (_numPointerDown == 1) {
                    emitPointerDown(info);
                }
            });
        });
        app.backend.screen.onTouchUp(this, function(touchIndex, x, y) {
            app.beginUpdateCallbacks.push(function() {
                app.flushImmediate();
                
                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);

                var info:TouchInfo = {
                    touchIndex: touchIndex,
                    buttonId: -1,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 <= width && y1 >= 0 && y1 <= height
                }
                prepareMultiTouchPointerUp(info);

                emitTouchUp(touchIndex, x1, y1);
                _numPointerDown--;
                emitMultiTouchPointerUp(info);
                if (_numPointerDown == 0) {
                    emitPointerUp(info);
                }
            });
        });
        app.backend.screen.onTouchMove(this, function(touchIndex, x, y) {
            app.beginUpdateCallbacks.push(function() {
                app.flushImmediate();

                var x0 = x * nativeDensity;
                var y0 = y * nativeDensity;
                var x1 = reverseMatrix.transformX(x0, y0);
                var y1 = reverseMatrix.transformY(x0, y0);

                var info:TouchInfo = {
                    touchIndex: touchIndex,
                    buttonId: -1,
                    x: x1,
                    y: y1,
                    hits: x1 >= 0 && x1 <= width && y1 >= 0 && y1 <= height
                };
                prepareMultiTouchPointerMove(info);

                emitTouchMove(touchIndex, x1, y1);
                emitMultiTouchPointerMove(info);
                if (_numPointerDown > 0) {
                    emitPointerMove(info);
                }
            });
        });

    }

    function updatePointerOverState(delta:Float):Void {

        // Update mouse over state
        updateMouseOver(mouseX, mouseY);

        // Update touch over state
        var numTouches = touches.values.length;
        if (numTouches > 0) {
            for (i in 0...numTouches) {
                var touch = touches.get(i);
                if (touch == null) continue;
                updateTouchOver(touch.index, touch.x, touch.y);
            }
        }

    }

    function resize():Void {

        // Already resizing?
        if (resizing) return;
        resizing = true;

        // Update scaling
        updateScaling();

        // Keep previous values
        var prevScaling = app.settings.scaling;
        var prevTargetWidth = app.settings.targetWidth;
        var prevTargetHeight = app.settings.targetHeight;

        // Emit resize event (to allow custom changes)
        emitResize();

        // Recompute scaling if target scaling or size changed at emit
        if (prevScaling != app.settings.scaling
        || prevTargetWidth != app.settings.targetWidth
        || prevTargetHeight != app.settings.targetHeight) {
            updateScaling();
        }

        // Apply result as transform
        updateTransform();

        // Update textures density
        updateTexturesDensity();

        // Resize finished
        resizing = false;

    }

    function updateTexturesDensity():Void {

        texturesDensity = (settings.targetDensity > 0) ?
            settings.targetDensity
        :
            density
        ;

    }

    /** Recompute screen width, height and density from settings and native state. */
    function updateScaling():Void {

        // Update screen scaling

        var targetWidth:Float = app.settings.targetWidth > 0 ? app.settings.targetWidth : nativeWidth;
        var targetHeight:Float = app.settings.targetHeight > 0 ? app.settings.targetHeight : nativeHeight;

        var scale:Float;
        
        switch (app.settings.scaling) {

            case FIT:
                scale = Math.max(targetWidth / (nativeWidth * nativeDensity), targetHeight / (nativeHeight * nativeDensity));

            case FILL:
                scale = Math.min(targetWidth / (nativeWidth * nativeDensity), targetHeight / (nativeHeight * nativeDensity));

            case RESIZE:
                targetWidth = nativeWidth;
                targetHeight = nativeHeight;
                scale = Math.max(targetWidth / (nativeWidth * nativeDensity), targetHeight / (nativeHeight * nativeDensity));

            case FIT_RESIZE:
                var nativeRatio = nativeHeight / nativeWidth;
                var targetRatio = targetHeight / targetWidth;
                if (nativeRatio > targetRatio) {
                    targetHeight = targetWidth * nativeRatio;
                }
                else if (nativeRatio < targetRatio) {
                    targetWidth = targetHeight / nativeRatio;
                }
                targetWidth = Math.ceil(targetWidth);
                targetHeight = Math.ceil(targetHeight);
                scale = Math.max(targetWidth / (nativeWidth * nativeDensity), targetHeight / (nativeHeight * nativeDensity));
        }

        // Init default values
        actualWidth = nativeWidth * nativeDensity * scale;
        actualHeight = nativeHeight * nativeDensity * scale;
        density = 1.0 / scale;

        // Offset
        switch (app.settings.scaling) {
            case FIT | FILL:
                offsetX = (actualWidth - targetWidth) * 0.5;
                offsetY = (actualHeight - targetHeight) * 0.5;
            case RESIZE | FIT_RESIZE:
                offsetX = 0;
                offsetY = 0;
        }

        // Update screen size
        width = targetWidth;
        height = targetHeight;

        /*
        if (app.settings.scaling == FIT_RESIZE) {
            offsetX = (targetWidth - width) * 0.5;
            offsetY = (targetHeight - height) * 0.5;
        }
        else {
            offsetX = 0;
            offsetY = 0;
        }
        */

    }

    /** Recompute transform from screen width, height and density. */
    function updateTransform():Void {
        
        var targetWidth:Float = app.settings.targetWidth > 0 ? app.settings.targetWidth * density : nativeWidth * nativeDensity;
        var targetHeight:Float = app.settings.targetHeight > 0 ? app.settings.targetHeight * density : nativeHeight * nativeDensity;

        switch (app.settings.scaling) {
            case RESIZE:
                targetWidth = nativeWidth * nativeDensity;
                targetHeight = nativeHeight * nativeDensity;
            case FIT_RESIZE:
                var nativeRatio = nativeHeight / nativeWidth;
                var targetRatio = targetHeight / targetWidth;
                if (nativeRatio > targetRatio) {
                    targetHeight = targetWidth * nativeRatio;
                }
                else if (nativeRatio < targetRatio) {
                    targetWidth = targetHeight / nativeRatio;
                }
            default:
        }

        // Update transform
        matrix.identity();

        matrix.scale(density, density);

        var tx = (nativeWidth * nativeDensity - targetWidth) * 0.5;
        var ty = (nativeHeight * nativeDensity - targetHeight) * 0.5;
        matrix.translate(tx, ty);

    }

/// Match visuals to x,y

    function matchFirstDownListener(x:Float, y:Float, touchIndex:Int = -1, buttonId:Int = -1):Visual {

        app.computeHierarchy();

        for (i in 0...2) {

            // We walk through visual up to 2 times to find the correct down listener
            // This double iteration is required when we hit first a visual that can re-route
            // its events to children that are rendered with a custom render target

            matchedHitVisual = null;
            var testHitVisuals = (i == 0);
            var visuals = app.visuals;
            var i = visuals.length - 1;
            while (i >= 0) {

                var visual = visuals[i];
                if (visual.computedTouchable) {
                    var visualListensPointerDown = visual.listensPointerDown();
                    var visualHits = false;
                    var visualIntercepts = false;
                    if (visualListensPointerDown) {
                        visualHits = visual.hits(x, y);
                        if (visualHits) {
                            visualIntercepts = visual.interceptPointerDown(visual, x, y, touchIndex, buttonId);
                            #if ceramic_debug_touch
                            log.debug('visual intercepts pointer down: $visual (parent=${visual.parent})');
                            #end
                        }
                    }
                    if ((visualHits && !visualIntercepts) ||
                        (testHitVisuals && isHitVisual(visual) && visual.hits(x, y))) {

                        var intercepts = false;

                        // If a parent intercepts this pointer event, ignore the visual
                        if (visualListensPointerDown) {
                            var parent = visual.parent;
                            while (parent != null) {
                                intercepts = parent.interceptPointerDown(visual, x, y, touchIndex, buttonId);
                                if (intercepts) {
                                    #if ceramic_debug_touch
                                    log.debug('visual parent intercepts pointer down: $parent (parent=${parent.parent})');
                                    #end
                                    break;
                                }
                                parent = parent.parent;
                            }
                        }

                        if (!intercepts) {
                            // If no parent did intercept, that's should be fine,
                            // But also check that this is not a hitVisual
                            if (!visualListensPointerDown && testHitVisuals && isHitVisual(visual)) {
                                // We matched a hit visual, keep the reference and continue
                                matchedHitVisual = visual;
                            }
                            else {
                                // Clean any hitVisual reference
                                matchedHitVisual = null;

                                #if ceramic_debug_touch
                                log.debug('visual pointer down: $visual (parent=${visual.parent})');
                                #end

                                // Return this matching visual
                                return visual;
                            }
                        }
                    }
                }

                i--;
            }
        }

        // Clean any hitVisual reference
        matchedHitVisual = null;

        return null;

    }

    function matchFirstOverListener(x:Float, y:Float):Visual {

        app.computeHierarchy();

        for (i in 0...2) {

            // We walk through visual up to 2 times to find the correct down listener
            // This double iteration is required when we hit first a visual that can re-route
            // its events to children that are rendered with a custom render target

            matchedHitVisual = null;
            var testHitVisuals = (i == 0);
            var visuals = app.visuals;
            var i = visuals.length - 1;
            while (i >= 0) {

                var visual = visuals[i];
                if (visual.computedTouchable) {
                    var visualListensPointerOver = visual.listensPointerOver();
                    var visualHits = false;
                    var visualIntercepts = false;
                    if (visualListensPointerOver) {
                        visualHits = visual.hits(x, y);
                        if (visualHits) {
                            visualIntercepts = visual.interceptPointerOver(visual, x, y);
                            #if ceramic_debug_touch_over
                            log.debug('visual intercepts pointer over: $visual (parent=${visual.parent})');
                            #end
                        }
                    }
                    if ((visualHits && !visualIntercepts) ||
                        (testHitVisuals && isHitVisual(visual) && visual.hits(x, y))) {

                        var intercepts = false;

                        // If a parent intercepts this pointer event, ignore the visual
                        if (visualListensPointerOver) {
                            var parent = visual.parent;
                            while (parent != null) {
                                intercepts = parent.interceptPointerOver(visual, x, y);
                                if (intercepts) {
                                    #if ceramic_debug_touch_over
                                    log.debug('visual parent intercepts pointer over: $parent (parent=${parent.parent})');
                                    #end
                                    break;
                                }
                                parent = parent.parent;
                            }
                        }

                        if (!intercepts) {
                            // If no parent did intercept, that's should be fine,
                            // But also check that this is not a hitVisual
                            if (!visualListensPointerOver && testHitVisuals && isHitVisual(visual)) {
                                // We matched a hit visual, keep the reference and continue
                                matchedHitVisual = visual;
                            }
                            else {
                                // Clean any hitVisual reference
                                matchedHitVisual = null;

                                #if ceramic_debug_touch_over
                                log.debug('visual pointer over: $visual (parent=${visual.parent})');
                                #end

                                // Return this matching visual
                                return visual;
                            }
                        }
                    }
                }

                i--;
            }
        }

        // Clean any hitVisual reference
        matchedHitVisual = null;

        return null;

    }

/// Touch/Mouse events

    inline function prepareMultiTouchPointerDown(info:TouchInfo):Void {

        if (info.buttonId != -1) {
            // Mouse
            mouseX = info.x;
            mouseY = info.y;
        }
        
        if (info.touchIndex != -1) {
            // Touch
            var pointer = touches.get(info.touchIndex);
            if (pointer == null) {
                pointer = { index: info.touchIndex, x: info.x, y: info.y };
                touches.set(info.touchIndex, pointer);
            } else {
                pointer.x = info.x;
                pointer.y = info.y;
            }
        }

        updatePointer();

    }

    inline function prepareMultiTouchPointerUp(info:TouchInfo):Void {

        if (info.buttonId != -1) {
            // Mouse
            mouseX = info.x;
            mouseY = info.y;
        }

        if (info.touchIndex != -1) {
            // Touch
            var pointer = touches.get(info.touchIndex);
            if (pointer == null) {
                pointer = { index: info.touchIndex, x: info.x, y: info.y };
                touches.set(info.touchIndex, pointer);
            } else {
                pointer.x = info.x;
                pointer.y = info.y;
            }
        }

        updatePointer();

        if (info.touchIndex != -1) {
            // Touch
            touches.set(info.touchIndex, null);
        }

    }

    inline function prepareMultiTouchPointerMove(info:TouchInfo):Void {

        if (info.buttonId != -1) {
            // Mouse
            mouseX = info.x;
            mouseY = info.y;
        }

        if (info.touchIndex != -1) {
            // Touch
            var pointer = touches.get(info.touchIndex);
            if (pointer == null) {
                pointer = { index: info.touchIndex, x: info.x, y: info.y };
                touches.set(info.touchIndex, pointer);
            } else {
                pointer.x = info.x;
                pointer.y = info.y;
            }
        }

        updatePointer();

    }

    inline function updatePointer():Void {

        // Touches?
        //
        var numTouchPointers = 0;
        var pX = 0.0;
        var pY = 0.0;
        for (i in 0...touches.values.length) {
            var pointer = touches.values.get(i);
            if (pointer == null) continue;
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
        else {
            pointerX = mouseX;
            pointerY = mouseY;
        }

    }

    var matchedDownListeners:Map<Int,Visual> = new Map();

    var matchedOverListeners:Map<Int,Visual> = new Map();

    inline function didEmitMouseDown(buttonId:Int, x:Float, y:Float):Void {

        var matched = matchFirstDownListener(x, y, -1, buttonId);
        if (matched != null) {
            matched._numPointerDown++;
            if (matched._numPointerDown == 1 || matched.multiTouch) {
                screen.focusedVisual = matched;
                matched.emitPointerDown({
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

    }

    inline function didEmitMouseUp(buttonId:Int, x:Float, y:Float):Void {

        var id = 10000 + buttonId;
        var matched = matchedDownListeners.get(id);
        if (matched != null && !matched.destroyed && matched._numPointerDown > 0) {
            matched._numPointerDown--;
            if (matched._numPointerDown == 0 || matched.multiTouch) {
                matched.emitPointerUp({
                    touchIndex: -1,
                    buttonId: buttonId,
                    x: x,
                    y: y,
                    hits: matched.hits(x, y)
                });
            }
        }
        matchedDownListeners.remove(id);

    }

    inline function updateMouseOver(x:Float, y:Float) {

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
        if (prevMatched != null && prevMatched != matched && !prevMatched.destroyed && prevMatched._numPointerOver > 0) {
            prevMatched._numPointerOver--;
            if (prevMatched._numPointerOver == 0 || prevMatched.multiTouch) {
                prevMatched.emitPointerOut({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: false
                });
            }
        }
        if (matched != null && prevMatched != matched) {
            matched._numPointerOver++;
            if (matched._numPointerOver == 1 || matched.multiTouch) {
                matched.emitPointerOver({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: true
                });
            }
        }

    }

    inline function didEmitTouchDown(touchIndex:Int, x:Float, y:Float):Void {

        var matched = matchFirstDownListener(x, y, touchIndex, -1);
        if (matched != null) {
            matched._numPointerDown++;
            if (matched._numPointerDown == 1 || matched.multiTouch) {
                screen.focusedVisual = matched;
                matched.emitPointerDown({
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

    }

    inline function didEmitTouchUp(touchIndex:Int, x:Float, y:Float):Void {

        var id = 20000 + touchIndex;
        var matched = matchedDownListeners.get(id);
        if (matched != null && !matched.destroyed && matched._numPointerDown > 0) {
            matched._numPointerDown--;
            if (matched._numPointerDown == 0 || matched.multiTouch) {
                matched.emitPointerUp({
                    touchIndex: touchIndex,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: matched.hits(x, y)
                });
            }
        }
        matchedDownListeners.remove(id);

    }

    inline function updateTouchOver(touchIndex:Int, x:Float, y:Float):Void {

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
        if (prevMatched != null && prevMatched != matched && !prevMatched.destroyed && prevMatched._numPointerOver > 0) {
            prevMatched._numPointerOver--;
            if (prevMatched._numPointerOver == 0 || prevMatched.multiTouch) {
                prevMatched.emitPointerOut({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: false
                });
            }
        }
        if (matched != null && prevMatched != matched) {
            matched._numPointerOver++;
            if (matched._numPointerOver == 1 || matched.multiTouch) {
                matched.emitPointerOver({
                    touchIndex: -1,
                    buttonId: -1,
                    x: x,
                    y: y,
                    hits: true
                });
            }
        }

    }

/// Hit visual logic

    /** Internal reference to a matched hit visual. This is used to let Visual.hit() return `false`
        on every visual not related to the matched hit visual, if any is defined. */
    @:noCompletion
    public static var matchedHitVisual:Visual = null;

    var hitVisuals:Array<Visual> = [];

    public function addHitVisual(visual:Visual):Void {

        var wasHitVisual = isHitVisual(visual);
        hitVisuals.push(visual);

        if (!wasHitVisual) {
            visual.internalFlag(3, true);
        }

    }

    public function removeHitVisual(visual:Visual):Void {

        var index = hitVisuals.indexOf(visual);
        if (index == -1) {
            log.warning('Hit visual not removed from hitVisuals because it was not added at the first place');
        }
        else {
            hitVisuals.splice(index, 1);
            if (hitVisuals.indexOf(visual) == -1) {
                visual.internalFlag(3, false);
            }
        }

    }

    public function isHitVisual(visual:Visual):Bool {

        return visual.internalFlag(3);

    }

}
