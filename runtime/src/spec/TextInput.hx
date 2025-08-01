package spec;

/**
 * Backend interface for system text input handling.
 * 
 * This interface manages platform-specific text input methods including
 * virtual keyboards on mobile devices and IME (Input Method Editor) support
 * for international text entry.
 * 
 * When text input is started, the backend should show the appropriate
 * input UI (virtual keyboard, IME window, etc.) and send text events
 * to the application. The position and size parameters help the platform
 * position the input UI appropriately.
 * 
 * Text input events are dispatched through the App's event system.
 */
interface TextInput {

    /**
     * Starts text input mode with the system input method.
     * 
     * This typically shows a virtual keyboard on mobile devices or
     * activates the IME on desktop platforms. The position parameters
     * help the system avoid covering the input field with the keyboard.
     * 
     * @param initialText The initial text to display in the input field
     * @param x The X position of the input field in screen coordinates
     * @param y The Y position of the input field in screen coordinates
     * @param w The width of the input field
     * @param h The height of the input field
     */
    function start(initialText:String, x:Float, y:Float, w:Float, h:Float):Void;

    /**
     * Stops text input mode and hides the system input method.
     * 
     * This hides the virtual keyboard or deactivates the IME.
     * Should be called when text input is no longer needed.
     */
    function stop():Void;

}
