package ceramic;

/**
 * Base class for the InputMap system.
 * 
 * This class provides the foundation for input mapping functionality,
 * extending Entity to integrate with Ceramic's entity system and event handling.
 * 
 * The actual implementation is provided by InputMapImpl, which is used by
 * the generic InputMap class.
 * 
 * @see InputMap
 * @see InputMapImpl
 */
class InputMapBase extends Entity  {

    /**
     * A placeholder value used to represent "no key" in generic input map implementations.
     * This allows the system to handle null values in a type-safe way across different
     * generic type parameters.
     */
    static final NO_KEY:Dynamic = null;

/// Lifecycle

    /**
     * Creates a new InputMapBase instance.
     * Should not be instantiated directly - use InputMap<T> instead.
     */
    public function new() {

        super();

    }

}
