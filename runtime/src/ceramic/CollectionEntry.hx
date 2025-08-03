package ceramic;

import haxe.DynamicAccess;
import haxe.rtti.Meta;

using StringTools;
using ceramic.Extensions;

/**
 * Base class for entries that can be stored in a Collection.
 *
 * CollectionEntry provides:
 * - Automatic unique ID generation
 * - Runtime index for fast integer-based identification
 * - Flexible data deserialization from raw data (CSV, JSON, etc.)
 * - Type conversion for common data types
 *
 * When creating custom collection entries, extend this class and add
 * your specific fields. The FieldInfoMacro will automatically generate
 * type information for proper deserialization.
 *
 * Example usage:
 * ```haxe
 * class EnemyEntry extends CollectionEntry {
 *     public var health:Int = 100;
 *     public var damage:Float = 10.5;
 *     public var isFlying:Bool = false;
 *     public var enemyType:EnemyType; // Enum support
 * }
 *
 * // Create from raw data (e.g., from CSV)
 * var enemy = new EnemyEntry();
 * enemy.setRawData({
 *     id: "goblin1",
 *     health: "50",
 *     damage: "5.5",
 *     isFlying: "true",
 *     enemyType: "GOBLIN"
 * });
 * ```
 *
 * @see Collection
 * @see FieldInfo
 */
@:structInit
@:keep
@:keepSub
#if (!macro && !display && !completion)
@:autoBuild(ceramic.macros.FieldInfoMacro.build())
@:build(ceramic.macros.FieldInfoMacro.build())
#end
class CollectionEntry {

    /** Counter for auto-generated IDs */
    static var _nextId:Int = 1;

    /** Counter for unique runtime indices */
    static var _nextIndex:Int = 1;

    /**
     * Unique identifier for this entry.
     * Auto-generated if not provided in constructor.
     */
    public var id:String;

    /**
     * Optional human-readable name for this entry.
     */
    public var name:String;

    /**
     * A unique runtime index for this collection entry instance.
     *
     * Warning: This index is not persistent and will vary between app runs!
     * Use it only for fast runtime lookups, never for saving/loading data.
     * For persistent identification, use the 'id' field instead.
     */
    public var index(default,null):Int;

    /**
     * Creates a new CollectionEntry.
     * @param id Optional unique identifier (auto-generated if not provided)
     * @param name Optional human-readable name
     */
    public function new(?id:String, ?name:String) {

        this.index = (_nextIndex++);
        this.id = id != null ? id : 'id' + (_nextId++);
        this.name = name;

    }

    /**
     * Sets entry fields from raw data, with automatic type conversion.
     *
     * Supports conversion from strings (e.g., CSV data) to:
     * - Bool: "true"/"false", "yes"/"no", "1"/"0"
     * - Int: Numeric strings
     * - Float: Numeric strings (accepts comma as decimal separator)
     * - Color: Integer color values
     * - String: Any value (null becomes null)
     * - Enum: Case-insensitive enum constructor names
     *
     * Fields marked with @skipEmpty meta will be skipped if the raw value is null or empty.
     *
     * @param data Object containing field names and raw values
     */
    public function setRawData(data:Dynamic) {

        var clazz = Type.getClass(this);
        var classPath = Type.getClassName(clazz);
        var types = FieldInfo.types(classPath);

        for (key in types.keys()) {
            var type = types.get(key);

            if (Reflect.hasField(data, key)) {
                var rawValue:Dynamic = Reflect.field(data, key);
                var value:Dynamic = null;

                if (setRawField(key, rawValue)) continue;

                // Skip if field is empty or null
                if (FieldMeta.hasMeta(clazz, key, 'skipEmpty')) {
                    if (rawValue == null)
                        continue;
                    if (rawValue is String) {
                        var rawValueStr:String = rawValue;
                        if (rawValueStr.length == 0)
                            continue;
                    }
                }

                switch (type) {

                    case 'Bool':
                        if (Std.isOfType(rawValue, Bool)) {
                            value = rawValue;
                        }
                        else {
                            rawValue = (''+rawValue).toLowerCase().trim();
                            if (rawValue != '' && rawValue != '0' && rawValue != 'false' && rawValue != 'no') {
                                value = true;
                            } else {
                                value = false;
                            }
                        }

                    case 'Int', 'ceramic.Color':
                        if (Std.isOfType(rawValue, Int) || Std.isOfType(rawValue, Float)) {
                            value = Std.int(rawValue);
                        }
                        else {
                            value = Std.parseInt(''+rawValue);
                            if (value == null || Math.isNaN(value)) value = 0;
                        }

                    case 'Float':
                        if (Std.isOfType(rawValue, Int) || Std.isOfType(rawValue, Float)) {
                            value = rawValue;
                        }
                        else {
                            value = Std.parseFloat((''+rawValue).replace(',', '.'));
                            if (value == null || Math.isNaN(value)) value = 0.0;
                        }

                    case 'String':
                        value = rawValue == null || rawValue == 'null' ? null : ''+rawValue;

                    default:
                        var rawValue = (''+rawValue).toLowerCase().trim();
                        var resolvedEnum = Type.resolveEnum(type);
                        if (resolvedEnum != null) {
                            for (name in Type.getEnumConstructs(resolvedEnum)) {
                                if (name.toLowerCase() == rawValue) {
                                    value = Type.createEnum(resolvedEnum, name);
                                    break;
                                }
                            }
                        }
                }

                // Set field
                Reflect.setField(this, key, value);
            }
        }

    }

    /**
     * Override this method to handle custom field deserialization.
     *
     * Return true to skip default type conversion for the field.
     * Useful for complex types or custom parsing logic.
     *
     * @param name The field name
     * @param rawValue The raw value to process
     * @return True if field was handled, false to use default conversion
     */
    public function setRawField(name:String, rawValue:Dynamic):Bool {

        return false;

    }

}
