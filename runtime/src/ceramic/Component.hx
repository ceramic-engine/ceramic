package ceramic;

/**
 * Interface for components that can be attached to entities.
 * 
 * A Component is an Entity that can be bound to another Entity, enabling
 * composition-based architecture. Components are automatically managed by
 * their parent entity and destroyed when the parent is destroyed.
 * 
 * Any Entity subclass can be used as a Component by implementing this interface.
 * The ComponentMacro will automatically add required fields and methods.
 * 
 * Example usage:
 * ```haxe
 * class MyComponent extends Entity implements Component {
 *     function bindAsComponent() {
 *         // Initialize component when attached to entity
 *     }
 * }
 * 
 * // Attach to entity
 * entity.component('myComp', new MyComponent());
 * ```
 */
#if !macro
@:autoBuild(ceramic.macros.ComponentMacro.build())
#end
@:keep
@:keepSub
interface Component /* extends Entity (enforced by ComponentMacro) */ {

    /**
     * If this component was created from an initializer,
     * its initializer name is provided to retrieve the
     * initializer from the component.
     * This field is automatically added to implementing class by ComponentMacro
     */
    var initializerName(default,null):String;

    // If implementing class doesn't provide an `entity` field or a field marked with `@entity`,
    // it is automatically added by ComponentMacro with name `entity` and type `ceramic.Entity`

    /**
     * Called by target entity to assign itself to the component
     * @param entity
     */
    private function setEntity(entity:Entity):Void;

    /**
     * Called to retrieve entity in a generic way that works with all components
     */
    private function getEntity():Entity;

    /**
     * Called when the component is bound to an entity. At this stage, the `entity` property
     * should be assigned and work properly. Use this method to run initialization code once
     * the component has been plugged to a target entity.
     * When the target entity is destroyed, our instance (the component) will be unbound and destroyed as well.
     */
    private function bindAsComponent():Void;

}
