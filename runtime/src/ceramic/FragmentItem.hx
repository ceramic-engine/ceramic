package ceramic;

/**
 * Defines an entity instance within a fragment.
 * Each FragmentItem describes what type of entity to create
 * and how to configure it with properties and components.
 * 
 * FragmentItems are the building blocks of fragments, allowing
 * data-driven instantiation of any Entity subclass with:
 * - Initial property values
 * - Component attachments
 * - Unique identification
 * - Custom metadata
 * 
 * @see Fragment
 * @see FragmentData
 * @see Entity
 */
typedef FragmentItem = {

    /**
     * Fully qualified class name of the entity to instantiate.
     * Examples: "ceramic.Quad", "ceramic.Text", "ceramic.Fragment"
     * The class must extend ceramic.Entity.
     */
    var entity:String;

    /**
     * Unique identifier for this entity instance within the fragment.
     * Used to reference the entity in timeline tracks and from code.
     */
    var id:String;

    /**
     * Components to attach to this entity after creation.
     * Keys are component names, values are component type names or data.
     * Components are processed after all other properties are set.
     */
    var components:Dynamic<String>;

    /**
     * Optional human-readable name for this entity.
     * Can be used for debugging or as an alternative way to find entities.
     */
    @:optional var name:String;

    /**
     * Property values to set on the entity after instantiation.
     * Keys are property names, values are the property values.
     * Properties are set in the order defined by the entity class.
     */
    var props:Dynamic<Dynamic>;

    /**
     * Optional arbitrary data attached to this item.
     * Copied to the entity's data property if available.
     * Useful for storing custom metadata or configuration.
     */
    @:optional var data:Dynamic<Dynamic>;

    /**
     * Optional type information for entity properties.
     * Maps property names to their type strings.
     * Used by the fragment system to properly convert values.
     * If not provided, types are resolved via reflection.
     */
    @:optional var schema:Dynamic<String>;

}

