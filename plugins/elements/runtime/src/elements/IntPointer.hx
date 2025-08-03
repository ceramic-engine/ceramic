package elements;

/**
 * Function type for accessing and modifying integer values by reference.
 * 
 * This type definition enables functional-style integer value manipulation,
 * commonly used in the elements UI system for two-way data binding between
 * UI components and numeric data models.
 * 
 * @param val Optional new integer value to set. When omitted, acts as a getter.
 * @return The current integer value (after any modification)
 * 
 * Usage example:
 * ```haxe
 * var myInt = 42;
 * var pointer:IntPointer = (val) -> {
 *     if (val != null) myInt = val;
 *     return myInt;
 * };
 * 
 * // Read current value
 * var current = pointer();
 * 
 * // Set new value
 * pointer(100);
 * ```
 * 
 * @see NumberFieldView
 * @see SliderView
 * @see FieldView
 */
typedef IntPointer = (?val:Int)->Int;
