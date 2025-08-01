package ceramic;

import haxe.DynamicAccess;

/**
 * Converter for array fields in fragments and data serialization.
 * 
 * This converter handles array types by creating deep copies to ensure
 * data integrity between the original and converted values. Used by the
 * fragment system to convert between serialized array data and runtime
 * array instances.
 * 
 * @see ConvertField
 * @see Fragment
 */
class ConvertArray<T> implements ConvertField<Array<T>,Array<T>> {

    /**
     * Create a new array converter instance.
     */
    public function new() {}

    /**
     * Convert a basic array to a field array by creating a deep copy.
     * 
     * This method ensures that the field instance has its own array
     * that won't be affected by changes to the original basic array.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param assets Assets instance for resource loading (unused for arrays)
     * @param basic The source array to convert
     * @param done Callback invoked with the converted array copy
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Array<T>, done:Array<T>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value:Array<T> = [];
        value = value.concat(basic);

        done(value);

    }

    /**
     * Convert a field array to a basic array by creating a deep copy.
     * 
     * This method ensures that the serialized data has its own array
     * that won't be affected by changes to the field array.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param value The field array to convert
     * @return A new array containing copies of all elements
     */
    public function fieldToBasic(instance:Entity, field:String, value:Array<T>):Array<T> {

        if (value == null) return null;

        var basic:Array<T> = [];
        basic = basic.concat(value);

        return basic;

    }

}
