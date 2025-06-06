package backend;

import ceramic.IntBoolMap;
import ceramic.IntFloatMap;
import ceramic.IntIntMap;
import ceramic.IntMap;
import clay.Clay;
import clay.KeyCode;
import clay.ScanCode;
import clay.Types.AppEventType;
import clay.Types.GamepadDeviceEventType;
import clay.Types.ModState;
import clay.Types.TextEventType;
import clay.Types.WindowEventType;

using StringTools;

#if clay_sdl
import clay.sdl.SDL;
#end

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

    #if (web && !ceramic_no_ab_swap)
    var swapAbGamepads:IntBoolMap = new IntBoolMap();
    var swapXyGamepads:IntBoolMap = new IntBoolMap();
    #end

    var gamepadAxisToButton:IntIntMap = new IntIntMap();
    var gamepadButtonMapping:IntIntMap = new IntIntMap();
    var gamepadPressedValues:IntIntMap = new IntIntMap();

    #if !ceramic_no_axis_round
    var gamepadAxisValues:IntFloatMap = new IntFloatMap();
    #end

    #if !ceramic_no_gyro_round
    var gamepadGyroValues:IntMap<Array<Float>> = new IntMap();
    #end

    var handleReady:()->Void;

    var gamepadsEnabled:Bool = true;

    function new(handleReady:()->Void) {

        this.handleReady = handleReady;

        #if (ios || ceramic_no_gamepad)
        gamepadsEnabled = false;
        #end

        configureGamepadMapping();

    }

    function configureGamepadMapping() {

        #if !ceramic_no_remap_gamepad

        #if clay_sdl

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

    override function render() {

        backend.emitRender();

    }

    #if clay_sdl

    override function sdlEvent(event:SDLEvent) {

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
                #if (ios || tvos || android)
                backend.mobileInBackground.store(true);
                #end
                ceramic.App.app.emitFinishEnterBackground();
            case WILL_ENTER_FOREGROUND:
                ceramic.App.app.emitBeginEnterForeground();
                #if (ios || tvos || android)
                backend.mobileInBackground.store(false);
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

        backend.textInput.handleKeyDown(keyCode, scanCode);

    }

    override function keyUp(keyCode:KeyCode, scanCode:ScanCode, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        backend.input.emitKeyUp({
            keyCode: (keyCode:Int),
            scanCode: (scanCode:Int)
        });

        backend.textInput.handleKeyUp(keyCode, scanCode);

    }

    function _configureGamepad(id:Int, name:String) {

        #if (web && !ceramic_no_ab_swap)
        if (name != null) {
            var lowerName = name.toLowerCase();
            if (lowerName.indexOf(' vendor: 057e ') != -1 || lowerName.startsWith('057e-')) {
                // Nintendo controller on web, swap A & B buttons and X & Y buttons
                swapAbGamepads.set(id, true);
                swapXyGamepads.set(id, true);
            }
            else {
                swapAbGamepads.set(id, false);
                swapXyGamepads.set(id, false);
            }
        }
        else {
            swapAbGamepads.set(id, false);
            swapXyGamepads.set(id, false);
        }
        #end

    }

    override function gamepadAxis(id:Int, axisId:Int, value:Float, timestamp:Float) {

        if (!gamepadsEnabled) return;

        if (!activeGamepads.exists(id) && !removedGamepads.exists(id)) {
            activeGamepads.set(id, true);
            var name = Clay.app.runtime.getGamepadName(id);
            _configureGamepad(id, name);
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

    override function gamepadDown(id:Int, buttonId:Int, value:Float, timestamp:Float) {

        if (!gamepadsEnabled) return;

        if (!activeGamepads.exists(id) && !removedGamepads.exists(id)) {
            activeGamepads.set(id, true);
            for (i in 0...GAMEPAD_STORAGE_SIZE) {
                gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + i, 0);
            }
            var name = Clay.app.runtime.getGamepadName(id);
            _configureGamepad(id, name);
            backend.input.emitGamepadEnable(id, name);
        }

        if (gamepadButtonMapping.exists(buttonId)) {
            buttonId = gamepadButtonMapping.get(buttonId);
        }

        #if (web && !ceramic_no_ab_swap)
        // Swap A & B button if needed
        if (buttonId == 0 || buttonId == 1) {
            if (swapAbGamepads.get(id)) {
                buttonId = (buttonId == 1) ? 0 : 1;
            }
        }
        #end

        #if (web && !ceramic_no_xy_swap)
        // Swap X & Y button if needed
        if (buttonId == 2 || buttonId == 3) {
            if (swapXyGamepads.get(id)) {
                buttonId = (buttonId == 2) ? 3 : 2;
            }
        }
        #end

        if (gamepadPressedValues.get(id * GAMEPAD_STORAGE_SIZE + buttonId) != 1) {
            gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + buttonId, 1);
            backend.input.emitGamepadDown(id, buttonId);
        }

    }

    override function gamepadUp(id:Int, buttonId:Int, value:Float, timestamp:Float) {

        if (!gamepadsEnabled) return;

        if (!activeGamepads.exists(id) && !removedGamepads.exists(id)) {
            activeGamepads.set(id, true);
            for (i in 0...GAMEPAD_STORAGE_SIZE) {
                gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + i, 0);
            }
            var name = Clay.app.runtime.getGamepadName(id);
            _configureGamepad(id, name);
            backend.input.emitGamepadEnable(id, name);
        }

        if (gamepadButtonMapping.exists(buttonId)) {
            buttonId = gamepadButtonMapping.get(buttonId);
        }

        #if (web && !ceramic_no_ab_swap)
        // Swap A & B button if needed
        if (buttonId == 0 || buttonId == 1) {
            if (swapAbGamepads.get(id)) {
                buttonId = (buttonId == 1) ? 0 : 1;
            }
        }
        #end

        #if (web && !ceramic_no_xy_swap)
        // Swap X & Y button if needed
        if (buttonId == 2 || buttonId == 3) {
            if (swapXyGamepads.get(id)) {
                buttonId = (buttonId == 2) ? 3 : 2;
            }
        }
        #end

        if (gamepadPressedValues.get(id * GAMEPAD_STORAGE_SIZE + buttonId) == 1) {
            gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + buttonId, 0);
            backend.input.emitGamepadUp(id, buttonId);
        }

    }

    override function gamepadGyro(id:Int, dx:Float, dy:Float, dz:Float, timestamp:Float) {

        #if (web && ceramic_native_bridge)

        // Will use native bridge instead

        #else

        if (!gamepadsEnabled) return;

        if (!activeGamepads.exists(id) && !removedGamepads.exists(id)) {
            activeGamepads.set(id, true);
            for (i in 0...GAMEPAD_STORAGE_SIZE) {
                gamepadPressedValues.set(id * GAMEPAD_STORAGE_SIZE + i, 0);
            }
            var name = Clay.app.runtime.getGamepadName(id);
            _configureGamepad(id, name);
            backend.input.emitGamepadEnable(id, name);
        }

        var scale = 360.0 / 1550.0;
        backend.input.emitGamepadGyro(
            id,
            dx * scale,
            dy * scale,
            dz * scale
        );

        #end

    }

    override function gamepadDevice(id:Int, name:String, type:GamepadDeviceEventType, timestamp:Float) {

        if (!gamepadsEnabled) return;

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
                var name = Clay.app.runtime.getGamepadName(id);
                _configureGamepad(id, name);
                backend.input.emitGamepadEnable(id, name);
            }
        }

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
