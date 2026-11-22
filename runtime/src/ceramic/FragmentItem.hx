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
     * Optional id of another item of the same fragment. When both items
     * are visuals, this one is displayed inside the other one
     * (it becomes one of its children) instead of the fragment itself.
     * Items can be listed in any order.
     */
    @:optional var parent:String;

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
     * `width` and `height` are always set last.
     *
     * For an item of class `ceramic.Fragment`, `fragmentData` is either
     * the data of the fragment or the id of another fragment.
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
     * If not provided, types come from the `schema` of the fragment,
     * then from reflection (`ceramic_entity_field_info`).
     */
    @:optional var schema:Dynamic<String>;

}

