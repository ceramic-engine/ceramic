package ceramic;

import haxe.DynamicAccess;

/**
 * Converter for Map fields in fragments and data serialization.
 * 
 * This converter handles Map<String,T> instances by converting between
 * DynamicAccess objects (JavaScript-style objects) and Haxe Map instances.
 * This allows maps to be serialized as plain objects in JSON and other
 * serialization formats.
 * 
 * @see ConvertField
 * @see Fragment
 */
class ConvertMap<T> implements ConvertField<DynamicAccess<T>,Map<String,T>> {

    /**
     * Create a new map converter instance.
     */
    public function new() {}

    /**
     * Convert a DynamicAccess object to a Map instance.
     * 
     * Iterates through all keys in the dynamic object and creates
     * corresponding entries in a new Map instance.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param assets Assets instance for resource loading (unused for maps)
     * @param basic The DynamicAccess object to convert
     * @param done Callback invoked with the converted Map instance
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:DynamicAccess<T>, done:Map<String,T>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new Map<String,T>();

        for (key in basic.keys()) {
            value.set(key, basic.get(key));
        }

        done(value);

    }

    /**
     * Convert a Map instance to a DynamicAccess object for serialization.
     * 
     * Iterates through all entries in the map and creates corresponding
     * properties in a new DynamicAccess object.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param value The Map instance to convert
     * @return A DynamicAccess object containing all map entries
     */
    public function fieldToBasic(instance:Entity, field:String, value:Map<String,T>):DynamicAccess<T> {

        if (value == null) return null;

        var basic:DynamicAccess<T> = {};

        for (key in value.keys()) {
            basic.set(key, value.get(key));
        }

        return basic;

    }

}
