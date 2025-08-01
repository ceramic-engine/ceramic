package ceramic;

import ceramic.ReadOnlyMap;
import haxe.DynamicAccess;

/**
 * Runtime reflection utility for extracting field type information from classes.
 * 
 * This class provides a way to retrieve type information about fields at runtime,
 * which is normally lost due to Haxe's type erasure. It works with Entity subclasses
 * marked with `@fieldInfo` or `@autoFieldInfo` metadata, or any class processed by
 * the FieldInfoMacro build macro.
 * 
 * The field information is extracted from a special `_fieldInfo` static field that
 * is generated at compile time by the FieldInfoMacro. This allows for runtime
 * introspection of field types, which is useful for serialization, binding systems,
 * and dynamic property manipulation.
 * 
 * @see ceramic.macros.FieldInfoMacro
 * @see ceramic.Entity
 */
class FieldInfo {

    /**
     * Cache of field type information for each class.
     * Key: class name, Value: map of field names to type strings
     */
    static var fieldInfoMap:Map<String,Map<String,String>> = new Map();

    /**
     * Retrieves a map of field names to their type information for a given class.
     * 
     * This method extracts field type information that was generated at compile time
     * by the FieldInfoMacro. The information is cached after the first retrieval for
     * performance.
     * 
     * Example:
     * ```haxe
     * var types = FieldInfo.types("myapp.Player");
     * trace(types.get("health")); // "Float"
     * trace(types.get("name")); // "String"
     * ```
     * 
     * @param targetClass The fully qualified class name to extract field info from
     * @param recursive Whether to include fields from parent classes (default: true)
     * @return A read-only map of field names to their type strings
     * @throws If the target class doesn't have field info and recursive is false
     */
    public static function types(targetClass:String, recursive:Bool = true):ReadOnlyMap<String,String> {

        var info = fieldInfoMap.get(targetClass);

        if (info == null) {
            info = new Map();
            fieldInfoMap.set(targetClass, info);

            var clazz = Type.resolveClass(targetClass);
            var firstTry = true;

            while (clazz != null) {

                var storedFieldInfo:DynamicAccess<Dynamic> = Reflect.field(clazz, '_fieldInfo');
                Assert.assert(storedFieldInfo != null || !firstTry, 'Missing _fieldInfo on class $targetClass');
                firstTry = false;

                if (storedFieldInfo != null) {
                    for (key => val in storedFieldInfo) {
                        if (!info.exists(key))
                            info.set(key, val.type);
                    }
                }

                if (!recursive)
                    break;

                clazz = Type.getSuperClass(clazz);

            }
        }

        return cast info;

    }

    /**
     * Gets the type information for a specific field of a class.
     * 
     * This is a convenience method that retrieves the type of a single field
     * without having to access the full types map.
     * 
     * Example:
     * ```haxe
     * var healthType = FieldInfo.typeOf("myapp.Player", "health");
     * trace(healthType); // "Float"
     * ```
     * 
     * @param targetClass The fully qualified class name containing the field
     * @param field The name of the field to get type information for
     * @return The type string for the field, or null if the field doesn't exist
     */
    public static function typeOf(targetClass:String, field:String):String {

        return types(targetClass).get(field);

    }

}
