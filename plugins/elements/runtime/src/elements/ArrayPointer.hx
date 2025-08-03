package elements;

/**
 * Function type for accessing and manipulating arrays by reference.
 * 
 * This type definition allows passing arrays between UI elements and field systems
 * in a functional way, where the array can be both read and written.
 * 
 * @param val Optional new array value to set. When provided, replaces the current array.
 * @param erase Optional flag to clear/reset the array. When true, empties the array.
 * @return The current array value (after any modifications)
 * 
 * Usage example:
 * ```haxe
 * var myArray = [1, 2, 3];
 * var pointer:ArrayPointer = (val, erase) -> {
 *     if (erase) myArray = [];
 *     else if (val != null) myArray = val;
 *     return myArray;
 * };
 * 
 * // Read current value
 * var current = pointer();
 * 
 * // Set new value
 * pointer([4, 5, 6]);
 * 
 * // Clear array
 * pointer(null, true);
 * ```
 */
typedef ArrayPointer = (?val:Array<Dynamic>,?erase:Bool)->Array<Dynamic>;
