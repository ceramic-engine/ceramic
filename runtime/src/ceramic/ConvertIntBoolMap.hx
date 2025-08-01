package ceramic;

import ceramic.Shortcuts.*;

/**
 * Converter for IntBoolMap fields in fragments and data serialization.
 * 
 * This converter handles IntBoolMap instances by converting between
 * object representations and the specialized integer-to-boolean map.
 * Includes special handling for Spine plugin's hiddenSlots field where
 * slot names are converted to indices.
 * 
 * Note: The fieldToBasic conversion is currently not implemented and
 * will log a warning if used.
 * 
 * @see ConvertField
 * @see IntBoolMap
 * @see Fragment
 */
class ConvertIntBoolMap implements ConvertField<Dynamic,IntBoolMap> {

    /**
     * Create a new IntBoolMap converter instance.
     */
    public function new() {}

    /**
     * Convert a basic object to an IntBoolMap instance.
     * 
     * The basic object should have string keys (representing integers)
     * mapped to boolean values. Special handling is provided for Spine
     * plugin's hiddenSlots field where slot names are converted to indices.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param assets Assets instance for resource loading (unused)
     * @param basic Object with string keys and boolean values
     * @param done Callback invoked with the converted IntBoolMap
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Dynamic, done:IntBoolMap->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new IntBoolMap();
        
        #if plugin_spine
        // Specific case for Spine's hiddenSlots field
        // Converts slot names to slot indices
        if (Std.isOfType(instance, Spine) && field == 'hiddenSlots') {
            var spine:Spine = cast instance;
            for (key in Reflect.fields(basic)) {
                var boolVal:Bool = Reflect.field(basic, key);
                var slotIndex = Spine.globalSlotIndexForName(key);
                value.set(slotIndex, boolVal);
            }
            done(value);
            return;
        }
        #end
        
        // Standard conversion: parse string keys as integers
        for (key in Reflect.fields(basic)) {
            value.set(Std.parseInt(key), Reflect.field(basic, key));
        }

        done(value);

    }

    /**
     * Convert an IntBoolMap to a basic object for serialization.
     * 
     * WARNING: This method is not yet implemented and will log a warning.
     * The implementation should iterate through the map and create an
     * object with string keys representing the integer indices.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param value The IntBoolMap to convert
     * @return An empty object (method not implemented)
     */
    public function fieldToBasic(instance:Entity, field:String, value:IntBoolMap):Dynamic {

        if (value == null) return null;

        var basic:Dynamic = {};

        // TODO: Implement proper serialization
        log.warning('ConvertIntBoolMap.fieldToBasic() not implemented!');

        return basic;

    }

}
