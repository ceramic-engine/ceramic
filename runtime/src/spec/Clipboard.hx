package spec;

/**
 * Backend interface for system clipboard operations.
 * 
 * This interface provides access to the platform's clipboard for copy/paste functionality.
 * Currently supports text-only operations, though backends may extend this for other data types.
 * 
 * Clipboard access may require permissions on some platforms (e.g., web browsers) and
 * operations may fail silently if permissions are not granted.
 */
interface Clipboard {

    /**
     * Gets the current text content from the system clipboard.
     * @return The clipboard text content, or an empty string if the clipboard is empty
     *         or doesn't contain text data
     */
    function getText():String;

    /**
     * Sets text content to the system clipboard.
     * This replaces any existing clipboard content.
     * @param text The text to copy to the clipboard
     */
    function setText(text:String):Void;

}
