package backend;

import ceramic.IntIntMap;
import unityengine.inputsystem.Mouse;
import unityengine.inputsystem.TouchPhase;
import unityengine.inputsystem.Touchscreen;
import unityengine.inputsystem.controls.TouchControl;

using ceramic.Extensions;

@:keep
@:allow(Main)
class Screen implements tracker.Events #if !completion implements spec.Screen #end {

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

    var width:Int = 0;

    var height:Int = 0;

    var density:Float = 1;

    var isEditor:Bool = false;

/// Events

    @event function resize();

    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    @event function mouseWheel(x:Float, y:Float);
    @event function mouseMove(x:Float, y:Float);

    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    @event function touchMove(touchIndex:Int, x:Float, y:Float);

/// Public API

    inline public function getWidth():Int {

        return width;

    }

    inline public function getHeight():Int {

        return height;

    }

    inline public function getDensity():Float {

        return density;

    }

    public function setBackground(background:Int):Void {

        // Background will be updated when drawing

    }

    public function setWindowTitle(title:String):Void {

        // TODO

    }

    public function setWindowFullscreen(fullscreen:Bool):Void {

        // TODO

    }

/// Internal

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

    var mouseLeftPressed:Bool = false;

    var mouseMiddlePressed:Bool = false;

    var mouseRightPressed:Bool = false;

    var mouseX:Float = -1;

    var mouseY:Float = -1;

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

    var touchIdToIndex:IntIntMap = new IntIntMap(16, 0.5, false);

    var usedTouchIndexes:IntIntMap = new IntIntMap(16, 0.5, false);

    var processedTouchIndexes:Array<Int> = [];

    var prevNumTouches:Int = 0;

    var prevProcessedTouchIndexes:Array<Int> = [];

    var processedTouchPositions:Array<Float> = [];

    var prevProcessedTouchPositions:Array<Float> = [];

    function updateTouchInput() {

        var touchScreen = Touchscreen.current;

        // Skip if no touchscreen API available on this device
        if (touchScreen == null)
            return;

        var numTouches = touchScreen.touches.Count;

        for (i in 0...numTouches) {
            processedTouchIndexes[i] = 0;

            var touch:TouchControl = untyped __cs__('{0}[{1}]', touchScreen.touches, i);

            var phase = touch.phase.ReadValue();

            if (phase != TouchPhase.None) {
                var touchId = touch.touchId.ReadValue();

                if (touchId > 0) {
                    var index = touchIdToIndex.get(touchId);
                    var positionX = touch.position.x.ReadValue() / density;
                    var positionY = touch.position.y.ReadValue() / density;

                    if (index == 0) {
                        // We only accept touches that are starting.
                        // Anything else is not supposed to be handled
                        if (phase != TouchPhase.Began)
                            continue;

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

}
