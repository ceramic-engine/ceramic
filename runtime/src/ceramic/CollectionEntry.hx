package ceramic;

import haxe.DynamicAccess;
import haxe.rtti.Meta;

using StringTools;
using ceramic.Extensions;

@:structInit
@:keep
@:keepSub
#if (!macro && !display && !completion)
@:autoBuild(ceramic.macros.FieldInfoMacro.build())
@:build(ceramic.macros.FieldInfoMacro.build())
#end
class CollectionEntry {

    static var _nextId:Int = 1;

    static var _nextIndex:Int = 1;

    public var id:String;

    public var name:String;

    /**
     * A unique index for this collection entry instance.
     * Warning:
     *     this index is in no way predictable and may vary
     *     for each entry between each run of the app!
     *     This is intended to be used as a fast integer-typed runtime identifier,
     *     but do not use this to identify entries when persisting data to disk etc...
     */
    public var index(default,null):Int;

    /**
     * Constructor
     */
    public function new(?id:String, ?name:String) {

        this.index = (_nextIndex++);
        this.id = id != null ? id : 'id' + (_nextId++);
        this.name = name;

    }

    /**
     * Set entry fields from given raw data.
     * Takes care of converting types when needed, and possible.
     * It's ok if raw field are strings, like when stored in CSV files.
     * Raw types can be converted to: `Bool`, `Int`, `Float`, `Color` (`Int`), `String` and `enum` types
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
     * Override this method to perform custom deserialisation on a specific field. If the overrided method
     * returns `true`, default behavior will be skipped for the related field.
     */
    public function setRawField(name:String, rawValue:Dynamic):Bool {

        return false;

    }

}
