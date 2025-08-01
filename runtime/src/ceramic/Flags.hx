package ceramic;

/**
 * Efficient bit flag storage using a single integer.
 * 
 * The Flags abstract provides a type-safe way to store and manipulate boolean
 * flags using bit operations. Each bit in the underlying integer represents
 * a boolean value, allowing up to 32 flags to be stored in a single Int.
 * 
 * This is particularly useful for:
 * - Storing multiple boolean states efficiently
 * - Passing multiple boolean parameters compactly
 * - Optimizing memory usage in data structures
 * - Creating bit masks for filtering operations
 * 
 * Example:
 * ```haxe
 * var flags = new Flags();
 * flags.setBool(0, true);  // Set first flag
 * flags.setBool(2, true);  // Set third flag
 * 
 * if (flags.bool(0)) {
 *     trace("First flag is set");
 * }
 * 
 * // Create flags from values
 * var flags2 = Flags.fromValues(true, false, true); // bits: 101
 * ```
 * 
 * @see ceramic.scriptable.ScriptableFlags
 */
abstract Flags(Int) from Int to Int {

    /**
     * Creates a new Flags instance with all bits set to 0 (false).
     */
    inline public function new() {

        this = 0;

    }

    /**
     * Converts the flags to their integer representation.
     * 
     * @return The underlying integer value
     */
    inline public function toInt():Int {
        return this;
    }

    /**
     * Creates a Flags instance from an integer value.
     * 
     * @param value The integer containing the bit flags
     * @return A Flags instance wrapping the integer
     */
    inline public static function fromInt(value:Int):Flags {
        return value;
    }

    /**
     * Checks if a specific bit (flag) is set.
     * 
     * @param bit The bit position to check (0-31)
     * @return True if the bit is set, false otherwise
     */
    inline public function bool(bit:Int):Bool {

        var mask = 1 << bit;
        return this & mask == mask;

    }

    /**
     * Sets or clears a specific bit (flag).
     * 
     * @param bit The bit position to modify (0-31)
     * @param bool The value to set (true sets the bit, false clears it)
     * @return The value that was set
     */
    inline public function setBool(bit:Int, bool:Bool):Bool {

        this = bool ? this | (1 << bit) : this & ~(1 << bit);
        return bool;

    }

    /**
     * Static method to check if a specific bit is set in a Flags instance.
     * 
     * @param flags The Flags instance to check
     * @param bit The bit position to check (0-31)
     * @return True if the bit is set, false otherwise
     */
    inline public static function getBool(flags:Flags, bit:Int):Bool {

        return flags.bool(bit);

    }

    /**
     * Sets a bit in a Flags instance and returns the modified flags as an integer.
     * 
     * This is useful for chaining operations or when you need the integer result.
     * 
     * @param flags The Flags instance to modify
     * @param bit The bit position to set (0-31)
     * @param bool The value to set
     * @return The modified flags as an integer
     */
    inline public static function setBoolAndGetFlags(flags:Flags, bit:Int, bool:Bool):Int {

        flags.setBool(bit, bool);
        return flags;

    }

    /**
     * Creates a Flags instance from boolean values (1 flag).
     * 
     * @param flag0 Value for bit 0
     * @return Flags instance with the specified bits set
     */
    inline public static extern overload function fromValues(flag0:Bool):Flags {
        return _fromValues(flag0, false, false, false, false, false, false, false);
    }

    /**
     * Creates a Flags instance from boolean values (2 flags).
     * 
     * @param flag0 Value for bit 0
     * @param flag1 Value for bit 1
     * @return Flags instance with the specified bits set
     */
    inline public static extern overload function fromValues(flag0:Bool, flag1:Bool):Flags {
        return _fromValues(flag0, flag1, false, false, false, false, false, false);
    }

    inline public static extern overload function fromValues(flag0:Bool, flag1:Bool, flag2:Bool):Flags {
        return _fromValues(flag0, flag1, flag2, false, false, false, false, false);
    }

    inline public static extern overload function fromValues(flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, false, false, false, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, false, false, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, flag5, false, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool, flag6:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, flag5, flag6, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool, flag6:Bool, flag7:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, flag5, flag6, flag7);
    }

    /**
     * Internal implementation for creating flags from boolean values.
     * 
     * Sets bits 0-7 based on the provided boolean values.
     */
    inline static function _fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool, flag6:Bool, flag7:Bool
    ):Flags {

        var flags:Flags = 0;
        if (flag0)
            flags.setBool(0, flag0);
        if (flag1)
            flags.setBool(1, flag1);
        if (flag2)
            flags.setBool(2, flag2);
        if (flag3)
            flags.setBool(3, flag3);
        if (flag4)
            flags.setBool(4, flag4);
        if (flag5)
            flags.setBool(5, flag5);
        if (flag6)
            flags.setBool(6, flag6);
        if (flag7)
            flags.setBool(7, flag7);
        return flags;

    }

}
