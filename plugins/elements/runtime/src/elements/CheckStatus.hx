package elements;

import ceramic.Flags;

/**
 * Represents the status of a checkbox or toggle control with change tracking.
 * 
 * This abstract type efficiently packs both the checked state and whether
 * the state just changed into a single integer using bit flags:
 * - Bit 0: Whether the checkbox is checked
 * - Bit 1: Whether the state changed in the current frame
 * 
 * The type can be implicitly converted to Bool (returns true if changed),
 * making it convenient for change detection in conditionals.
 * 
 * Example usage:
 * ```haxe
 * var status:CheckStatus = getCheckboxStatus();
 * if (status) { // Implicitly checks if changed
 *     if (status.justChecked) {
 *         trace("Checkbox was just checked!");
 *     } else if (status.justUnchecked) {
 *         trace("Checkbox was just unchecked!");
 *     }
 * }
 * ```
 */
abstract CheckStatus(Int) from Int to Int {

    /**
     * Creates a new CheckStatus with the given bit flag value.
     * @param value The integer containing packed bit flags
     */
    inline public function new(value:Int) {
        this = value;
    }

    /**
     * Implicit conversion to Bool that returns true if the state changed.
     * Allows using CheckStatus directly in conditionals to detect changes.
     * @return True if the checked state changed, false otherwise
     */
    @:to inline public function toBool():Bool {
        return changed;
    }

    /**
     * Whether the checkbox is currently checked.
     * Reads bit 0 of the status flags.
     */
    public var checked(get,never):Bool;
    inline function get_checked():Bool {
        return Flags.fromInt(this).bool(0);
    }

    /**
     * Whether the checkbox was just checked in the current frame.
     * True when both changed is true and checked is true.
     */
    public var justChecked(get,never):Bool;
    inline function get_justChecked():Bool {
        return changed && checked;
    }

    /**
     * Whether the checkbox was just unchecked in the current frame.
     * True when changed is true but checked is false.
     */
    public var justUnchecked(get,never):Bool;
    inline function get_justUnchecked():Bool {
        return changed && !checked;
    }

    /**
     * Whether the checked state changed in the current frame.
     * Reads bit 1 of the status flags.
     */
    public var changed(get,never):Bool;
    inline function get_changed():Bool {
        return Flags.fromInt(this).bool(1);
    }

}