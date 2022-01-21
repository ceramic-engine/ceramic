package backend;

import ceramic.IntBoolMap;
import ceramic.IntFloatMap;
import ceramic.IntIntMap;
import clay.Clay;
import clay.KeyCode;
import clay.ScanCode;
import clay.Types.AppEventType;
import clay.Types.GamepadDeviceEventType;
import clay.Types.ModState;
import clay.Types.TextEventType;
import clay.Types.WindowEventType;

@:access(backend.Backend)
@:access(backend.Screen)
@:access(backend.Input)
@:access(backend.TextInput)
@:access(ceramic.App)
class ClayEvents extends clay.Events {

    /**
     * Internal value to store gamepad state
     */
    inline static final GAMEPAD_STORAGE_SIZE:Int = 32;

    var backend:backend.Backend;

    var lastDensity:Float = -1;
    var lastWidth:Float = -1;
    var lastHeight:Float = -1;

    // Don't handle touch on desktop, for now
    #if !(mac || windows || linux)
    var touches:IntIntMap = new IntIntMap();
    var touchIndexes:IntIntMap = new IntIntMap();
    #end

    // Only handle mouse on desktop & web, for now
    #if (mac || windows || linux || web)
    var mouseDownButtons:IntBoolMap = new IntBoolMap();
    var mouseX:Float = 0;
    var mouseY:Float = 0;
    #end

    var activeGamepads:IntBoolMap = new IntBoolMap();
    var removedGamepads:IntBoolMap = new IntBoolMap();

    var gamepadAxisToButton:IntIntMap = new IntIntMap();
    var gamepadButtonMapping:IntIntMap = new IntIntMap();
    var gamepadPressedValues:IntIntMap = new IntIntMap();

    #if !ceramic_no_axis_round
    var gamepadAxisValues:IntFloatMap = new IntFloatMap();
    #end

    var handleReady:()->Void;

    function new(handleReady:()->Void) {

        this.handleReady = handleReady;

        configureGamepadMapping();

    }

    function configureGamepadMapping() {

        #if !ceramic_no_remap_gamepad

        #if (cpp && linc_sdl)

        // Tweak a few values to make these match what we got with HTML5 gamepad API
        // This is expected to work on PS4 and Xbox gamepads for now.
        // (better support of more gamepad could be done later if needed though)

        gamepadButtonMapping.set(9, 4);
        gamepadButtonMapping.set(10, 5);
        gamepadAxisToButton.set(4, 6);
        gamepadAxisToButton.set(5, 7);
        gamepadButtonMapping.set(4, 8);
        gamepadButtonMapping.set(6, 9);
        gamepadButtonMapping.set(7, 10);
        gamepadButtonMapping.set(8, 11);
        gamepadButtonMapping.set(11, 12);
        gamepadButtonMapping.set(12, 13);
        gamepadButtonMapping.set(13, 14);
        gamepadButtonMapping.set(14, 15);

        #end

        #end

    }

    override function ready() {

        backend = ceramic.App.app.backend;

        // Keep screen size and density value to trigger
        // resize events that might be skipped by the engine
        lastDensity = Clay.app.screenDensity;
        lastWidth = Clay.app.screenWidth;
        lastHeight = Clay.app.screenHeight;

        handleReady();

        backend.emitReady();

    }

    override function tick(delta:Float) {

        triggerResizeIfNeeded();

        backend.emitUpdate(delta);

    }

    #if (linc_sdl && cpp)

    override function sdlEvent(event:sdl.Event) {

        backend.emitSdlEvent(event);

    }

    #end

/// Internal

    function triggerResizeIfNeeded():Void {

        var density = Clay.app.screenDensity;
        var width = Clay.app.screenWidth;
        var height = Clay.app.screenHeight;

        if (lastDensity != density || lastWidth != width || lastHeight != height) {

            lastDensity = density;
            lastWidth = width;
            lastHeight = height;

            backend.screen.emitResize();
        }

    }

/// Overrides

    override function appEvent(type:AppEventType) {

        switch type {
            case UNKNOWN:
            case TERMINATING:
                ceramic.App.app.emitTerminate();
            case LOW_MEMORY:
                ceramic.App.app.emitLowMemory();
            case WILL_ENTER_BACKGROUND:
                ceramic.App.app.emitBeginEnterBackground();
            case DID_ENTER_BACKGROUND:
                #if (ios || android)
                backend.mobileInBackground = true;
                #end
                ceramic.App.app.emitFinishEnterBackground();
            case WILL_ENTER_FOREGROUND:
                ceramic.App.app.emitBeginEnterForeground();
                #if (ios || android)
                backend.mobileInBackground = false;
                #end
            case DID_ENTER_FOREGROUND:
                ceramic.App.app.emitFinishEnterForeground();
        }

    }

    // Only handle mouse on desktop & web, for now
    #if (mac || windows || linux || web)

    override function mouseDown(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        if (mouseDownButtons.exists(button)) {
            mouseUp(x, y, button, timestamp, windowId);
        }

        mouseX = x / Clay.app.screenDensity;
        mouseY = y / Clay.app.screenDensity;

        mouseDownButtons.set(button, true);
        backend.screen.emitMouseDown(button, mouseX, mouseY);

    }

    override function mouseUp(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        if (!mouseDownButtons.exists(button)) {
            return;
        }

        mouseX = x / Clay.app.screenDensity;
        mouseY = y / Clay.app.screenDensity;

        mouseDownButtons.remove(button);
        backend.screen.emitMouseUp(button, mouseX, mouseY);

    }

    override function mouseMove(x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, windowId:Int) {

        mouseX = x / Clay.app.screenDensity;
        mouseY = y / Clay.app.screenDensity;

        backend.screen.emitMouseMove(mouseX, mouseY);

    }

    override function mouseWheel(x:Float, y:Float, timestamp:Float, windowId:Int) {

        backend.screen.emitMouseWheel(x, y);

    }

    #end

    // Don't handle touch on desktop, for now
    #if !(mac || windows || linux)

    override function touchDown(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        var index = 0;
        while (touchIndexes.exists(index)) {
            index++;
        }
        touches.set(touchId, index);
        touchIndexes.set(index, touchId);

        backend.screen.emitTouchDown(
            index,
            x * lastWidth,
            y * lastHeight
        );

    }

    override function touchUp(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        if (!touches.exists(touchId)) {
            touchDown(x, y, dx, dy, touchId, timestamp);
        }
        var index = touches.get(touchId);

        backend.screen.emitTouchUp(
            index,
            x * lastWidth,
            y * lastHeight
        );

        touches.remove(touchId);
        touchIndexes.remove(index);

    }

    override function touchMove(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        if (!touches.exists(touchId)) {
            touchDown(x, y, dx, dy, touchId, timestamp);
        }
        var index = touches.get(touchId);

        backend.screen.emitTouchMove(
            index,
            x * lastWidth,
            y * lastHeight
        );

    }

    #end

    override function keyDown(keyCode:KeyCode, scanCode:ScanCode, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        backend.input.emitKeyDown({
            keyCode: (keyCode:Int),
            scanCode: (scanCode:Int)
        });

        if (backend.textInput.inputActive) {
            backend.textInput.handleKeyDown(keyCode, scanCode);
        }

    }

    override function keyUp(keyCode:KeyCode, scanCode:ScanCode, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        backend.input.emitKeyUp({
            keyCode: (keyCode:Int),
            scanCode: (scanCode:Int)
        });

        if (backend.textInput.inputActive) {
            backend.textInput.handleKeyUp(keyCode, scanCode);
        }

    }

    override function gamepadAxis(id:Int, axisId:Int, value:Float, timestamp:Float) {

        #if !(ios || android) // No gamepad on ios & android for now

        if (!activeGamepads.exists(id) && !removedGamepads.exists(id)) {
            activeGamepads.set(id, true);
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            backend.input.emitGamepadEnable(id, name);
        }

        if (gamepadAxisToButton.exists(axisId)) {
            var buttonId = gamepadAxisToButton.get(axisId);
            var pressed = value >= 0.5;
            if (pressed) {
                if (gamepadPressedValues.get(id * GAMEPAD_STORAGE_SIZE + buttonId) != 1) {
                    gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + buttonId, 1);
                    backend.input.emitGamepadDown(id, buttonId);
                }
            }
            else {
                if (gamepadPressedValues.get(id * GAMEPAD_STORAGE_SIZE + buttonId) == 1) {
                    gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + buttonId, 0);
                    backend.input.emitGamepadUp(id, buttonId);
                }
            }
        }
        else {
            #if !ceramic_no_axis_round
            var prevValue = gamepadAxisValues.get(id * GAMEPAD_STORAGE_SIZE + axisId);
            var newValue = Math.round(value * 100.0) / 100.0;
            if (Math.abs(prevValue - newValue) > 0.01) {
                gamepadAxisValues.set(id * GAMEPAD_STORAGE_SIZE + axisId, newValue);
                backend.input.emitGamepadAxis(id, axisId, newValue);
            }
            #else
            backend.input.emitGamepadAxis(id, axisId, event.value);
            #end
        }

        #end

    }

    override function gamepadDown(id:Int, buttonId:Int, value:Float, timestamp:Float) {

        #if !(ios || android)

        if (!activeGamepads.exists(id) && !removedGamepads.exists(id)) {
            activeGamepads.set(id, true);
            for (i in 0...GAMEPAD_STORAGE_SIZE) {
                gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + i, 0);
            }
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            backend.input.emitGamepadEnable(id, name);
        }

        if (gamepadButtonMapping.exists(buttonId)) {
            buttonId = gamepadButtonMapping.get(buttonId);
        }

        if (gamepadPressedValues.get(id * GAMEPAD_STORAGE_SIZE + buttonId) != 1) {
            gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + buttonId, 1);
            backend.input.emitGamepadDown(id, buttonId);
        }

        #end

    }

    override function gamepadUp(id:Int, buttonId:Int, value:Float, timestamp:Float) {

        #if !(ios || android)

        if (!activeGamepads.exists(id) && !removedGamepads.exists(id)) {
            activeGamepads.set(id, true);
            for (i in 0...GAMEPAD_STORAGE_SIZE) {
                gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + i, 0);
            }
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            backend.input.emitGamepadEnable(id, name);
        }

        if (gamepadButtonMapping.exists(buttonId)) {
            buttonId = gamepadButtonMapping.get(buttonId);
        }

        if (gamepadPressedValues.get(id * GAMEPAD_STORAGE_SIZE + buttonId) == 1) {
            gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + buttonId, 0);
            backend.input.emitGamepadUp(id, buttonId);
        }

        #end

    }

    override function gamepadDevice(id:Int, name:String, type:GamepadDeviceEventType, timestamp:Float) {

        #if !(ios || android)

        if (type == GamepadDeviceEventType.DEVICE_REMOVED) {
            if (activeGamepads.exists(id)) {
                for (i in 0...GAMEPAD_STORAGE_SIZE) {
                    if (gamepadPressedValues.get(id * GAMEPAD_STORAGE_SIZE + i) == 1) {
                        backend.input.emitGamepadUp(id, i);
                        gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + i, 0);
                    }
                }
                backend.input.emitGamepadDisable(id);
                activeGamepads.remove(id);
                removedGamepads.set(id, true);
                ceramic.App.app.onceUpdate(null, function(_) {
                    removedGamepads.remove(id);
                });
            }
        }
        else if (type == GamepadDeviceEventType.DEVICE_ADDED) {
            if (!activeGamepads.exists(id)) {
                activeGamepads.set(id, true);
                for (i in 0...GAMEPAD_STORAGE_SIZE) {
                    gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + i, 0);
                }
                removedGamepads.remove(id);
                var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
                backend.input.emitGamepadEnable(id, name);
            }
        }

        #end

    }

    override function text(text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, windowId:Int) {

        if (backend.textInput.inputActive) {
            backend.textInput.handleTextInput(text);
        }

    }

    override function windowEvent(type:WindowEventType, timestamp:Float, windowId:Int, x:Int, y:Int) {

        switch type {
            case UNKNOWN:
            case SHOWN:
            case HIDDEN:
            case EXPOSED:
            case MOVED:
            case RESIZED:
            case SIZE_CHANGED:
            case MINIMIZED:
            case MAXIMIZED:
            case RESTORED:
            case ENTER:
            case LEAVE:
            case FOCUS_GAINED:
            case FOCUS_LOST:
            case CLOSE:
            case ENTER_FULLSCREEN:
                ceramic.App.app.settings.fullscreen = true;
            case EXIT_FULLSCREEN:
                ceramic.App.app.settings.fullscreen = false;
        }

    }

}
