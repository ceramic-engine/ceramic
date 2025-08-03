package backend;

#if !no_backend_docs
/**
 * Unity implementation of the clipboard interface.
 * 
 * Currently provides a simple in-memory clipboard implementation
 * that stores text within the application. This is a placeholder
 * implementation that doesn't interact with the system clipboard.
 * 
 * Limitations:
 * - Text is not shared with the system clipboard
 * - Copy/paste only works within the application
 * - Clipboard content is lost when the app closes
 * 
 * Future improvements could use Unity's GUIUtility.systemCopyBuffer
 * or platform-specific clipboard APIs for true system integration.
 * 
 * @see spec.Clipboard The interface this class implements
 * @see backend.Backend Provides this clipboard instance
 */
#end
class Clipboard implements spec.Clipboard {

    #if !no_backend_docs
    /**
     * Internal storage for clipboard text.
     * Only accessible within this application instance.
     */
    #end
    var clipboardText:String = null;

    #if !no_backend_docs
    /**
     * Creates a new clipboard instance.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Gets the current clipboard text.
     * Returns the text previously set with setText(), or null if none.
     * 
     * @return The clipboard text, or null if empty
     */
    #end
    public function getText():String {
        
        return clipboardText;

    }

    #if !no_backend_docs
    /**
     * Sets the clipboard text.
     * The text is only stored in memory and not shared with the system.
     * 
     * @param text The text to store in the clipboard
     */
    #end
    public function setText(text:String):Void {

        clipboardText = text;

    }

}
