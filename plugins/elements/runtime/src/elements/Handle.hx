package elements;

/**
 * A type alias for integer handles used throughout the Elements UI framework.
 * 
 * Handles are used as lightweight references to UI elements, resources, or
 * other objects that need to be identified by a unique integer value.
 * This pattern is commonly used for:
 * - Window management systems
 * - Resource tracking
 * - Event system identifiers
 * - Component registration
 * 
 * Using a typedef allows the code to be more self-documenting, as `Handle`
 * is more meaningful than raw `Int` values in function signatures.
 */
typedef Handle = Int;
