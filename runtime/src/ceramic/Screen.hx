package ceramic;

import ceramic.ReadOnlyArray;
import ceramic.Shortcuts.*;
import haxe.io.Bytes;
import tracker.Observable;

using ceramic.Extensions;

/**
 * Core screen management class that handles display properties, coordinate transformations, and input events.
 * 
 * Screen provides a unified interface for managing screen properties across different platforms,
 * handling logical vs native coordinates, and dispatching input events. It serves as the bridge
 * between the backend's native screen handling and Ceramic's logical coordinate system.
 * 
 * Key responsibilities:
 * - **Coordinate transformation**: Converts between native and logical coordinates
 * - **Screen scaling**: Manages different scaling modes (FIT, FILL, RESIZE, FIT_RESIZE)
 * - **Input handling**: Processes and dispatches mouse, touch, and pointer events
 * - **Visual hit testing**: Determines which visuals receive input events
 * - **Focus management**: Tracks and manages focused visuals
 * - **Screenshot capture**: Provides methods to capture screen content
 * 
 * The screen uses a matrix transformation system to handle scaling and positioning,
 * ensuring consistent behavior across different screen sizes and densities.
 * 
 * Example usage:
 * ```haxe
 * // Access screen properties
 * trace('Screen size: ${screen.width} x ${screen.height}');
 * trace('Native size: ${screen.nativeWidth} x ${screen.nativeHeight}');
 * 
 * // Listen for screen events
 * screen.onResize(this, () -> {
 *     trace('Screen resized');
 * });
 * 
 * // Check input states
 * if (screen.mousePressed(MouseButton.LEFT)) {
 *     trace('Left mouse button pressed at ${screen.mouseX}, ${screen.mouseY}');
 * }
 * ```
 * 
 * @see App#screen
 * @see ScreenScaling
 * @see Visual
 */
@:allow(ceramic.App)
#if lua
@dynamicEvents
@:dce
#end
class Screen extends Entity implements Observable {

/// Properties

    /**
     * Screen density computed from app's logical width/height
     * settings and native width/height.
     */
    public var density(default,null):Float = 1.0;

    /**
     * Logical width used in app to position elements.
     * Updated when the screen is resized.
     */
    public var width(default,null):Float = 0;

    /**
     * Logical height used in app to position elements.
     * Updated when the screen is resized.
     */
    public var height(default,null):Float = 0;

    /**
     * The actual width available on screen, including offsets, in the same unit as `width`.
     * Updated when the screen is resized.
     */
    public var actualWidth(default,null):Float = 0;

    /**
     * The actual height available on screen, including offsets, in the same unit as `width`.
     * Updated when the screen is resized.
     */
    public var actualHeight(default,null):Float = 0;

    /**
     * Logical x offset.
     * Updated when the screen is resized.
     */
    public var offsetX(default,null):Float = 0;

    /**
     * Logical y offset.
     * Updated when the screen is resized.
     */
    public var offsetY(default,null):Float = 0;

    /**
     * Native width
     */
    public var nativeWidth(get,null):Float;
    inline function get_nativeWidth():Float {
        return app.backend.screen.getWidth();
    }

    /**
     * Native height
     */
    public var nativeHeight(get,null):Float;
    inline function get_nativeHeight():Float {
        return app.backend.screen.getHeight();
    }

    /**
     * Native pixel ratio/density.
     */
    public var nativeDensity(get,null):Float;
    inline function get_nativeDensity():Float {
        return app.backend.screen.getDensity();
    }

    /**
     * Pointer x coordinate, computed from mouse and touch events.
     * When using multiple touch inputs at the same time, x will be
     * the mean value of all touches x value. Use this as a
     * convenience when you don't want to deal with multiple positions.
     */
    public var pointerX(default,null):Float = 0;

    /**
     * Pointer y coordinate, computed from mouse and touch events.
     * When using multiple touch inputs at the same time, y will be
     * the mean value of all touches y value. Use this as a
     * convenience when you don't want to deal with multiple positions.
     */
    public var pointerY(default,null):Float = 0;

    /**
     * Pointer x delta since last frame
     */
    public var pointerDeltaX(default,null):Float = 0;

    /**
     * Pointer y delta since last frame
     */
    public var pointerDeltaY(default,null):Float = 0;

    /**
     * Mouse x coordinate, computed from mouse events.
     */
    public var mouseX(default,null):Float = 0;

    /**
     * Mouse y coordinate, computed from mouse events.
     */
    public var mouseY(default,null):Float = 0;

    /**
     * Mouse x delta since last frame
     */
    public var mouseDeltaX(default, null):Float = 0;

    /**
     * Mouse y delta since last frame
     */
    public var mouseDeltaY(default, null):Float = 0;

    /**
     * Mouse wheel x delta since last frame
     */
    public var mouseWheelDeltaX(default, null):Float = 0;

    /**
     * Mouse wheel y delta since last frame
     */
    public var mouseWheelDeltaY(default, null):Float = 0;

    /**
     * Touches x and y coordinates by touch index.
     */
    public var touches(default,null):Touches = new Touches();

    /**
     * Focused visual
     */
    @observe public var focusedVisual(default,set):Visual = null;
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

    /**
     * Ideal textures density, computed from settings
     * targetDensity and current screen state.
     */
    @observe public var texturesDensity:Float = 1.0;

    /**
     * Root matrix applied to every visual.
     * This is recomputed on screen resize but
     * can be changed otherwise.
     */
    @:allow(ceramic.Visual)
    private var matrix:Transform = new Transform();

    /**
     * Internal inverted matrix computed from root matrix.
     */
    @:allow(ceramic.Visual)
    private var reverseMatrix:Transform = new Transform();

    /**
     * In order to prevent nested resizes.
     */
    private var resizing:Bool = false;

    /**
     * Whether the screen is between a `pointer down` and an `pointer up` event or not.
     */
    public var isPointerDown(get,null):Bool;
    var _numPointerDown:Int = 0;
    inline function get_isPointerDown():Bool { return _numPointerDown > 0; }

    private var pressedMouseButtons:IntIntMap = new IntIntMap(16, 0.5, false);

    private var pressedTouches:IntIntMap = new IntIntMap(16, 0.5, false);

    private var prevTouchPositions:IntFloatMap = new IntFloatMap(16, 0.5, false);

    private var prevMouseX:Float = 0;

    private var prevMouseY:Float = 0;

    private var maxTouchIndex:Int = -1;

    private var visualsListenPointerOver:Bool = false;

/// Events

    /**
     * Resize event occurs once at startup, then each time any
     * of native width, height or density changes.
     */
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

    /**
     * Creates a new Screen instance.
     * 
     * Typically not called directly - use the singleton instance via `app.screen`.
     */
    function new() {

        super();

    }

    /**
     * Initializes the screen after the backend is ready.
     * 
     * Sets up event listeners for native screen events, initializes coordinate
     * transformations, and configures settings observers. This method is called
     * automatically by the App during initialization.
     */
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
        settings.onFullscreenChange(this, function(fullscreen, prevFullscreen) {
            #if debug log.info('Setting fullscreen=$fullscreen'); #end
            app.backend.screen.setWindowFullscreen(fullscreen);
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
                prepareMultiTouchPointerMove(info, true);

                emitMouseMove(x1, y1);
                emitMultiTouchPointerMove(info);
                emitPointerMove(info);
            });
        });
        app.backend.screen.onMouseWheel(this, function(x, y) {
            app.beginUpdateCallbacks.push(function() {
                emitMouseWheel(x, y);
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
                prepareMultiTouchPointerMove(info, false);

                emitTouchMove(touchIndex, x1, y1);
                emitMultiTouchPointerMove(info);
                if (_numPointerDown > 0) {
                    emitPointerMove(info);
                }
            });
        });

    }

    /**
     * Updates pointer over/out states for visuals.
     * 
     * Called each frame to track which visuals have pointers hovering over them,
     * triggering pointerOver and pointerOut events as needed.
     * 
     * @param delta Time elapsed since last frame (unused)
     */
    function updatePointerOverState(delta:Float):Void {

 #if (!ios && !android)
        // Update mouse over state
        updateMouseOver(mouseX, mouseY);
#end

        // Update touch over state
        for (touch in touches) {
            updateTouchOver(touch.index, touch.x, touch.y);
        }

    }

    /**
     * Handles screen resize events.
     * 
     * Recalculates screen dimensions, scaling, and transformations based on
     * current settings and native screen properties. This method is called
     * automatically when the native screen size changes.
     * 
     * The resize process:
     * 1. Updates scaling based on settings
     * 2. Emits resize event (allowing custom handling)
     * 3. Recomputes transformations
     * 4. Updates texture density
     */
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

    /**
     * Updates the ideal texture density based on screen density and settings.
     * 
     * The texture density determines which resolution of assets should be loaded.
     * If targetDensity is set in settings, it overrides the calculated value.
     * Otherwise, density is rounded to the nearest integer (minimum 1).
     */
    function updateTexturesDensity():Void {

        if (settings.targetDensity > 0) {
            this.texturesDensity = settings.targetDensity;
        }
        else {
            var texturesDensity = density;

            if (texturesDensity < 1) {
                texturesDensity = 1;
            }
            else {
                texturesDensity = Math.round(texturesDensity);
            }

            this.texturesDensity = texturesDensity;
        }

    }

    /**
     * Recomputes screen dimensions and density based on scaling mode and native properties.
     * 
     * This method implements the different scaling modes:
     * - **FIT**: Scales to fit within target size, may show borders
     * - **FILL**: Scales to fill target size, may crop content
     * - **RESIZE**: Matches native size exactly
     * - **FIT_RESIZE**: Adjusts target size to match native aspect ratio
     * 
     * Updates width, height, actualWidth, actualHeight, density, offsetX, and offsetY.
     */
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
        actualWidth = Math.ceil(nativeWidth * nativeDensity * scale);
        actualHeight = Math.ceil(nativeHeight * nativeDensity * scale);
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

    /**
     * Recomputes the root transformation matrix from current screen properties.
     * 
     * The matrix is used to transform all visual coordinates from logical
     * to native screen space. It applies scaling and translation to properly
     * position content on screen based on the current scaling mode.
     */
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

    /**
     * Finds the topmost visual that should receive a pointer down event at the given coordinates.
     * 
     * This method performs hit testing through the visual hierarchy, respecting:
     * - Visual touchability and visibility
     * - Event interception by parents
     * - Special handling for hit visuals (visuals that block events behind them)
     * 
     * @param x X coordinate in logical screen space
     * @param y Y coordinate in logical screen space
     * @param touchIndex Touch index for touch events, -1 for mouse events
     * @param buttonId Mouse button ID, -1 for touch events
     * @return The visual that should receive the event, or null if none found
     */
    function matchFirstDownListener(x:Float, y:Float, touchIndex:Int = -1, buttonId:Int = -1):Visual {

        app.computeHierarchy();

        for (n in 0...2) {

            // We walk through visual up to 2 times to find the correct down listener
            // This double iteration is required when we hit first a visual that can re-route
            // its events to children that are rendered with a custom render target

            matchedHitVisual = null;
            var testHitVisuals = (n == 0);
            var visuals = app.visuals;
            var i = visuals.length - 1;
            while (i >= 0) {

                var visual = visuals.unsafeGet(i);
                if (!visual.destroyed && visual.computedTouchable) {
                    var visualListensPointerDown = visual.listensPointerDown();
                    var visualHits = false;
                    var visualIntercepts = false;
                    if (visualListensPointerDown) {
                        visualHits = visual.hits(x, y);
                        if (visualHits) {
                            visualIntercepts = visual.interceptPointerDown(visual, x, y, touchIndex, buttonId);
                            if (visualIntercepts) {
                                #if ceramic_debug_touch
                                log.debug('visual intercepts pointer down: $visual (parent=${visual.parent})');
                                #end
                            }
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

    /**
     * Finds the topmost visual that should receive pointer over events at the given coordinates.
     * 
     * Similar to matchFirstDownListener but for hover/over events. Only active
     * when at least one visual is listening for pointer over events.
     * 
     * @param x X coordinate in logical screen space
     * @param y Y coordinate in logical screen space
     * @return The visual that should receive over events, or null if none found
     */
    function matchFirstOverListener(x:Float, y:Float):Visual {

        if (visualsListenPointerOver) {

            app.computeHierarchy();

            for (n in 0...2) {

                // We walk through visual up to 2 times to find the correct down listener
                // This double iteration is required when we hit first a visual that can re-route
                // its events to children that are rendered with a custom render target

                matchedHitVisual = null;
                var testHitVisuals = (n == 0);
                var visuals = app.visuals;
                var i = visuals.length - 1;
                while (i >= 0) {

                    var visual = visuals.unsafeGet(i);
                    if (!visual.destroyed && visual.computedTouchable) {
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
        }

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
                pointer = { index: info.touchIndex, x: info.x, y: info.y, deltaX: 0, deltaY: 0 };
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
                pointer = { index: info.touchIndex, x: info.x, y: info.y, deltaX: 0, deltaY: 0 };
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

    inline function prepareMultiTouchPointerMove(info:TouchInfo, isMouse:Bool):Void {

        if (isMouse) {
            // Mouse
            mouseX = info.x;
            mouseY = info.y;
        }

        if (info.touchIndex != -1) {
            // Touch
            var pointer = touches.get(info.touchIndex);
            if (pointer == null) {
                pointer = { index: info.touchIndex, x: info.x, y: info.y, deltaX: 0, deltaY: 0 };
                touches.set(info.touchIndex, pointer);
            } else {
                pointer.x = info.x;
                pointer.y = info.y;
            }
        }

        updatePointer();

    }

    inline function updatePointer():Void {

        // Keep value for delta
        var prevPointerX = pointerX;
        var prevPointerY = pointerY;

        // Touches?
        //
        var numTouchPointers = 0;
        var pX = 0.0;
        var pY = 0.0;
        for (pointer in touches) {
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

        // Update delta
        pointerDeltaX += (pointerX - prevPointerX);
        pointerDeltaY += (pointerY - prevPointerY);

    }

    #if plugin_elements

    @:plugin('elements')
    inline function canEmitMultiTouchPointerDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitMultiTouchPointerMove(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitMultiTouchPointerUp(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitMouseDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitMouseMove(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitMouseUp(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitTouchDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitTouchMove(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitTouchUp(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitPointerDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitPointerMove(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitPointerUp(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    #end

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

    /**
     * Internal reference to a matched hit visual during hit testing.
     * 
     * This static variable is used during the hit testing process to ensure
     * that when a hit visual is encountered, only that visual and its children
     * can receive events, blocking all visuals behind it.
     * 
     * @see Visual#hits
     */
    @:noCompletion
    public static var matchedHitVisual:Visual = null;

    var hitVisuals:Array<Visual> = [];

    /**
     * Registers a visual as a hit visual.
     * 
     * Hit visuals are special visuals that block input events from reaching
     * visuals behind them, even if they don't handle the events themselves.
     * This is useful for modal dialogs, overlays, or invisible blocking areas.
     * 
     * @param visual The visual to register as a hit visual
     */
    public function addHitVisual(visual:Visual):Void {

        var wasHitVisual = visual.isHitVisual;
        hitVisuals.push(visual);

        if (!wasHitVisual) {
            visual.isHitVisual = true;
        }

    }

    /**
     * Unregisters a visual as a hit visual.
     * 
     * The visual will no longer block input events from reaching visuals
     * behind it unless it explicitly handles those events.
     * 
     * @param visual The visual to unregister
     */
    public function removeHitVisual(visual:Visual):Void {

        var index = hitVisuals.indexOf(visual);
        if (index == -1) {
            log.warning('Hit visual not removed from hitVisuals because it was not added at the first place');
        }
        else {
            hitVisuals.splice(index, 1);
            if (hitVisuals.indexOf(visual) == -1) {
                visual.isHitVisual = false;
            }
        }

    }

    /**
     * Checks if a visual is registered as a hit visual.
     * 
     * @param visual The visual to check
     * @return `true` if the visual is a hit visual
     */
    public function isHitVisual(visual:Visual):Bool {

        return visual.isHitVisual;

    }

/// Screen deltas

    /**
     * Resets all input deltas to zero.
     * 
     * Called at the beginning of each frame to clear movement deltas
     * for pointer, mouse, and touch inputs. This ensures deltas only
     * reflect movement within the current frame.
     */
    function resetDeltas():Void {

        pointerDeltaX = 0;
        pointerDeltaY = 0;

        mouseDeltaX = 0;
        mouseDeltaY = 0;

        mouseWheelDeltaX = 0;
        mouseWheelDeltaY = 0;

        var i = 0;
        while (i <= maxTouchIndex) {
            var touch:Touch = touches.get(i);
            if (touch != null) {
                touch.deltaX = 0;
                touch.deltaY = 0;
            }
            i++;
        }

    }

/// Mouse states

    function willEmitMouseMove(x:Float, y:Float):Void {

        mouseDeltaX += (x - prevMouseX);
        mouseDeltaY += (y - prevMouseY);
        prevMouseX = x;
        prevMouseY = y;

    }

    function willEmitMouseDown(buttonId:Int, x:Float, y:Float) {

        prevMouseX = x;
        prevMouseY = y;

        var prevValue = pressedMouseButtons.get(buttonId);

        if (prevValue == -1) {
            prevValue = 0;
        }

        pressedMouseButtons.set(buttonId, prevValue + 1);

        if (prevValue == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedMouseButtons.get(buttonId) == 1) {
                    pressedMouseButtons.set(buttonId, 2);
                }
            });
        }

        #if plugin_elements

        // When an elements UI window is focused, check if we are clicking outside
        // and remove focus in that case so that regular visuals & entities can resume catching events
        var context = elements.Context.context;
        if (context != null && context.focusedWindow != null) {
            var matched = matchFirstDownListener(x, y, -1, buttonId);
            if (matched == null || !elements.Im.filterEventOwner(matched)) {
                focusedVisual = null;
            }
        }

        #end

    }

    function willEmitMouseUp(buttonId:Int, x:Float, y:Float):Void {

        pressedMouseButtons.set(buttonId, -1);
        // Used to differenciate "released" and "just released" states
        ceramic.App.app.beginUpdateCallbacks.push(function() {
            if (pressedMouseButtons.get(buttonId) == -1) {
                pressedMouseButtons.set(buttonId, 0);
            }
        });

    }

    function willEmitMouseWheel(x:Float, y:Float):Void {

        mouseWheelDeltaX += x;
        mouseWheelDeltaY += y;

    }

    #if plugin_elements

    @:plugin('elements')
    static function _elementsImFocused():Bool {

        var context = elements.Context.context;
        return (context != null && context.focusedWindow != null);

    }

    #end

    /**
     * Checks if mouse events are currently allowed for the given entity.
     * 
     * This is primarily used with the elements plugin to ensure UI windows
     * can block events from reaching entities behind them. For most use cases,
     * this will always return true.
     * 
     * @param owner The entity to check
     * @return `true` if the entity can receive mouse events
     */
    inline public function mouseAllowed(owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) #else true #end;

    }

    public extern inline overload function mousePressed(buttonId:Int):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _mousePressed(buttonId);

    }

    public extern inline overload function mouseJustPressed(buttonId:Int):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _mouseJustPressed(buttonId);

    }

    public extern inline overload function mouseJustReleased(buttonId:Int):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _mouseJustReleased(buttonId);

    }

    public extern inline overload function mousePressed(buttonId:Int, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _mousePressed(buttonId);

    }

    public extern inline overload function mouseJustPressed(buttonId:Int, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _mouseJustPressed(buttonId);

    }

    public extern inline overload function mouseJustReleased(buttonId:Int, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _mouseJustReleased(buttonId);

    }

    function _mousePressed(buttonId:Int):Bool {

        return pressedMouseButtons.get(buttonId) > 0;

    }

    function _mouseJustPressed(buttonId:Int):Bool {

        return pressedMouseButtons.get(buttonId) == 1;

    }

    function _mouseJustReleased(buttonId:Int):Bool {

        return pressedMouseButtons.get(buttonId) == -1;

    }

/// Touch states

    function willEmitTouchMove(touchIndex:Int, x:Float, y:Float):Void {

        if (touchIndex > maxTouchIndex) {
            maxTouchIndex = touchIndex;
        }
        var keyX = touchIndex * 2;
        var keyY = keyX + 1;
        var prevX = prevTouchPositions.get(keyX);
        var prevY = prevTouchPositions.get(keyY);
        var touch:Touch = touches.get(touchIndex);
        if (touch != null) {
            touch.deltaX += (x - prevX);
            touch.deltaY += (y - prevY);
        }

    }

    function willEmitTouchDown(touchIndex:Int, x:Float, y:Float):Void {

        var keyX = touchIndex * 2;
        var keyY = keyX + 1;
        prevTouchPositions.set(keyX, x);
        prevTouchPositions.set(keyY, y);

        var prevValue = pressedTouches.get(touchIndex);

        if (prevValue == -1) {
            prevValue = 0;
        }

        pressedTouches.set(touchIndex, prevValue + 1);

        if (prevValue == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedTouches.get(touchIndex) == 1) {
                    pressedTouches.set(touchIndex, 2);
                }
            });
        }

        #if plugin_elements

        // When an elements UI window is focused, check if we are touching outside
        // and remove focus in that case so that regular visuals & entities can resume catching events
        var context = elements.Context.context;
        if (context != null && context.focusedWindow != null) {
            var matched = matchFirstDownListener(x, y, touchIndex, -1);
            if (matched == null || !elements.Im.filterEventOwner(matched)) {
                focusedVisual = null;
            }
        }

        #end

    }

    function willEmitTouchUp(touchIndex:Int, x:Float, y:Float):Void {

        var state = pressedTouches.get(touchIndex);
        if (state == 1) {
            // Just pressed and just released, all at the same frame
            pressedTouches.set(touchIndex, -2);
        }
        else {
            // Just released, was pressed before
            pressedTouches.set(touchIndex, -1);
        }
        // Used to differenciate "released" and "just released" states
        ceramic.App.app.beginUpdateCallbacks.push(function() {
            var state = pressedTouches.get(touchIndex);
            if (state == -1 || state == -2) {
                pressedTouches.set(touchIndex, 0);
            }
        });

    }

    public extern inline overload function touchPressed(touchIndex:Int):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _touchPressed(touchIndex);

    }

    public extern inline overload function touchJustPressed(touchIndex:Int):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _touchJustPressed(touchIndex);

    }

    public extern inline overload function touchJustReleased(touchIndex:Int):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _touchJustReleased(touchIndex);

    }

    public extern inline overload function touchPressed(touchIndex:Int, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _touchPressed(touchIndex);

    }

    public extern inline overload function touchJustPressed(touchIndex:Int, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _touchJustPressed(touchIndex);

    }

    public extern inline overload function touchJustReleased(touchIndex:Int, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _touchJustReleased(touchIndex);

    }

    function _touchPressed(touchIndex:Int):Bool {

        return pressedTouches.get(touchIndex) > 0;

    }

    function _touchJustPressed(touchIndex:Int):Bool {

        var state = pressedTouches.get(touchIndex);
        return state == 1 || state == -2;

    }

    function _touchJustReleased(touchIndex:Int):Bool {

        var state = pressedTouches.get(touchIndex);
        return state == -1 || state == -2;

    }

    /**
     * Gets the X-axis movement delta for a specific touch since the last frame.
     * 
     * @param touchIndex The index of the touch to check
     * @return The X delta in logical coordinates, or 0 if touch not found
     */
    public function touchDeltaX(touchIndex:Int):Float {

        var touch:Touch = touches.get(touchIndex);
        return touch != null ? touch.deltaX : 0.0;

    }

    /**
     * Gets the Y-axis movement delta for a specific touch since the last frame.
     * 
     * @param touchIndex The index of the touch to check
     * @return The Y delta in logical coordinates, or 0 if touch not found
     */
    public function touchDeltaY(touchIndex:Int):Float {

        var touch:Touch = touches.get(touchIndex);
        return touch != null ? touch.deltaY : 0.0;

    }

/// Screenshot

    /**
     * Captures the current screen content as a texture.
     * 
     * This is an asynchronous operation that renders the current frame to a texture.
     * The resulting texture can be used for effects, transitions, or saving screenshots.
     * 
     * @param done Callback that receives the captured texture, or null if capture failed
     */
    public function toTexture(done:(texture:Texture)->Void):Void {

        app.backend.screen.screenshotToTexture(function(backendItem:backend.Texture) {

            if (backendItem != null) {
                var texture = @:privateAccess new Texture(backendItem, nativeDensity);
                done(texture);
            }
            else {
                done(null);
            }

        });

    }

    /**
     * Captures the current screen content as raw pixel data.
     * 
     * Returns the screen content as an array of RGBA pixels in row-major order.
     * This is useful for image processing or custom screenshot implementations.
     * 
     * @param done Callback that receives pixel data, width, and height
     */
    public function toPixels(done:(pixels:UInt8Array, width:Int, height:Int)->Void):Void {

        app.backend.screen.screenshotToPixels(done);

    }

    /**
     * Captures the current screen content as PNG data.
     * 
     * This overload returns the PNG data as bytes, which can be used
     * for further processing or transmission.
     * 
     * @param done Callback that receives the PNG data as bytes
     */
    public extern inline overload function toPng(done:(data:Bytes)->Void):Void {

        _toPng(null, function(?data) {
            done(data);
        });

    }

    /**
     * Captures the current screen content and saves it as a PNG file.
     * 
     * This overload saves the screenshot directly to the specified file path.
     * 
     * @param path The file path where the PNG should be saved
     * @param done Callback called when the save operation completes
     */
    public extern inline overload function toPng(path:String, done:()->Void):Void {

        _toPng(path, function(?data) {
            done();
        });

    }

    /**
     * Internal implementation for PNG screenshot capture.
     * 
     * Waits for the current frame to finish drawing before capturing.
     */
    function _toPng(?path:String, done:(?data:Bytes)->Void):Void {

        app.onceFinishDraw(this, function() {
            app.backend.screen.screenshotToPng(path, done);
        });

    }

}
