package backend;

#if !no_backend_docs
/**
 * Text input implementation for the headless backend.
 * 
 * This class provides text input functionality for forms and UI elements
 * in the headless environment. Since there's no user interface in headless
 * mode, all methods are implemented as no-ops.
 * 
 * This maintains API compatibility for applications that use text input
 * controls, allowing them to run in headless environments without errors.
 */
#end
class TextInput implements spec.TextInput {

    #if !no_backend_docs
    /**
     * Creates a new headless text input system.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Starts text input with the specified initial text and bounds.
     * 
     * In headless mode, this is a no-op since no text input UI is available.
     * 
     * @param initialText The initial text to display
     * @param x X position of the input area
     * @param y Y position of the input area
     * @param w Width of the input area
     * @param h Height of the input area
     */
    #end
    public function start(initialText:String, x:Float, y:Float, w:Float, h:Float):Void {}

    #if !no_backend_docs
    /**
     * Stops text input and hides the input UI.
     * 
     * In headless mode, this is a no-op since no text input UI exists.
     */
    #end
    public function stop():Void {}

}
