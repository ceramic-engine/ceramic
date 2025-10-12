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

/**
 * Event handler for the Clay backend that bridges low-level Clay engine events
 * to high-level Ceramic framework events.
 *
 * This class processes all input events from the Clay engine including:
 * - Mouse events (desktop/web platforms)
 * - Touch events (mobile platforms)
 * - Keyboard events
 * - Gamepad events with button mapping and axis-to-button conversion
 * - Application lifecycle events
 * - Window events
 * - Text input events
 *
 * Platform-specific behavior:
 * - Desktop (Mac/Windows/Linux): Mouse input only, no touch
 * - Mobile (iOS/Android): Touch input only, no mouse
 * - Web: Mouse input with optional gamepad button remapping
 *
 * The class includes gamepad normalization to ensure consistent button
 * mappings across different controller types and platforms.
 */
@:access(backend.Backend)
@:access(backend.Screen)
@:access(backend.Input)
@:access(backend.TextInput)
@:access(ceramic.App)
class ClayEvents extends clay.Events {

    /**
     * Internal value to store gamepad state.
     * Each gamepad can have up to 32 buttons/axes tracked.
     */
    inline static final GAMEPAD_STORAGE_SIZE:Int = 32;

    /** Reference to the main backend instance */
    var backend:backend.Backend;

    /** Cached screen density to detect changes */
    var lastDensity:Float = -1;
    /** Cached screen width to detect changes */
    var lastWidth:Float = -1;
    /** Cached screen height to detect changes */
    var lastHeight:Float = -1;

    // Don't handle touch on desktop, for now
    #if !(mac || windows || linux)
    /** Maps touch IDs to sequential indexes for consistent tracking */
    var touches:IntIntMap = new IntIntMap();
    /** Reverse mapping from indexes to touch IDs */
    var touchIndexes:IntIntMap = new IntIntMap();
    #end

    // Only handle mouse on desktop & web, for now
    #if (mac || windows || linux || web)
    /** Tracks which mouse buttons are currently pressed */
    var mouseDownButtons:IntBoolMap = new IntBoolMap();
    /** Current mouse X position in logical coordinates */
    var mouseX:Float = 0;
    /** Current mouse Y position in logical coordinates */
    var mouseY:Float = 0;
    #end

    /** Tracks currently connected gamepad IDs */
    var activeGamepads:IntBoolMap = new IntBoolMap();
    /** Temporarily tracks removed gamepads to prevent immediate re-detection */
    var removedGamepads:IntBoolMap = new IntBoolMap();

    #if !ceramic_no_ab_swap
    /** Tracks which gamepads need A/B button swapping (Nintendo controllers) */
    var swapAbGamepads:IntBoolMap = new IntBoolMap();
    #end
    #if !ceramic_no_xy_swap
    /** Tracks which gamepads need X/Y button swapping (Nintendo controllers) */
    var swapXyGamepads:IntBoolMap = new IntBoolMap();
    #end

    /** Maps gamepad axis IDs to virtual button IDs (for triggers) */
    var gamepadAxisToButton:IntIntMap = new IntIntMap();
    /** Remaps physical button IDs to standardized button IDs */
    var gamepadButtonMapping:IntIntMap = new IntIntMap();
    /** Stores pressed state for each gamepad button (packed storage) */
    var gamepadPressedValues:IntIntMap = new IntIntMap();

    #if !ceramic_no_axis_round
    /** Cached gamepad axis values for change detection (packed storage) */
    var gamepadAxisValues:IntFloatMap = new IntFloatMap();
    #end

    #if !ceramic_no_gyro_round
    /** Cached gyroscope values for change detection */
    var gamepadGyroValues:IntMap<Array<Float>> = new IntMap();
    #end

    /** Callback invoked when the event system is ready */
    var handleReady:()->Void;

    /** Whether gamepad input processing is enabled */
    var gamepadsEnabled:Bool = true;

    /**
     * Creates a new Clay events handler.
     * @param handleReady Callback invoked when the event system is ready
     */
    function new(handleReady:()->Void) {

        this.handleReady = handleReady;

        #if (ios || ceramic_no_gamepad)
        gamepadsEnabled = false;
        #end

        configureGamepadMapping();

    }

    /**
     * Configures gamepad button mapping to normalize differences between
     * SDL gamepad API and HTML5 gamepad API. This ensures consistent
     * button IDs across platforms.
     */
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

    /**
     * Called when the Clay engine is ready.
     * Initializes the backend reference and triggers the ready callback.
     */
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

    /**
     * Called every frame update.
     * @param delta Time elapsed since last frame in seconds
     */
    override function tick(delta:Float) {

        triggerResizeIfNeeded();

        backend.emitUpdate(delta);

    }

    /**
     * Called when a frame needs to be rendered.
     */
    override function render() {

        backend.emitRender();

    }

    #if clay_sdl

    /**
     * Handles raw SDL events for platform-specific functionality.
     * @param event The SDL event to process
     */
    override function sdlEvent(event:SDLEvent) {

        backend.emitSdlEvent(event);

    }

    #end

/// Internal

    /**
     * Checks if screen dimensions or density have changed and triggers
     * a resize event if needed. This handles cases where the engine
     * might miss resize events.
     */
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

    /**
     * Handles application lifecycle events.
     * @param type The type of application event
     */
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

    /**
     * Handles mouse button press events.
     * Converts physical pixel coordinates to logical coordinates using screen density.
     * Ensures proper handling of multiple presses of the same button by triggering mouseUp first.
     *
     * Platform availability: Desktop (Mac/Windows/Linux) and Web only.
     *
     * @param x Physical X coordinate in pixels
     * @param y Physical Y coordinate in pixels
     * @param button Mouse button ID (0=left, 1=middle, 2=right)
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that received the event
     */
    override function mouseDown(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        if (mouseDownButtons.exists(button)) {
            mouseUp(x, y, button, timestamp, windowId);
        }

        mouseX = x / Clay.app.screenDensity;
        mouseY = y / Clay.app.screenDensity;

        mouseDownButtons.set(button, true);
        backend.screen.emitMouseDown(button, mouseX, mouseY);

    }

    /**
     * Handles mouse button release events.
     * Converts physical pixel coordinates to logical coordinates using screen density.
     * Ignores mouse up events for buttons that weren't previously pressed down.
     *
     * Platform availability: Desktop (Mac/Windows/Linux) and Web only.
     *
     * @param x Physical X coordinate in pixels
     * @param y Physical Y coordinate in pixels
     * @param button Mouse button ID (0=left, 1=middle, 2=right)
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that received the event
     */
    override function mouseUp(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        if (!mouseDownButtons.exists(button)) {
            return;
        }

        mouseX = x / Clay.app.screenDensity;
        mouseY = y / Clay.app.screenDensity;

        mouseDownButtons.remove(button);
        backend.screen.emitMouseUp(button, mouseX, mouseY);

    }

    /**
     * Handles mouse movement events.
     * Converts physical pixel coordinates to logical coordinates using screen density.
     * Updates internal mouse position tracking and emits movement events.
     *
     * Platform availability: Desktop (Mac/Windows/Linux) and Web only.
     *
     * @param x Physical X coordinate in pixels
     * @param y Physical Y coordinate in pixels
     * @param xrel Relative X movement in pixels (not used)
     * @param yrel Relative Y movement in pixels (not used)
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that received the event
     */
    override function mouseMove(x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, windowId:Int) {

        mouseX = x / Clay.app.screenDensity;
        mouseY = y / Clay.app.screenDensity;

        backend.screen.emitMouseMove(mouseX, mouseY);

    }

    /**
     * Handles mouse wheel scroll events.
     * Passes through wheel delta values directly without coordinate transformation.
     *
     * Platform availability: Desktop (Mac/Windows/Linux) and Web only.
     *
     * @param x Horizontal scroll delta (positive = right, negative = left)
     * @param y Vertical scroll delta (positive = up, negative = down)
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that received the event
     */
    override function mouseWheel(x:Float, y:Float, timestamp:Float, windowId:Int) {

        backend.screen.emitMouseWheel(x, y);

    }

    #end

    // Don't handle touch on desktop, for now
    #if !(mac || windows || linux)

    /**
     * Handles touch press events.
     * Maps platform-specific touch IDs to sequential indexes for consistent handling.
     * Converts normalized coordinates (0.0-1.0) to logical pixel coordinates.
     *
     * Platform availability: Mobile (iOS/Android) and other touch-enabled platforms.
     * Not available on desktop platforms.
     *
     * @param x Normalized X coordinate (0.0 to 1.0)
     * @param y Normalized Y coordinate (0.0 to 1.0)
     * @param dx Touch pressure or force (not used)
     * @param dy Touch size or area (not used)
     * @param touchId Platform-specific touch identifier
     * @param timestamp Event timestamp in seconds
     */
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

    /**
     * Handles touch release events.
     * Automatically handles missing touchDown events by calling touchDown first.
     * Converts normalized coordinates to logical pixel coordinates and cleans up touch tracking.
     *
     * Platform availability: Mobile (iOS/Android) and other touch-enabled platforms.
     * Not available on desktop platforms.
     *
     * @param x Normalized X coordinate (0.0 to 1.0)
     * @param y Normalized Y coordinate (0.0 to 1.0)
     * @param dx Touch pressure or force (not used)
     * @param dy Touch size or area (not used)
     * @param touchId Platform-specific touch identifier
     * @param timestamp Event timestamp in seconds
     */
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

    /**
     * Handles touch movement events.
     * Automatically handles missing touchDown events by calling touchDown first.
     * Converts normalized coordinates to logical pixel coordinates.
     *
     * Platform availability: Mobile (iOS/Android) and other touch-enabled platforms.
     * Not available on desktop platforms.
     *
     * @param x Normalized X coordinate (0.0 to 1.0)
     * @param y Normalized Y coordinate (0.0 to 1.0)
     * @param dx Touch pressure or force (not used)
     * @param dy Touch size or area (not used)
     * @param touchId Platform-specific touch identifier
     * @param timestamp Event timestamp in seconds
     */
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

    /**
     * Handles keyboard key press events.
     * Emits both input events for game logic and text input events for text editing.
     * Supports key repeating when a key is held down.
     *
     * @param keyCode Virtual key code representing the key's logical meaning
     * @param scanCode Physical scan code representing the key's hardware position
     * @param repeat Whether this is a repeat event from holding the key down
     * @param mod Modifier key state (Shift, Ctrl, Alt, etc.)
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that received the event
     */
    override function keyDown(keyCode:KeyCode, scanCode:ScanCode, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        backend.input.emitKeyDown({
            keyCode: (keyCode:Int),
            scanCode: (scanCode:Int)
        });

        backend.textInput.handleKeyDown(keyCode, scanCode);

    }

    /**
     * Handles keyboard key release events.
     * Emits both input events for game logic and text input events for text editing.
     *
     * @param keyCode Virtual key code representing the key's logical meaning
     * @param scanCode Physical scan code representing the key's hardware position
     * @param repeat Should always be false for key up events
     * @param mod Modifier key state (Shift, Ctrl, Alt, etc.)
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that received the event
     */
    override function keyUp(keyCode:KeyCode, scanCode:ScanCode, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        backend.input.emitKeyUp({
            keyCode: (keyCode:Int),
            scanCode: (scanCode:Int)
        });

        backend.textInput.handleKeyUp(keyCode, scanCode);

    }

    /**
     * Configures gamepad-specific settings based on controller type.
     * Handles special cases like Nintendo controllers that need button swapping.
     * @param id Gamepad ID
     * @param name Gamepad name/identifier string
     */
    function _configureGamepad(id:Int, name:String) {

        #if !(ceramic_no_ab_swap && ceramic_no_xy_swap)
        if (name != null) {
            var lowerName = name.toLowerCase();
            if (#if web lowerName.indexOf(' vendor: 057e ') != -1 || lowerName.startsWith('057e-') || #end lowerName.contains('retroid pocket controller')) {
                // Nintendo controller on web, or retroid pocket, swap A & B buttons and X & Y buttons
                #if !ceramic_no_ab_swap
                swapAbGamepads.set(id, true);
                #end
                #if !ceramic_no_xy_swap
                swapXyGamepads.set(id, true);
                #end
            }
            else {
                #if !ceramic_no_ab_swap
                swapAbGamepads.set(id, false);
                #end
                #if !ceramic_no_xy_swap
                swapXyGamepads.set(id, false);
                #end
            }
        }
        else {
            #if !ceramic_no_ab_swap
            swapAbGamepads.set(id, false);
            #end
            #if !ceramic_no_xy_swap
            swapXyGamepads.set(id, false);
            #end
        }
        #end

    }

    /**
     * Handles gamepad analog stick and trigger movement events.
     * Auto-enables gamepads on first input. Converts triggers to button presses when value >= 0.5.
     * Rounds axis values to reduce noise and only emits events when values change meaningfully.
     *
     * Platform behavior:
     * - Desktop: Full gamepad support with axis-to-button mapping for triggers
     * - Web: Gamepad support with potential button remapping for Nintendo controllers
     * - iOS: Disabled by default
     *
     * @param id Gamepad device ID (0-3 typically)
     * @param axisId Axis identifier (0=left stick X, 1=left stick Y, 2=right stick X, etc.)
     * @param value Axis value from -1.0 to 1.0 (or 0.0 to 1.0 for triggers)
     * @param timestamp Event timestamp in seconds
     */
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
        backend.input.emitGamepadAxis(id, axisId, value);
        #end

    }

    /**
     * Handles gamepad button press events.
     * Auto-enables gamepads on first input and applies platform-specific button remapping.
     * Prevents duplicate button press events and handles Nintendo controller button swapping on web.
     *
     * Button mapping:
     * - Standard: 0=A, 1=B, 2=X, 3=Y, 4=LB, 5=RB, etc.
     * - Nintendo on Web: A/B and X/Y positions are swapped to match Nintendo layout
     * - SDL platforms: Uses custom mapping to match HTML5 gamepad API
     *
     * @param id Gamepad device ID (0-3 typically)
     * @param buttonId Physical button identifier from the platform
     * @param value Button pressure (0.0 to 1.0, usually 0.0 or 1.0 for digital buttons)
     * @param timestamp Event timestamp in seconds
     */
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

        #if !ceramic_no_ab_swap
        // Swap A & B button if needed
        if (buttonId == 0 || buttonId == 1) {
            if (swapAbGamepads.get(id)) {
                buttonId = (buttonId == 1) ? 0 : 1;
            }
        }
        #end

        #if !ceramic_no_xy_swap
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

    /**
     * Handles gamepad button release events.
     * Auto-enables gamepads on first input and applies the same button remapping as gamepadDown.
     * Only emits events for buttons that were previously pressed to prevent spurious releases.
     *
     * Uses identical button mapping logic to gamepadDown to ensure consistent behavior.
     *
     * @param id Gamepad device ID (0-3 typically)
     * @param buttonId Physical button identifier from the platform
     * @param value Button pressure (usually 0.0 for button release)
     * @param timestamp Event timestamp in seconds
     */
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

        #if !ceramic_no_ab_swap
        // Swap A & B button if needed
        if (buttonId == 0 || buttonId == 1) {
            if (swapAbGamepads.get(id)) {
                buttonId = (buttonId == 1) ? 0 : 1;
            }
        }
        #end

        #if !ceramic_no_xy_swap
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

    /**
     * Handles gamepad gyroscope/motion sensor events.
     * Auto-enables gamepads on first input and applies scaling to convert raw sensor data
     * to degrees per second. On web with native bridge, this is handled elsewhere.
     *
     * The scaling factor (360.0 / 1550.0) converts platform-specific gyro units
     * to standard degrees per second for consistent cross-platform behavior.
     *
     * Platform availability:
     * - Desktop: Gyro data from supported controllers (PS4, PS5, Switch Pro)
     * - Web: Available unless ceramic_native_bridge is used
     * - Mobile: Depends on controller support
     *
     * @param id Gamepad device ID
     * @param dx Gyro rotation rate around X-axis (raw platform units)
     * @param dy Gyro rotation rate around Y-axis (raw platform units)
     * @param dz Gyro rotation rate around Z-axis (raw platform units)
     * @param timestamp Event timestamp in seconds
     */
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

    /**
     * Handles gamepad connection and disconnection events.
     * Manages gamepad lifecycle including proper cleanup of pressed buttons on disconnect
     * and initialization of button state on connect. Uses temporary tracking to prevent
     * immediate re-detection of removed gamepads.
     *
     * When a gamepad is removed:
     * - All pressed buttons are released with gamepadUp events
     * - The gamepad is disabled and marked as temporarily removed
     * - Removal tracking is cleared on the next frame update
     *
     * When a gamepad is added:
     * - Button state is initialized to all unpressed
     * - Gamepad-specific configuration is applied (button swapping, etc.)
     * - The gamepad is enabled and ready for input
     *
     * @param id Gamepad device ID
     * @param name Gamepad name/identifier string for device detection
     * @param type Device event type (DEVICE_ADDED or DEVICE_REMOVED)
     * @param timestamp Event timestamp in seconds
     */
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

    /**
     * Handles text input events for text editing functionality.
     * Only processes text input when text input mode is active, allowing for
     * proper text editing in text fields while ignoring text when not needed.
     *
     * This is separate from keyboard events and provides the actual character input
     * including support for international keyboards, input methods, and composed text.
     *
     * @param text The text string that was input (may be multiple characters)
     * @param start Starting position for text editing (not used)
     * @param length Length of text selection/replacement (not used)
     * @param type Type of text event (input, editing, etc.)
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that received the event
     */
    override function text(text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, windowId:Int) {

        if (backend.textInput.inputActive) {
            backend.textInput.handleTextInput(text);
        }

    }

    /**
     * Handles window-related events such as focus changes, resize, and fullscreen transitions.
     * Most events are handled automatically by the Clay engine, but fullscreen state changes
     * need to be synchronized with the Ceramic app settings.
     *
     * Fullscreen events:
     * - ENTER_FULLSCREEN: Updates app settings to reflect fullscreen state
     * - EXIT_FULLSCREEN: Updates app settings to reflect windowed state
     *
     * Other events (SHOWN, HIDDEN, MINIMIZED, etc.) are currently not handled but
     * could be extended for application-specific window management needs.
     *
     * @param type The type of window event that occurred
     * @param timestamp Event timestamp in seconds
     * @param windowId ID of the window that generated the event
     * @param x X coordinate data (usage depends on event type)
     * @param y Y coordinate data (usage depends on event type)
     */
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
