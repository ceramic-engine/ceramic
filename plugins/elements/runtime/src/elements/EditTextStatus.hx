package elements;

import ceramic.Flags;

/**
 * Represents the status of text editing operations using bit flags.
 * 
 * This abstract type efficiently encodes multiple boolean states related to
 * text field interactions. It tracks whether the text has changed, was
 * submitted (e.g., by pressing Enter), or lost focus (blurred).
 * 
 * The status can be implicitly converted to Bool, returning true if the
 * text has changed.
 * 
 * Bit layout:
 * - Bit 0: changed - Text content has been modified
 * - Bit 1: submitted - User pressed Enter or similar submit action
 * - Bit 2: blurred - Text field lost focus
 * 
 * Example usage:
 * ```haxe
 * var status = textField.getStatus();
 * if (status.changed) {
 *     saveChanges();
 * }
 * if (status.submitted) {
 *     processSubmission();
 * }
 * ```
 * 
 * @see TextFieldView For text input fields
 * @see BaseTextFieldView For autocomplete text fields
 */
abstract EditTextStatus(Int) from Int to Int {

    /**
     * Creates a new EditTextStatus with the specified bit flags.
     * @param value Integer containing the bit flags
     */
    inline public function new(value:Int) {
        this = value;
    }

    /**
     * Converts this status to a boolean value.
     * @return True if the text has changed
     */
    @:to inline public function toBool():Bool {
        return changed;
    }

    /**
     * Whether the text content has been modified.
     * Checks bit 0 of the status flags.
     */
    public var changed(get,never):Bool;
    inline function get_changed():Bool {
        return Flags.fromInt(this).bool(0);
    }

    /**
     * Whether the text was submitted (e.g., Enter pressed).
     * Checks bit 1 of the status flags.
     */
    public var submitted(get,never):Bool;
    inline function get_submitted():Bool {
        return Flags.fromInt(this).bool(1);
    }

    /**
     * Whether the text field lost focus (blurred).
     * Checks bit 2 of the status flags.
     */
    public var blurred(get,never):Bool;
    inline function get_blurred():Bool {
        return Flags.fromInt(this).bool(2);
    }

}