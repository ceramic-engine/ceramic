package backend;

import clay.Clay;

/**
 * Clay backend input handling implementation.
 * 
 * This class provides the input event system for the Clay backend, handling:
 * - Keyboard input events (key presses and releases)
 * - Gamepad/controller input including analog sticks, buttons, and gyroscope
 * - Gamepad haptic feedback (rumble/vibration)
 * 
 * Input events are forwarded from the Clay runtime (SDL on native platforms)
 * and dispatched through Ceramic's event system. The backend supports multiple
 * simultaneous gamepads and provides normalized analog stick values.
 */
class Input implements tracker.Events implements spec.Input {

    /**
     * Fired when a keyboard key is pressed down.
     * @param key The key that was pressed, including both key code and scan code information
     */
    @event function keyDown(key:ceramic.Key);
    
    /**
     * Fired when a keyboard key is released.
     * @param key The key that was released, including both key code and scan code information
     */
    @event function keyUp(key:ceramic.Key);

    /**
     * Fired when a gamepad analog stick or trigger moves.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param axisId The axis identifier (e.g., 0=left stick X, 1=left stick Y)
     * @param value The normalized axis value, typically -1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers
     */
    @event function gamepadAxis(gamepadId:Int, axisId:Int, value:Float);
    
    /**
     * Fired when a gamepad button is pressed down.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param buttonId The button identifier (mapped to standard gamepad layout)
     */
    @event function gamepadDown(gamepadId:Int, buttonId:Int);
    
    /**
     * Fired when a gamepad button is released.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param buttonId The button identifier (mapped to standard gamepad layout)
     */
    @event function gamepadUp(gamepadId:Int, buttonId:Int);
    
    /**
     * Fired when gamepad gyroscope data is received (if supported by the controller).
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param dx Angular velocity around X axis (pitch) in degrees per second
     * @param dy Angular velocity around Y axis (yaw) in degrees per second
     * @param dz Angular velocity around Z axis (roll) in degrees per second
     */
    @event function gamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float);
    
    /**
     * Fired when a gamepad is connected and recognized.
     * @param gamepadId The ID assigned to the gamepad (0-based index)
     * @param name The name/description of the gamepad device
     */
    @event function gamepadEnable(gamepadId:Int, name:String);
    
    /**
     * Fired when a gamepad is disconnected.
     * @param gamepadId The ID of the disconnected gamepad
     */
    @event function gamepadDisable(gamepadId:Int);

    /**
     * Starts haptic feedback (rumble/vibration) on a gamepad.
     * 
     * Modern gamepads typically have two rumble motors:
     * - Low frequency motor: Creates a strong, rumbly vibration
     * - High frequency motor: Creates a weaker, buzzy vibration
     * 
     * @param gamepadId The ID of the gamepad to rumble
     * @param lowFrequency Intensity of the low frequency motor (0.0 to 1.0)
     * @param highFrequency Intensity of the high frequency motor (0.0 to 1.0)
     * @param duration Duration of the rumble effect in seconds (0 for infinite)
     */
    public function startGamepadRumble(gamepadId:Int, lowFrequency:Float, highFrequency:Float, duration:Float):Void {

        Clay.app.runtime.startGamepadRumble(gamepadId, lowFrequency, highFrequency, duration);

    };

    /**
     * Stops any active haptic feedback on a gamepad.
     * 
     * @param gamepadId The ID of the gamepad to stop rumbling
     */
    public function stopGamepadRumble(gamepadId:Int): Void {

        Clay.app.runtime.stopGamepadRumble(gamepadId);

    };

    /**
     * Creates a new Input backend instance.
     * Input events are automatically dispatched by the Clay runtime.
     */
    public function new() {

    }

}
