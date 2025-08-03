package backend;

/**
 * Clipboard implementation for the headless backend.
 * 
 * This class provides clipboard functionality for copy/paste operations
 * in the headless environment. Since there's no system clipboard access
 * in headless mode, this maintains an internal clipboard state.
 * 
 * This allows applications to use clipboard operations without errors,
 * with the clipboard data persisting within the application session.
 */
class Clipboard implements spec.Clipboard {

    /**
     * Internal storage for clipboard text.
     * This persists clipboard data within the headless environment.
     */
    var clipboardText:String = null;

    /**
     * Creates a new headless clipboard system.
     */
    public function new() {}

    /**
     * Gets the current text from the clipboard.
     * 
     * In headless mode, this returns the internally stored text
     * rather than accessing the system clipboard.
     * 
     * @return The current clipboard text, or null if none is set
     */
    public function getText():String {
        
        return clipboardText;

    }

    /**
     * Sets text to the clipboard.
     * 
     * In headless mode, this stores the text internally rather
     * than copying it to the system clipboard.
     * 
     * @param text The text to store in the clipboard
     */
    public function setText(text:String):Void {

        clipboardText = text;

    }

}
