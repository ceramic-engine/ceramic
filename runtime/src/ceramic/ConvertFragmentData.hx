package ceramic;

/**
 * Converter for FragmentData fields in fragments and data serialization.
 * 
 * This converter provides a pass-through implementation for FragmentData,
 * as FragmentData is already a serializable format that doesn't require
 * conversion. The converter exists to maintain consistency in the fragment
 * system's field conversion architecture.
 * 
 * @see ConvertField
 * @see FragmentData
 * @see Fragment
 */
class ConvertFragmentData implements ConvertField<Dynamic,FragmentData> {

    /**
     * Create a new fragment data converter instance.
     */
    public function new() {}

    /**
     * Pass through the basic value as FragmentData without conversion.
     * 
     * Since FragmentData is already in a serializable format, no
     * transformation is needed.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param assets Assets instance for resource loading (unused)
     * @param basic The FragmentData value to pass through
     * @param done Callback invoked with the same FragmentData value
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Dynamic, done:FragmentData->Void):Void {

        done(basic);

    }

    /**
     * Pass through the FragmentData value without conversion.
     * 
     * Since FragmentData is already in a serializable format, no
     * transformation is needed.
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param value The FragmentData value to pass through
     * @return The same FragmentData value
     */
    public function fieldToBasic(instance:Entity, field:String, value:FragmentData):Dynamic {

        return value;

    }

}
