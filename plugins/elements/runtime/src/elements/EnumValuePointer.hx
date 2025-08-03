package elements;

/**
 * Type alias for enum value pointers in the elements UI system.
 * 
 * This type definition represents a pointer to any enum value, used for
 * generic enum handling in UI components where the specific enum type
 * is not known at compile time. It provides type-safe access to enum
 * values while maintaining flexibility for different enum types.
 * 
 * The actual implementation depends on the context where it's used,
 * typically following the same getter/setter pattern as other pointer
 * types but with enum-specific value handling.
 * 
 * Usage example:
 * ```haxe
 * enum Color {
 *     Red;
 *     Green;
 *     Blue;
 * }
 * 
 * var myColor = Color.Red;
 * var pointer:EnumValuePointer = myColor;
 * 
 * // Used in enum selection components
 * // that can work with any enum type
 * ```
 * 
 * @see EnumFieldView
 * @see FieldView
 */
typedef EnumValuePointer = Any;
