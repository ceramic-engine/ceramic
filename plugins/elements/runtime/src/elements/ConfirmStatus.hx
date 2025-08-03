package elements;

import ceramic.Flags;

/**
 * Represents the status of a confirmation dialog or action.
 * 
 * This abstract type encodes different states using integer values:
 * - Positive values (>= 0): Custom confirmation with index
 * - 0: Standard confirmation
 * - -1: Pending/incomplete state
 * - -2: Canceled state
 * 
 * Can be implicitly converted to Bool (true when confirmed).
 * 
 * @see PromptStatus For text input dialogs
 * @see ListStatus For list selection dialogs
 */
abstract ConfirmStatus(Int) from Int to Int {

    /**
     * Creates a new ConfirmStatus with the specified value.
     * @param value The status value (-2: canceled, -1: pending, 0: confirmed, >0: custom index)
     */
    inline public function new(value:Int) {
        this = value;
    }

    /**
     * Converts this status to a boolean value.
     * @return True if the status is confirmed (value == 0)
     */
    @:to inline public function toBool():Bool {
        return confirmed;
    }

    /**
     * The index of a custom confirmation choice.
     * Returns -1 if not a positive index (canceled or standard confirmation).
     */
    public var index(get,never):Int;
    inline function get_index():Int {
        return this >= 0 ? this : -1;
    }

    /**
     * Whether this represents a confirmed action.
     * True when the value is exactly 0 (standard confirmation).
     */
    public var confirmed(get,never):Bool;
    inline function get_confirmed():Bool {
        return this == 0;
    }

    /**
     * Whether this represents a canceled action.
     * True when the value is -2.
     */
    public var canceled(get,never):Bool;
    inline function get_canceled():Bool {
        return this == -2;
    }

    /**
     * Whether the status is complete (either confirmed or canceled).
     * False only when the value is -1 (pending state).
     */
    public var complete(get,never):Bool;
    inline function get_complete():Bool {
        return this != -1;
    }

}