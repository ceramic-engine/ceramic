package elements;

/**
 * Function type for accessing and modifying boolean values by reference.
 * 
 * This type definition enables functional-style boolean value manipulation,
 * commonly used in the elements UI system for two-way data binding between
 * UI components and data models.
 * 
 * @param val Optional new boolean value to set. When omitted, acts as a getter.
 * @return The current boolean value (after any modification)
 * 
 * Usage example:
 * ```haxe
 * var myBool = true;
 * var pointer:BoolPointer = (val) -> {
 *     if (val != null) myBool = val;
 *     return myBool;
 * };
 * 
 * // Read current value
 * var current = pointer();
 * 
 * // Set new value
 * pointer(false);
 * ```
 * 
 * @see BooleanFieldView
 * @see FieldView
 */
typedef BoolPointer = (?val:Bool)->Bool;
