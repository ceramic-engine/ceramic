package elements;

import ceramic.Flags;

/**
 * Represents the status of an informational dialog or notification.
 * 
 * This abstract type encodes the dialog's state as an integer:
 * - `-2`: Dialog was canceled
 * - `-1`: Dialog is still pending/incomplete
 * - `0`: Dialog completed successfully
 * - Other values: Custom status codes
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var status = new InfoStatus(-1); // Pending
 * 
 * if (!status.complete) {
 *     // Dialog still open
 * }
 * 
 * if (status.canceled) {
 *     // User canceled the dialog
 * }
 * 
 * if (status) { // toBool() returns true for value 0
 *     // Dialog completed successfully
 * }
 * ```
 */
abstract InfoStatus(Int) from Int to Int {

    /**
     * Creates a new InfoStatus with the specified value.
     * @param value The status value (-2 for canceled, -1 for pending, 0 for success)
     */
    inline public function new(value:Int) {
        this = value;
    }

    /**
     * Converts the status to boolean.
     * @return `true` if the status is 0 (success), `false` otherwise
     */
    @:to inline public function toBool():Bool {
        return this == 0;
    }

    /**
     * Whether the dialog was canceled by the user.
     * True when status value is -2.
     */
    public var canceled(get,never):Bool;
    inline function get_canceled():Bool {
        return this == -2;
    }

    /**
     * Whether the dialog has completed (either successfully or canceled).
     * False only when status is -1 (pending).
     */
    public var complete(get,never):Bool;
    inline function get_complete():Bool {
        return this != -1;
    }

}