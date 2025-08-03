package elements;

import ceramic.Flags;

/**
 * Represents the status of a choice selection with special states.
 * 
 * This abstract type encodes choice selection results as integers:
 * - Values >= 0: The index of the selected choice
 * - Value -1: No selection made yet (pending)
 * - Value -2: Selection was canceled
 * 
 * The type can be implicitly converted to Bool (returns true if a valid choice was made),
 * making it convenient for checking if a selection was successful.
 * 
 * Example usage:
 * ```haxe
 * var status:ChoiceStatus = showChoiceDialog();
 * if (status) { // Implicitly checks if a valid choice was made
 *     trace("Selected option: " + status.index);
 * } else if (status.canceled) {
 *     trace("User canceled the selection");
 * }
 * ```
 * 
 * @see ListStatus
 * @see ConfirmStatus
 */
abstract ChoiceStatus(Int) from Int to Int {

    /**
     * Creates a new ChoiceStatus with the given value.
     * @param value The status value (-2 for canceled, -1 for pending, >= 0 for choice index)
     */
    inline public function new(value:Int) {
        this = value;
    }

    /**
     * Implicit conversion to Bool that returns true if a valid choice was made.
     * @return True if index >= 0 (a valid choice was selected), false otherwise
     */
    @:to inline public function toBool():Bool {
        return this >= 0;
    }

    /**
     * The index of the selected choice.
     * Returns -1 if no valid choice was made (pending or canceled).
     * For valid selections, returns the zero-based index of the chosen option.
     */
    public var index(get,never):Int;
    inline function get_index():Int {
        return this >= 0 ? this : -1;
    }

    /**
     * Whether the choice selection was canceled by the user.
     * True when the status value is -2.
     */
    public var canceled(get,never):Bool;
    inline function get_canceled():Bool {
        return this == -2;
    }

    /**
     * Whether the choice selection process is complete.
     * True when either a choice was made or the selection was canceled.
     * False only when the status is pending (-1).
     */
    public var complete(get,never):Bool;
    inline function get_complete():Bool {
        return this != -1;
    }

}