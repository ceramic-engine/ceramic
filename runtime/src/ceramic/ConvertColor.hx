package ceramic;

import ceramic.Shortcuts.*;

/**
 * Converter for Color fields in fragments and data serialization.
 * 
 * This converter handles Color values by supporting both string representations
 * (like "#FF0000" or "red") and numeric values (0xFFRRGGBB). The conversion
 * behavior can be controlled via the `preferStringBasic` property.
 * 
 * @see ConvertField
 * @see Color
 * @see Fragment
 */
class ConvertColor implements ConvertField<Any,Color> {

    /**
     * When true, colors are serialized as web strings (e.g., "#FF0000").
     * When false, colors are serialized as numeric values (default).
     */
    public var preferStringBasic:Bool = false;

    /**
     * Create a new color converter instance.
     */
    public function new() {}

    /**
     * Convert a basic value (string or number) to a Color instance.
     * 
     * Supports multiple input formats:
     * - String: Web color strings like "#FF0000", "rgb(255,0,0)", or named colors like "red"
     * - Number: Integer color values in 0xRRGGBB format
     * - null: Returns Color.BLACK as default
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param assets Assets instance for resource loading (unused for colors)
     * @param basic The source value to convert (string or number)
     * @param done Callback invoked with the converted Color instance
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Any, done:Color->Void):Void {

        if (basic != null) {
            if (basic is String) {
                done(Color.fromString(basic));
            }
            else {
                done(Std.int(basic));
            }
        }
        else {
            done(Color.BLACK);
        }

    }

    /**
     * Convert a Color instance to a basic value for serialization.
     * 
     * The output format depends on the `preferStringBasic` property:
     * - If true: Returns a web color string like "#FF0000"
     * - If false: Returns the numeric color value
     * 
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param value The Color instance to convert
     * @return Either a web color string or numeric value
     */
    public function fieldToBasic(instance:Entity, field:String, value:Color):Any {

        return preferStringBasic ? value.toWebString() : value;

    }

}
