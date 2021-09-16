package ceramic;

/**
 * A Component is and Entity that can be bound to another Entity.
 * Any Entity can be used as a Component, given that it implement Component interface.
 * A Component must be an Entity subclass.
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
