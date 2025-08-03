package backend;

#if !no_backend_docs
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
#end
class Clipboard implements spec.Clipboard {

    #if !no_backend_docs
    /**
     * Internal storage for clipboard text.
     * This persists clipboard data within the headless environment.
     */
    #end
    var clipboardText:String = null;

    #if !no_backend_docs
    /**
     * Creates a new headless clipboard system.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Gets the current text from the clipboard.
     * 
     * In headless mode, this returns the internally stored text
     * rather than accessing the system clipboard.
     * 
     * @return The current clipboard text, or null if none is set
     */
    #end
    public function getText():String {
        
        return clipboardText;

    }

    #if !no_backend_docs
    /**
     * Sets text to the clipboard.
     * 
     * In headless mode, this stores the text internally rather
     * than copying it to the system clipboard.
     * 
     * @param text The text to store in the clipboard
     */
    #end
    public function setText(text:String):Void {

        clipboardText = text;

    }

}
