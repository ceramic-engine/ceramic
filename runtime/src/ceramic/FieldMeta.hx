package ceramic;

import haxe.rtti.Meta;

/**
 * Runtime reflection utility for accessing field metadata.
 * 
 * This class provides methods to query metadata annotations on fields at runtime.
 * In Haxe, metadata (annotations starting with @) can be attached to fields, methods,
 * and classes at compile time. This utility leverages Haxe's RTTI (Runtime Type
 * Information) system to access that metadata at runtime.
 * 
 * The class maintains internal caches for performance and supports both recursive
 * (including parent classes) and non-recursive metadata lookup.
 * 
 * Common use cases include:
 * - Checking if a field has specific metadata annotations
 * - Retrieving metadata values for serialization/deserialization
 * - Implementing custom binding or validation systems
 * 
 * Example:
 * ```haxe
 * @serialize
 * @range(0, 100)
 * public var health:Float = 100;
 * 
 * // At runtime:
 * var hasSer = FieldMeta.hasMeta(Player, "health", "serialize"); // true
 * var meta = FieldMeta.getMeta(Player, "health");
 * var range = meta.get("range"); // [0, 100]
 * ```
 * 
 * @see haxe.rtti.Meta
 */
class FieldMeta {

    /**
     * Cache for non-recursive metadata lookups.
     * Structure: className -> fieldName -> metaName -> metaValue
     */
    static var metaMap:Map<String,Map<String,Map<String,Dynamic>>> = new Map();

    /**
     * Cache for recursive metadata lookups (including parent classes).
     * Structure: className -> fieldName -> metaName -> metaValue
     */
    static var metaMapRecursive:Map<String,Map<String,Map<String,Dynamic>>> = new Map();

    /**
     * Checks if a field has a specific metadata annotation (class-based overload).
     * 
     * @param clazz The class containing the field
     * @param field The name of the field to check
     * @param meta The metadata name to look for
     * @param recursive Whether to include parent classes in the search (default: true)
     * @return True if the field has the specified metadata
     */
    extern inline overload public static function hasMeta(clazz:Class<Dynamic>, field:String, meta:String, recursive:Bool = true):Bool {

        var targetClass = Type.getClassName(clazz);
        return _hasMeta(clazz, targetClass, field, meta, recursive);

    }

    /**
     * Checks if a field has a specific metadata annotation (string-based overload).
     * 
     * @param targetClass The fully qualified class name containing the field
     * @param field The name of the field to check
     * @param meta The metadata name to look for
     * @param recursive Whether to include parent classes in the search (default: true)
     * @return True if the field has the specified metadata
     */
    extern inline overload public static function hasMeta(targetClass:String, field:String, meta:String, recursive:Bool = true):Bool {

        var clazz = Type.resolveClass(targetClass);
        return _hasMeta(clazz, targetClass, field, meta, recursive);

    }

    /**
     * Internal implementation for checking field metadata.
     */
    static function _hasMeta(clazz:Class<Dynamic>, targetClass:String, field:String, meta:String, recursive:Bool):Bool {

        var allMeta = _getMeta(clazz, targetClass, field, recursive);
        return allMeta != null ? allMeta.exists(meta) : false;

    }

    /**
     * Retrieves all metadata for a field (class-based overload).
     * 
     * Returns a map containing all metadata annotations and their values for the
     * specified field. The map keys are metadata names and values are the metadata
     * parameters (if any).
     * 
     * @param clazz The class containing the field
     * @param field The name of the field to get metadata for
     * @param recursive Whether to include parent classes in the search (default: true)
     * @return A read-only map of metadata names to values, or null if field not found
     */
    extern inline overload public static function getMeta(clazz:Class<Dynamic>, field:String, recursive:Bool = true):ReadOnlyMap<String,Dynamic> {

        var targetClass = Type.getClassName(clazz);
        return _getMeta(clazz, targetClass, field, recursive);

    }

    /**
     * Retrieves all metadata for a field (string-based overload).
     * 
     * Returns a map containing all metadata annotations and their values for the
     * specified field. The map keys are metadata names and values are the metadata
     * parameters (if any).
     * 
     * @param targetClass The fully qualified class name containing the field
     * @param field The name of the field to get metadata for
     * @param recursive Whether to include parent classes in the search (default: true)
     * @return A read-only map of metadata names to values, or null if field not found
     */
    extern inline overload public static function getMeta(targetClass:String, field:String, recursive:Bool = true):ReadOnlyMap<String,Dynamic> {

        var clazz = Type.resolveClass(targetClass);
        return _getMeta(clazz, targetClass, field, recursive);

    }

    /**
     * Internal implementation for retrieving field metadata.
     * 
     * This method handles the actual metadata extraction and caching logic. It walks
     * the class hierarchy if recursive is true, collecting metadata from all parent
     * classes. Results are cached for performance.
     */
    static function _getMeta(clazz:Class<Dynamic>, targetClass:String, field:String, recursive:Bool):ReadOnlyMap<String,Dynamic> {

        var metaMapForClass:Map<String,Map<String,Dynamic>> = null;
        var metaMap = recursive ? FieldMeta.metaMapRecursive : FieldMeta.metaMap;
        if (metaMap.exists(targetClass)) {
            metaMapForClass = metaMap.get(targetClass);
        }
        else {
            metaMapForClass = new Map();

            while (clazz != null) {

                var info = Meta.getFields(clazz);
                if (info != null) {
                    for (fieldName in Reflect.fields(info)) {
                        var computedMeta = metaMapForClass.get(fieldName);
                        if (computedMeta == null) {
                            computedMeta = new Map();
                            metaMapForClass.set(fieldName, computedMeta);
                        }
                        var fieldMeta:Dynamic = Reflect.field(info, fieldName);
                        if (fieldMeta != null) {
                            for (metaName in Reflect.fields(fieldMeta)) {
                                if (!computedMeta.exists(metaName)) {
                                    computedMeta.set(metaName, Reflect.field(fieldMeta, metaName));
                                }
                            }
                        }
                    }
                }

                if (!recursive)
                    break;

                clazz = Type.getSuperClass(clazz);

            }

            metaMap.set(targetClass, metaMapForClass);
        }

        if (metaMapForClass.exists(field)) {
            return cast metaMapForClass.get(field);
        }
        else {
            return null;
        }

    }

}