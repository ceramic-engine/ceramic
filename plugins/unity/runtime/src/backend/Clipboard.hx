package backend;

#if !no_backend_docs
/**
 * Unity implementation of the clipboard interface.
 *
 * Text goes through `GUIUtility.systemCopyBuffer`, the system clipboard in
 * the editor and in desktop players. Where it is not available (it throws,
 * or the platform has no clipboard), the text stays in memory and is only
 * shared within the app.
 *
 * @see spec.Clipboard The interface this class implements
 * @see backend.Backend Provides this clipboard instance
 */
#end
class Clipboard implements spec.Clipboard {

    #if !no_backend_docs
    /**
     * Text of the last `setText()`, returned when the system clipboard
     * cannot be read.
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
     * Gets the text of the system clipboard (an empty string when it holds
     * no text), or the text of the last `setText()` when the system
     * clipboard cannot be read.
     *
     * @return The clipboard text
     */
    #end
    public function getText():String {

        try {
            final text:String = untyped __cs__('UnityEngine.GUIUtility.systemCopyBuffer');
            return text != null ? text : '';
        }
        catch (e:Dynamic) {
            return clipboardText;
        }

    }

    #if !no_backend_docs
    /**
     * Sets the text of the system clipboard (and keeps it in memory, in case
     * the system clipboard cannot be read).
     *
     * @param text The text to store in the clipboard
     */
    #end
    public function setText(text:String):Void {

        clipboardText = text;
        try {
            untyped __cs__('UnityEngine.GUIUtility.systemCopyBuffer = {0}', text != null ? text : '');
        }
        catch (e:Dynamic) {}

    }

}
