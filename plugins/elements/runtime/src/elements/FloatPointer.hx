package elements;

/**
 * Function type for accessing and modifying floating-point values by reference.
 * 
 * This type definition enables functional-style float value manipulation,
 * commonly used in the elements UI system for two-way data binding between
 * UI components and numeric data models.
 * 
 * @param val Optional new float value to set. When omitted, acts as a getter.
 * @return The current float value (after any modification)
 * 
 * Usage example:
 * ```haxe
 * var myFloat = 3.14;
 * var pointer:FloatPointer = (val) -> {
 *     if (val != null) myFloat = val;
 *     return myFloat;
 * };
 * 
 * // Read current value
 * var current = pointer();
 * 
 * // Set new value
 * pointer(2.71);
 * ```
 * 
 * @see NumberFieldView
 * @see SliderView
 * @see FieldView
 */
typedef FloatPointer = (?val:Float)->Float;
