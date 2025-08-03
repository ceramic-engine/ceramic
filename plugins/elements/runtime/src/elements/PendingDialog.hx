package elements;

import tracker.Model;

/**
 * Model representing a pending dialog box with user interaction.
 * 
 * PendingDialog manages the state and configuration of modal dialogs,
 * including alert dialogs, confirmation dialogs, and prompt dialogs.
 * It tracks user interaction results and provides callback mechanisms
 * for handling user responses.
 * 
 * Features:
 * - Multiple choice support with custom button labels
 * - Optional text input with prompt functionality
 * - Cancelable dialogs with escape handling
 * - Configurable dimensions and styling
 * - Async operation support
 * - Callback-based result handling
 * - Unique key identification for dialog management
 * 
 * Example usage:
 * ```haxe
 * var dialog = new PendingDialog(
 *     "confirm_delete",
 *     "Confirm Delete",
 *     "Are you sure you want to delete this item?",
 *     false, null, null,
 *     ["Cancel", "Delete"],
 *     true, -1, -1, true,
 *     (index, text) -> {
 *         if (index == 1) {
 *             // User clicked Delete
 *         }
 *     }
 * );
 * ```
 * 
 * @see StringPointer
 * @see Im
 */
class PendingDialog extends Model {

    /** Index of the chosen button (-1 if none chosen yet) */
    public var chosenIndex:Int = -1;

    /** Whether the dialog was canceled (typically via Escape key) */
    public var canceled:Bool = false;

    /** Pointer to the prompt text input value (for prompt dialogs) */
    public var promptPointer:StringPointer;

    /** Placeholder text for the prompt input field */
    public var promptPlaceholder:String;

    /** Unique identifier for this dialog instance */
    public var key:String;

    /** Title text displayed in the dialog header */
    public var title:String;

    /** Main message text displayed in the dialog body */
    public var message:String;

    /** Array of button labels for user choices */
    public var choices:Array<String>;

    /** Whether the dialog can be canceled (e.g., with Escape key) */
    public var cancelable:Bool;

    /** Fixed width of the dialog (-1 for auto-sizing) */
    public var width:Float;

    /** Fixed height of the dialog (-1 for auto-sizing) */
    public var height:Float;

    /** Whether the dialog operates asynchronously */
    public var async:Bool;

    /** Callback function called when user makes a choice */
    public var callback:(index:Int, text:String)->Void;

    /** Internal storage for prompt value when no pointer is provided */
    var _promptValue:String;

    /**
     * Creates a new PendingDialog instance.
     * 
     * Configures all dialog properties and sets up prompt functionality if needed.
     * If prompt is enabled but no promptPointer is provided, creates an internal
     * string pointer for managing the prompt value.
     * 
     * @param key Optional unique identifier for the dialog
     * @param title Title text for the dialog header
     * @param message Main message text for the dialog body
     * @param prompt Whether to include a text input prompt
     * @param promptPointer Optional string pointer for prompt value binding
     * @param promptPlaceholder Placeholder text for the prompt input
     * @param choices Array of button labels for user choices
     * @param cancelable Whether the dialog can be canceled
     * @param width Fixed width (-1 for auto-sizing)
     * @param height Fixed height (-1 for auto-sizing)
     * @param async Whether the dialog operates asynchronously
     * @param callback Function called when user makes a choice
     */
    public function new(?key:String, title:String, message:String, prompt:Bool = false, ?promptPointer:StringPointer, ?promptPlaceholder:String, choices:Array<String>, cancelable:Bool = false, width:Float = -1, height:Float = -1, async:Bool, callback:(index:Int, text:String)->Void) {

        super();

        this.key = key;
        this.title = title;
        this.message = message;
        if (prompt) {
            if (promptPointer == null) {
                _promptValue = '';
                promptPointer = Im.string(_promptValue);
            }
            this.promptPointer = promptPointer;
            this.promptPlaceholder = promptPlaceholder;
        }
        this.choices = choices;
        this.async = async;
        this.callback = callback;
        this.cancelable = cancelable;
        this.width = width;
        this.height = height;

    }

    /**
     * Cleans up dialog resources when destroyed.
     * 
     * Clears references to strings, arrays, and callback functions
     * to prevent memory leaks and ensure proper garbage collection.
     */
    override function destroy() {

        this.title = null;
        this.message = null;
        this.choices = null;
        this.callback = null;

        super.destroy();

    }

}
