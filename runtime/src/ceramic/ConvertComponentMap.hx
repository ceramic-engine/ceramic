package ceramic;

import ceramic.Shortcuts.*;

import haxe.DynamicAccess;

/**
 * Converter for component map fields in fragments and data serialization.
 * 
 * This converter handles maps of Component instances by storing and restoring
 * them using component initializer names. Components are instantiated from
 * registered initializers during deserialization, allowing fragments to 
 * declaratively specify which components an entity should have.
 * 
 * Note: This system requires the ceramic_use_component_initializers flag to be
 * enabled for full functionality.
 * 
 * @see ConvertField
 * @see Component
 * @see Fragment
 */
class ConvertComponentMap implements ConvertField<DynamicAccess<String>,Map<String,Component>> {

    /**
     * Create a new component map converter instance.
     */
    public function new() {}

    /**
     * Convert a basic object mapping component names to initializer names
     * into a map of actual Component instances.
     * 
     * Each entry in the basic object maps a component name (key) to a
     * component initializer name (value). The initializer is looked up
     * in the app's component initializers registry and used to create
     * a new component instance.
     * 
     * @param instance The entity that will own these components
     * @param field The name of the field being converted
     * @param assets Assets instance for resource loading (unused for components)
     * @param basic Object mapping component names to initializer names
     * @param done Callback invoked with the map of instantiated components
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:DynamicAccess<String>, done:Map<String,Component>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new Map<String,Component>();

        for (name in basic.keys()) {
            // TODO extract arguments from value instead of treating it as initializer name directly
            var initializerName = basic.get(name);

            #if ceramic_use_component_initializers
            if (app.componentInitializers.exists(initializerName)) {
                var component = app.componentInitializers.get(initializerName)([]);
                if (component != null) {
                    @:privateAccess component.initializerName = initializerName;
                    value.set(name, component);
                }
            }
            #if debug
            else {
                log.warning('Missing component initializer: ' + initializerName);
            }
            #end
            #else
            log.error('Not using component initializers anymore. Need to implement event based solution!');
            #end
        }

        done(value);

    }

    /**
     * Convert a map of Component instances to a basic object for serialization.
     * 
     * Only components that have an initializer name are included in the
     * serialized output. The resulting object maps component names to their
     * initializer names, allowing them to be recreated later.
     * 
     * @param instance The entity that owns these components
     * @param field The name of the field being converted
     * @param value Map of component instances to serialize
     * @return Object mapping component names to initializer names
     */
    public function fieldToBasic(instance:Entity, field:String, value:Map<String,Component>):DynamicAccess<String> {

        if (value == null) return null;

        var basic:DynamicAccess<String> = {};

        for (name in value.keys()) {
            var component = value.get(name);
            if (component != null && component.initializerName != null) {
                basic.set(name, component.initializerName);
            }
        }

        return basic;

    }

}
