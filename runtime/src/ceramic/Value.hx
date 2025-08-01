package ceramic;

/**
 * An object that can hold any value.
 * 
 * This is a simple generic container class that wraps a single value of any type.
 * It's useful when you need a mutable reference to a value, particularly in contexts
 * where you want to pass a value by reference rather than by value.
 * 
 * Common use cases:
 * - Sharing mutable state between closures
 * - Returning multiple values from a function (using multiple Value objects)
 * - Creating observable values when combined with event systems
 * - Wrapping primitive types to make them nullable
 * 
 * Example usage:
 * ```haxe
 * // Basic usage
 * var counter = new Value<Int>(0);
 * counter.value++;
 * trace(counter.value); // 1
 * 
 * // Sharing state between functions
 * var shared = new Value<String>("Hello");
 * function updateValue() {
 *     shared.value = "World";
 * }
 * updateValue();
 * trace(shared.value); // "World"
 * 
 * // As a nullable wrapper
 * var maybeNumber = new Value<Float>();
 * if (someCondition) {
 *     maybeNumber.value = 42.0;
 * }
 * ```
 * 
 * @param T The type of value to store
 */
class Value<T> {

    /**
     * The stored value.
     * Can be read and written directly.
     */
    public var value:T;

    /**
     * Create a new Value container.
     * 
     * @param value The initial value to store (optional).
     *              If provided and not null, it will be stored.
     *              If not provided or null, the value property remains uninitialized.
     */
    public function new(?value:T) {

        if (value != null)
            this.value = value;

    }

}
