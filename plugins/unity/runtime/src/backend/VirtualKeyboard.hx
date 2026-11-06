package backend;

/**
 * A native virtual keyboard with its hidden text field, as `backend.TextInput`
 * uses it on iOS and Android (`UnityTouchScreenKeyboard`). Tests can give
 * `TextInput` another implementation to simulate a keyboard in batch mode.
 */
interface VirtualKeyboard {

    /**
     * Opens the keyboard (closing the previous one) with `text` in its field.
     */
    function open(text:String, type:ceramic.VirtualKeyboardType, autocorrect:Bool, multiline:Bool):Void;

    /** Closes the keyboard. */
    function close():Void;

    /** The text of the field, or null when the keyboard is closed. */
    function getText():Null<String>;

    /** Replaces the text of the field. */
    function setText(text:String):Void;

    /** Start of the selection in the field (UTF-16 code units), -1 when unknown. */
    function getSelectionStart():Int;

    /** Length of the selection in the field (UTF-16 code units). */
    function getSelectionLength():Int;

    /** Sets the selection of the field, where the platform allows it. */
    function setSelection(start:Int, length:Int):Void;

    /** What the keyboard is doing. */
    function getStatus():VirtualKeyboardStatus;

}
