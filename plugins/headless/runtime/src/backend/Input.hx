package backend;

/**
 * Input system implementation for the headless backend.
 * 
 * This class provides event handling for keyboard and gamepad input
 * in the headless environment. While no actual input devices are
 * connected in headless mode, this maintains the event structure
 * for API compatibility.
 * 
 * Applications can still emit these events programmatically for
 * testing purposes or automated input simulation.
 */
class Input implements tracker.Events implements spec.Input {

    /**
     * Fired when a keyboard key is pressed down.
     * 
     * @param key The key that was pressed
     */
    @event function keyDown(key:ceramic.Key);
    
    /**
     * Fired when a keyboard key is released.
     * 
     * @param key The key that was released
     */
    @event function keyUp(key:ceramic.Key);

    /**
     * Fired when a gamepad axis value changes.
     * 
     * @param gamepadId The ID of the gamepad
     * @param axisId The ID of the axis that changed
     * @param value The new axis value (-1.0 to 1.0)
     */
    @event function gamepadAxis(gamepadId:Int, axisId:Int, value:Float);
    
    /**
     * Fired when a gamepad button is pressed down.
     * 
     * @param gamepadId The ID of the gamepad
     * @param buttonId The ID of the button that was pressed
     */
    @event function gamepadDown(gamepadId:Int, buttonId:Int);
    
    /**
     * Fired when a gamepad button is released.
     * 
     * @param gamepadId The ID of the gamepad
     * @param buttonId The ID of the button that was released
     */
    @event function gamepadUp(gamepadId:Int, buttonId:Int);
    
    /**
     * Fired when gamepad gyroscope data is received.
     * 
     * @param gamepadId The ID of the gamepad
     * @param dx Rotation around X axis
     * @param dy Rotation around Y axis
     * @param dz Rotation around Z axis
     */
    @event function gamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float);
    
    /**
     * Fired when a gamepad is connected.
     * 
     * @param gamepadId The ID of the connected gamepad
     * @param name The name of the gamepad
     */
    @event function gamepadEnable(gamepadId:Int, name:String);
    
    /**
     * Fired when a gamepad is disconnected.
     * 
     * @param gamepadId The ID of the disconnected gamepad
     */
    @event function gamepadDisable(gamepadId:Int);


    /**
     * Starts gamepad rumble/vibration.
     * 
     * In headless mode, this is a no-op since no physical gamepads are connected.
     * 
     * @param gamepadId The ID of the gamepad to rumble
     * @param lowFrequency Low frequency rumble intensity (0.0 to 1.0)
     * @param highFrequency High frequency rumble intensity (0.0 to 1.0)
     * @param duration Rumble duration in seconds
     */
    public function startGamepadRumble(gamepadId:Int, lowFrequency:Float, highFrequency:Float, duration:Float):Void {
        // not needed
    };

    /**
     * Stops gamepad rumble/vibration.
     * 
     * In headless mode, this is a no-op since no physical gamepads are connected.
     * 
     * @param gamepadId The ID of the gamepad to stop rumbling
     */
    public function stopGamepadRumble(gamepadId:Int): Void {
        // not needed
    };

    /**
     * Creates a new headless input system.
     */
    public function new() {

    }

}
