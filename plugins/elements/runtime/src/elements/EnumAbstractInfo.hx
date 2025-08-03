package elements;

/**
 * Runtime information container for enum abstract types.
 * 
 * This class provides runtime introspection capabilities for Haxe enum abstracts,
 * allowing dynamic access to enum field names and their corresponding values.
 * It's particularly useful in UI components that need to display or manipulate
 * enum values dynamically, such as dropdown selects or enum field editors.
 * 
 * The class maintains two parallel arrays:
 * - `enumFields`: Contains the string names of enum fields
 * - `enumValues`: Contains the actual values associated with each field
 * 
 * Example usage:
 * ```haxe
 * // For an enum abstract like:
 * // enum abstract MyEnum(Int) {
 * //     var OPTION_A = 1;
 * //     var OPTION_B = 2;
 * // }
 * 
 * var info = new EnumAbstractInfo(
 *     ["OPTION_A", "OPTION_B"],
 *     [1, 2]
 * );
 * 
 * var fieldName = info.getEnumFieldFromValue(2); // Returns "OPTION_B"
 * var value = info.createEnumValue("OPTION_A"); // Returns 1
 * ```
 * 
 * @see EnumValuePointer for usage in field binding
 */
class EnumAbstractInfo {

    /**
     * Array of enum field names as strings.
     * The order corresponds to the order in enumValues.
     */
    var enumFields:Array<String>;

    /**
     * Array of enum values corresponding to each field.
     * The order corresponds to the order in enumFields.
     */
    var enumValues:Array<Dynamic>;

    /**
     * Creates a new EnumAbstractInfo instance.
     * 
     * @param enumFields Array of enum field names (e.g., ["OPTION_A", "OPTION_B"])
     * @param enumValues Array of corresponding values (e.g., [1, 2])
     */
    public function new(enumFields:Array<String>, enumValues:Array<Dynamic>) {
        this.enumFields = enumFields;
        this.enumValues = enumValues;
    }

    /**
     * Returns all available enum field names.
     * 
     * @return Array of enum field names as strings
     */
    inline public function getEnumFields() {
        return enumFields;
    }

    /**
     * Finds the enum field name corresponding to a given value.
     * 
     * This method performs a reverse lookup, finding the field name
     * that matches the provided value.
     * 
     * @param value The enum value to look up
     * @return The field name if found, null otherwise
     */
    inline public function getEnumFieldFromValue(value:Dynamic) {
        if (value == null)
            return null;
        var index = enumValues.indexOf(value);
        if (index < 0)
            return null;
        return enumFields[index];
    }

    /**
     * Creates an enum value from its field name.
     * 
     * This method looks up the value associated with the given field name.
     * It's useful for converting string representations back to enum values.
     * 
     * @param name The enum field name to look up
     * @return The corresponding enum value if found, null otherwise
     */
    public function createEnumValue(name:String):Dynamic {
        if (name == null)
            return null;
        var index = enumFields.indexOf(name);
        if (index < 0)
            return null;
        return enumValues[index];
    }

}
