package backend;

import ceramic.IntIntMap;
import haxe.io.Bytes;
import unityengine.ImageConversion;
import unityengine.ScreenCapture;
import unityengine.Texture2D;
import unityengine.inputsystem.Mouse;
import unityengine.inputsystem.TouchPhase;
import unityengine.inputsystem.Touchscreen;
import unityengine.inputsystem.controls.TouchControl;

using ceramic.Extensions;

#if !no_backend_docs
/**
 * Unity backend implementation for screen and input handling.
 * Manages window properties, mouse/touch input, and screenshot capture functionality.
 * Handles Unity's Input System for both mouse and multi-touch interactions.
 */
#end
@:keep
@:allow(Main)
class Screen implements tracker.Events #if !completion implements spec.Screen #end {

    #if !no_backend_docs
    /**
     * Creates a new Screen instance and initializes display properties.
     * Automatically detects screen dimensions and calculates pixel density.
     */
    #end
    public function new() {

        isEditor = untyped __cs__('UnityEngine.Application.isEditor');

        width = untyped __cs__('UnityEngine.Screen.width');
        height = untyped __cs__('UnityEngine.Screen.height');

        if (!isEditor) {
            var dpi:Single = untyped __cs__('UnityEngine.Screen.dpi');
            density = Math.round(dpi / 160);
            if (density < 1) {
                density = 1;
            }
        }
        else {
            density = 1;
        }
        width = Math.round(width / density);
        height = Math.round(height / density);

    }

    #if !no_backend_docs
    /**
     * Current screen width in logical pixels (after density scaling).
     */
    #end
    var width:Int = 0;

    #if !no_backend_docs
    /**
     * Current screen height in logical pixels (after density scaling).
     */
    #end
    var height:Int = 0;

    #if !no_backend_docs
    /**
     * Screen pixel density multiplier (DPI / 160).
     * Used to convert between physical and logical pixels.
     */
    #end
    var density:Float = 1;

    #if !no_backend_docs
    /**
     * Whether the application is running in Unity Editor.
     * Editor mode uses density = 1 regardless of display DPI.
     */
    #end
    var isEditor:Bool = false;

/// Events

    #if !no_backend_docs
    /**
     * Emitted when the screen dimensions or density changes.
     */
    #end
    @event function resize();

    #if !no_backend_docs
    /**
     * Emitted when a mouse button is pressed.
     * @param buttonId Button identifier (0=left, 1=middle, 2=right)
     * @param x Mouse X position in logical pixels
     * @param y Mouse Y position in logical pixels
     */
    #end
    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when a mouse button is released.
     * @param buttonId Button identifier (0=left, 1=middle, 2=right)
     * @param x Mouse X position in logical pixels
     * @param y Mouse Y position in logical pixels
     */
    #end
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when the mouse wheel is scrolled.
     * @param x Horizontal scroll delta
     * @param y Vertical scroll delta
     */
    #end
    @event function mouseWheel(x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when the mouse cursor moves.
     * @param x Mouse X position in logical pixels
     * @param y Mouse Y position in logical pixels
     */
    #end
    @event function mouseMove(x:Float, y:Float);

    #if !no_backend_docs
    /**
     * Emitted when a touch begins.
     * @param touchIndex Touch identifier (0-based index)
     * @param x Touch X position in logical pixels
     * @param y Touch Y position in logical pixels
     */
    #end
    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when a touch ends.
     * @param touchIndex Touch identifier (0-based index)
     * @param x Touch X position in logical pixels
     * @param y Touch Y position in logical pixels
     */
    #end
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when a touch moves.
     * @param touchIndex Touch identifier (0-based index)
     * @param x Touch X position in logical pixels
     * @param y Touch Y position in logical pixels
     */
    #end
    @event function touchMove(touchIndex:Int, x:Float, y:Float);

/// Public API

    #if !no_backend_docs
    /**
     * Gets the current screen width in logical pixels.
     * @return Screen width after density scaling
     */
    #end
    inline public function getWidth():Int {

        return width;

    }

    #if !no_backend_docs
    /**
     * Gets the current screen height in logical pixels.
     * @return Screen height after density scaling
     */
    #end
    inline public function getHeight():Int {

        return height;

    }

    #if !no_backend_docs
    /**
     * Gets the current screen pixel density multiplier.
     * @return Density factor (DPI / 160), minimum 1.0
     */
    #end
    inline public function getDensity():Float {

        return density;

    }

    #if !no_backend_docs
    /**
     * Sets the background color for the screen.
     * Note: In Unity backend, this is handled during rendering.
     * @param background RGB color value (0xRRGGBB)
     */
    #end
    public function setBackground(background:Int):Void {

        // Background will be updated when drawing

    }

    #if !no_backend_docs
    /**
     * Sets the window title.
     * Note: Not implemented in Unity backend.
     * @param title Window title string
     */
    #end
    public function setWindowTitle(title:String):Void {

        // TODO

    }

    #if !no_backend_docs
    /**
     * Toggles fullscreen mode.
     * Note: Not implemented in Unity backend.
     * @param fullscreen Whether to enable fullscreen
     */
    #end
    public function setWindowFullscreen(fullscreen:Bool):Void {

        // TODO

    }

/// Internal

    #if !no_backend_docs
    /**
     * Updates screen dimensions and processes input events.
     * Called internally by the backend each frame.
     */
    #end
    @:allow(backend.Backend)
    function update() {

        var newWidth = untyped __cs__('UnityEngine.Screen.width');
        var newHeight = untyped __cs__('UnityEngine.Screen.height');

        var newDensity:Float = 1;
        if (!isEditor) {
            var dpi:Single = untyped __cs__('UnityEngine.Screen.dpi');
            newDensity = Math.round(dpi / 160);
            if (newDensity < 1) {
                newDensity = 1;
            }
            newWidth = Math.round(newWidth / newDensity);
            newHeight = Math.round(newHeight / newDensity);
        }

        var didResize = (width != newWidth) || (height != newHeight) || (density != newDensity);

        width = newWidth;
        height = newHeight;
        density = newDensity;

        if (didResize) {
            emitResize();
        }

        updateMouseInput();
        updateTouchInput();

    }

/// Mouse input

    #if !no_backend_docs
    /**
     * Tracks left mouse button state.
     */
    #end
    var mouseLeftPressed:Bool = false;

    #if !no_backend_docs
    /**
     * Tracks middle mouse button state.
     */
    #end
    var mouseMiddlePressed:Bool = false;

    #if !no_backend_docs
    /**
     * Tracks right mouse button state.
     */
    #end
    var mouseRightPressed:Bool = false;

    #if !no_backend_docs
    /**
     * Current mouse X position in logical pixels.
     */
    #end
    var mouseX:Float = -1;

    #if !no_backend_docs
    /**
     * Current mouse Y position in logical pixels.
     */
    #end
    var mouseY:Float = -1;

    #if !no_backend_docs
    /**
     * Processes mouse input from Unity's Input System.
     * Handles button states, movement, and wheel scrolling.
     */
    #end
    function updateMouseInput() {

        var mouse = Mouse.current;
        if (mouse != null) {

            var newMouseX = mouse.position.x.ReadValue() / density;
            var newMouseY = height - mouse.position.y.ReadValue() / density;

            // Use a factor to try to get a consistent value with other targets
            var mouseScrollX = Math.floor(mouse.scroll.x.ReadValue());
            var mouseScrollY = Math.floor(mouse.scroll.y.ReadValue());

            if (mouseScrollX != 0 || mouseScrollY != 0) {
                emitMouseWheel(mouseScrollX, mouseScrollY);
            }

            if (newMouseX != mouseX || newMouseY != mouseY) {
                mouseX = newMouseX;
                mouseY = newMouseY;
                emitMouseMove(mouseX, mouseY);
            }

            if (mouse.leftButton.isPressed) {
                if (!mouseLeftPressed) {
                    mouseLeftPressed = true;
                    emitMouseDown(0, mouseX, mouseY);
                }
            }
            else {
                if (mouseLeftPressed) {
                    mouseLeftPressed = false;
                    emitMouseUp(0, mouseX, mouseY);
                }
            }

            if (mouse.middleButton.isPressed) {
                if (!mouseMiddlePressed) {
                    mouseMiddlePressed = true;
                    emitMouseDown(1, mouseX, mouseY);
                }
            }
            else {
                if (mouseMiddlePressed) {
                    mouseMiddlePressed = false;
                    emitMouseUp(1, mouseX, mouseY);
                }
            }

            if (mouse.rightButton.isPressed) {
                if (!mouseRightPressed) {
                    mouseRightPressed = true;
                    emitMouseDown(2, mouseX, mouseY);
                }
            }
            else {
                if (mouseRightPressed) {
                    mouseRightPressed = false;
                    emitMouseUp(2, mouseX, mouseY);
                }
            }

        }

    }

/// Touch input

    #if !no_backend_docs
    /**
     * Maps Unity touch IDs to Ceramic touch indices.
     */
    #end
    var touchIdToIndex:IntIntMap = new IntIntMap(16, 0.5, false);

    #if !no_backend_docs
    /**
     * Tracks which touch indices are currently in use.
     * Maps index to Unity touch ID.
     */
    #end
    var usedTouchIndexes:IntIntMap = new IntIntMap(16, 0.5, false);

    #if !no_backend_docs
    /**
     * Touch indices processed in the current frame.
     */
    #end
    var processedTouchIndexes:Array<Int> = [];

    #if !no_backend_docs
    /**
     * Number of touches from the previous frame.
     */
    #end
    var prevNumTouches:Int = 0;

    #if !no_backend_docs
    /**
     * Touch indices from the previous frame.
     */
    #end
    var prevProcessedTouchIndexes:Array<Int> = [];

    #if !no_backend_docs
    /**
     * Touch positions for the current frame (x,y pairs).
     */
    #end
    var processedTouchPositions:Array<Float> = [];

    #if !no_backend_docs
    /**
     * Touch positions from the previous frame (x,y pairs).
     */
    #end
    var prevProcessedTouchPositions:Array<Float> = [];

    #if !no_backend_docs
    /**
     * Highest touch start time seen, used to filter stale touches.
     */
    #end
    var touchHighestStartTime:Float = -1;

    #if !no_backend_docs
    /**
     * Processes touch input from Unity's Input System.
     * Handles multi-touch with proper ID tracking and robustness checks.
     */
    #end
    function updateTouchInput() {

        var touchScreen = Touchscreen.current;

        // Skip if no touchscreen API available on this device
        if (touchScreen == null)
            return;

        var numTouches = touchScreen.touches.Count;
        var prevTouchHighestStartTime = touchHighestStartTime;

        #if ceramic_debug_unity_touch
        trace('DEBUGTOUCH -------');
        #end

        for (i in 0...numTouches) {
            processedTouchIndexes[i] = 0;

            var touch:TouchControl = untyped __cs__('{0}[{1}]', touchScreen.touches, i);

            var phase = touch.phase.ReadValue();

            #if ceramic_debug_unity_touch
            trace('DEBUGTOUCH ${touch.touchId.ReadValue()}-${phase}-${touch.startTime.ReadValue()}-[${touch.position.x.ReadValue()/density},${touch.position.y.ReadValue()/density}]');
            #end

            if (phase != TouchPhase.None) {
                var touchId = touch.touchId.ReadValue();

                if (touchId > 0) {
                    var index = touchIdToIndex.get(touchId);
                    var positionX = touch.position.x.ReadValue() / density;
                    var positionY = touch.position.y.ReadValue() / density;
                    var startTime:Float = touch.startTime.ReadValue();

                    if (index == 0) {
                        // We only accept touches that are starting.
                        // Or new touches with an id higher than previously processed touches
                        if (phase == TouchPhase.Ended) {
                            if (startTime <= prevTouchHighestStartTime)
                                continue;
                        }
                        else if (phase == TouchPhase.Canceled) {
                            continue;
                        }

                        if (startTime > touchHighestStartTime)
                            touchHighestStartTime = startTime;

                        index++;
                        while (usedTouchIndexes.get(index) != 0) {
                            index++;
                        }
                        usedTouchIndexes.set(index, touchId);
                        touchIdToIndex.set(touchId, index);

                        // Emit touch down
                        var x = positionX;
                        var y = height - positionY;
                        emitTouchDown(index - 1, x, y);
                    }
                    processedTouchIndexes[i] = index;
                    processedTouchPositions[i * 2] = positionX;
                    processedTouchPositions[i * 2 + 1] = positionY;

                    if (phase == TouchPhase.Moved) {
                        var deltaX = touch.delta.x.ReadValue();
                        var deltaY = touch.delta.y.ReadValue();
                        if (deltaX != 0 || deltaY != 0) {
                            // Emit touch move
                            var x = positionX;
                            var y = height - positionY;
                            emitTouchMove(index - 1, x, y);
                        }
                    }
                    // We treat any ended/canceled touch phase like the touch ended (touch up)
                    else if (phase == TouchPhase.Ended || phase == TouchPhase.Canceled) {
                        // Emit touch up
                        var x = positionX;
                        var y = height - positionY;
                        emitTouchUp(index - 1, x, y);

                        usedTouchIndexes.remove(index);
                        touchIdToIndex.remove(touchId);
                    }
                }
            }

        }

        // Snippet for robustness: look for previously active touches that are not referenced
        // anymore by unity's input system. This is not supposed to happen, but from previous
        // tests on device, it does happen :(. Anyway we are safe with this check no matter what.
        for (i in 0...prevNumTouches) {
            var prevIndex = prevProcessedTouchIndexes.unsafeGet(i);
            if (prevIndex > 0 && usedTouchIndexes.get(prevIndex) != 0) {
                // Check that index is still processed this frame
                var foundIndex = false;
                for (n in 0...numTouches) {
                    var index = processedTouchIndexes.unsafeGet(n);
                    if (index == prevIndex) {
                        foundIndex = true;
                        break;
                    }
                }

                if (!foundIndex) {
                    // Index seems expired, remove it from list
                    // and emit touch up

                    var x = prevProcessedTouchPositions[i * 2];
                    var y = prevProcessedTouchPositions[i * 2 + 1];
                    emitTouchUp(prevIndex - 1, x, y);

                    var touchId = usedTouchIndexes.get(prevIndex);
                    usedTouchIndexes.remove(prevIndex);
                    touchIdToIndex.remove(touchId);
                }
            }
        }

        // Swap processed indexes and positions for next iteration
        prevNumTouches = numTouches;
        var tmpProcessedIndexes = prevProcessedTouchIndexes;
        prevProcessedTouchIndexes = processedTouchIndexes;
        processedTouchIndexes = tmpProcessedIndexes;
        var tmpProcessedPosition = prevProcessedTouchPositions;
        prevProcessedTouchPositions = processedTouchPositions;
        processedTouchPositions = tmpProcessedPosition;

    }

/// Screenshot

    #if !no_backend_docs
    /**
     * Counter for generating unique screenshot texture names.
     */
    #end
    var nextScreenshotIndex:Int = 0;

    #if !no_backend_docs
    /**
     * Captures the current screen as a texture.
     * @param done Callback with the captured texture (null on failure)
     */
    #end
    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        var unityTexture:Texture2D = ScreenCapture.CaptureScreenshotAsTexture(1);
        if (unityTexture != null) {
            var texture = new TextureImpl('screenshot:' + (nextScreenshotIndex++), unityTexture, null #if unity_6000 , null #end);
            done(texture);
        }
        else {
            ceramic.Shortcuts.log.warning('Failed to generate texture from screen');
            done(null);
        }

    }

    #if !no_backend_docs
    /**
     * Captures the current screen as PNG data.
     * @param path Optional file path to save the PNG
     * @param done Callback with PNG bytes (null if path provided or on failure)
     */
    #end
    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        if (path != null) {
            ScreenCapture.CaptureScreenshot(path, 1);
            done();
        }
        else {
            var unityTexture:Texture2D = ScreenCapture.CaptureScreenshotAsTexture(1);
            if (unityTexture != null) {
                var pngBytesData = ImageConversion.EncodeToPNG(unityTexture);
                done(Bytes.ofData(pngBytesData));
            }
            else {
                ceramic.Shortcuts.log.warning('Failed to generate texture from screen');
                done(null);
            }
        }

    }

    #if !no_backend_docs
    /**
     * Captures the current screen as raw pixel data.
     * @param done Callback with pixel array, width, and height (null array on failure)
     */
    #end
    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        var unityTexture:Texture2D = ScreenCapture.CaptureScreenshotAsTexture(1);
        if (unityTexture != null) {
            var texture = new TextureImpl('screenshot:' + (nextScreenshotIndex++), unityTexture, null #if unity_6000 , null #end);
            var pixels = ceramic.App.app.backend.textures.fetchTexturePixels(texture);
            var width = texture.width;
            var height = texture.height;
            ceramic.App.app.backend.textures.destroyTexture(texture);
            done(pixels, width, height);
        }
        else {
            ceramic.Shortcuts.log.warning('Failed to generate texture from screen');
            done(null, 0, 0);
        }

    }


}
