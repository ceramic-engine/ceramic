package elements;

/**
 * Function type for accessing and modifying string values by reference.
 * 
 * This type definition enables functional-style string value manipulation,
 * commonly used in the elements UI system for two-way data binding between
 * UI components and text data models. Unlike other pointer types, this includes
 * an additional erase parameter for special text operations.
 * 
 * @param val Optional new string value to set. When omitted, acts as a getter.
 * @param erase Optional flag to indicate text erasure operation (implementation-specific).
 * @return The current string value (after any modification)
 * 
 * Usage example:
 * ```haxe
 * var myString = "Hello";
 * var pointer:StringPointer = (val, erase) -> {
 *     if (val != null) myString = val;
 *     // Handle erase operation if needed
 *     if (erase == true) myString = "";
 *     return myString;
 * };
 * 
 * // Read current value
 * var current = pointer();
 * 
 * // Set new value
 * pointer("World");
 * 
 * // Erase content
 * pointer(null, true);
 * ```
 * 
 * @see TextFieldView
 * @see FieldView
 */
typedef StringPointer = (?val:String,?erase:Bool)->String;
