package elements;

import ceramic.Flags;

/**
 * Abstract type for tracking the completion status of prompt dialogs.
 * 
 * PromptStatus provides a type-safe way to represent and check the state
 * of prompt dialogs, including whether they are pending, completed, or canceled.
 * It uses integer values internally with specific meanings:
 * 
 * - Negative values indicate special states (-1 = pending, -2 = canceled)
 * - Zero or positive values indicate completion with the chosen button index
 * 
 * The type provides implicit conversion to Bool, returning true when the
 * prompt is complete (not pending).
 * 
 * Example usage:
 * ```haxe
 * var status:PromptStatus = -1; // Pending
 * if (status.complete) {
 *     // Handle completion
 * }
 * if (status.canceled) {
 *     // Handle cancellation
 * }
 * if (status) {
 *     // Equivalent to status.complete
 * }
 * ```
 * 
 * @see PendingDialog
 */
abstract PromptStatus(Int) from Int to Int {

    /**
     * Creates a new PromptStatus with the specified value.
     * 
     * @param value The status value (-1 = pending, -2 = canceled, >=0 = completed)
     */
    inline public function new(value:Int) {
        this = value;
    }

    /**
     * Implicit conversion to Bool indicating completion status.
     * 
     * @return `true` if the prompt is complete (value >= 0), `false` if pending
     */
    @:to inline public function toBool():Bool {
        return this >= 0;
    }

    /**
     * Indicates whether the prompt was canceled.
     * 
     * @return `true` if the prompt was canceled, `false` otherwise
     */
    public var canceled(get,never):Bool;
    inline function get_canceled():Bool {
        return this == -2;
    }

    /**
     * Indicates whether the prompt is complete (either chosen or canceled).
     * 
     * @return `true` if the prompt is not pending, `false` if still pending
     */
    public var complete(get,never):Bool;
    inline function get_complete():Bool {
        return this != -1;
    }

}