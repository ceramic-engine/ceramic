package ceramic.scriptable;

/**
 * Scriptable wrapper for Flags to expose bit flag operations to scripts.
 *
 * This class provides utility methods for working with bit flags, which are
 * commonly used to store multiple boolean values in a single integer.
 * In scripts, this type is exposed as `Flags` (without the Scriptable prefix).
 *
 * Bit flags allow efficient storage of up to 32 boolean values in a single
 * integer, where each bit position represents a different flag.
 *
 * ## Usage in Scripts
 *
 * ```haxe
 * // Define flag positions as constants
 * var FLAG_ACTIVE = 0;      // Bit 0
 * var FLAG_VISIBLE = 1;     // Bit 1
 * var FLAG_ENABLED = 2;     // Bit 2
 *
 * // Start with no flags set
 * var flags = 0;
 *
 * // Set the ACTIVE flag to true
 * flags = Flags.setBoolAndGetFlags(flags, FLAG_ACTIVE, true);
 *
 * // Set multiple flags
 * flags = Flags.setBoolAndGetFlags(flags, FLAG_VISIBLE, true);
 * flags = Flags.setBoolAndGetFlags(flags, FLAG_ENABLED, false);
 *
 * // Check if a flag is set
 * if (Flags.getBool(flags, FLAG_ACTIVE)) {
 *     trace("Object is active");
 * }
 *
 * // Toggle a flag
 * var isVisible = Flags.getBool(flags, FLAG_VISIBLE);
 * flags = Flags.setBoolAndGetFlags(flags, FLAG_VISIBLE, !isVisible);
 * ```
 *
 * ## Bit Positions
 *
 * - Bit 0: Rightmost bit, value 1
 * - Bit 1: Second bit, value 2
 * - Bit 2: Third bit, value 4
 * - And so on up to bit 31
 *
 * @see ceramic.Flags The actual implementation
 */
class ScriptableFlags {

    /**
     * Check if a specific bit flag is set.
     *
     * @param flags The integer containing the bit flags
     * @param bit The bit position to check (0-31)
     * @return True if the bit is set (1), false if not set (0)
     */
    public static function getBool(flags:Int, bit:Int):Bool {

        var mask = 1 << bit;
        return flags & mask == mask;

    }

    /**
     * Set or clear a specific bit flag and return the updated flags value.
     *
     * This method does not modify the input flags parameter, but returns
     * a new integer with the specified bit updated.
     *
     * @param flags The integer containing the bit flags
     * @param bit The bit position to modify (0-31)
     * @param bool True to set the bit (1), false to clear it (0)
     * @return The updated flags value with the bit modified
     */
    public static function setBoolAndGetFlags(flags:Int, bit:Int, bool:Bool):Int {

        flags = bool ? flags | (1 << bit) : flags & ~(1 << bit);
        return flags;

    }

}