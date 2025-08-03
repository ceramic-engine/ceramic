package backend;

#if !no_backend_docs
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
#end
class Input implements tracker.Events implements spec.Input {

    #if !no_backend_docs
    /**
     * Fired when a keyboard key is pressed down.
     * 
     * @param key The key that was pressed
     */
    #end
    @event function keyDown(key:ceramic.Key);
    
    #if !no_backend_docs
    /**
     * Fired when a keyboard key is released.
     * 
     * @param key The key that was released
     */
    #end
    @event function keyUp(key:ceramic.Key);

    #if !no_backend_docs
    /**
     * Fired when a gamepad axis value changes.
     * 
     * @param gamepadId The ID of the gamepad
     * @param axisId The ID of the axis that changed
     * @param value The new axis value (-1.0 to 1.0)
     */
    #end
    @event function gamepadAxis(gamepadId:Int, axisId:Int, value:Float);
    
    #if !no_backend_docs
    /**
     * Fired when a gamepad button is pressed down.
     * 
     * @param gamepadId The ID of the gamepad
     * @param buttonId The ID of the button that was pressed
     */
    #end
    @event function gamepadDown(gamepadId:Int, buttonId:Int);
    
    #if !no_backend_docs
    /**
     * Fired when a gamepad button is released.
     * 
     * @param gamepadId The ID of the gamepad
     * @param buttonId The ID of the button that was released
     */
    #end
    @event function gamepadUp(gamepadId:Int, buttonId:Int);
    
    #if !no_backend_docs
    /**
     * Fired when gamepad gyroscope data is received.
     * 
     * @param gamepadId The ID of the gamepad
     * @param dx Rotation around X axis
     * @param dy Rotation around Y axis
     * @param dz Rotation around Z axis
     */
    #end
    @event function gamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float);
    
    #if !no_backend_docs
    /**
     * Fired when a gamepad is connected.
     * 
     * @param gamepadId The ID of the connected gamepad
     * @param name The name of the gamepad
     */
    #end
    @event function gamepadEnable(gamepadId:Int, name:String);
    
    #if !no_backend_docs
    /**
     * Fired when a gamepad is disconnected.
     * 
     * @param gamepadId The ID of the disconnected gamepad
     */
    #end
    @event function gamepadDisable(gamepadId:Int);


    #if !no_backend_docs
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
    #end
    public function startGamepadRumble(gamepadId:Int, lowFrequency:Float, highFrequency:Float, duration:Float):Void {
        // not needed
    };

    #if !no_backend_docs
    /**
     * Stops gamepad rumble/vibration.
     * 
     * In headless mode, this is a no-op since no physical gamepads are connected.
     * 
     * @param gamepadId The ID of the gamepad to stop rumbling
     */
    #end
    public function stopGamepadRumble(gamepadId:Int): Void {
        // not needed
    };

    #if !no_backend_docs
    /**
     * Creates a new headless input system.
     */
    #end
    public function new() {

    }

}
