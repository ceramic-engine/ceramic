package ceramic;

import haxe.DynamicAccess;

using ceramic.Extensions;
using StringTools;

@:rtti
@:structInit
class CollectionEntry {

    static var _nextId:Int = 1;

    @editable
    public var id:String;

    @editable
    public var name:String;

    /** Constructor */
    public function new(?id:String, ?name:String) {

        this.id = id != null ? id : 'id' + (_nextId++);
        this.name = name;

    } //new

    /** Set entry fields from given raw data.
        Takes care of converting types when needed, and possible.
        It's ok if raw field are strings, like when stored in CSV files.
        Raw types can be converted to: `Bool`, `Int`, `Float`, `Color` (`Int`), `String` and `enum` types */
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

                switch (type) {

                    case 'Bool':
                        if (Std.is(rawValue, Bool)) {
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
                        if (Std.is(rawValue, Int) || Std.is(rawValue, Float)) {
                            value = Std.int(rawValue);
                        }
                        else {
                            value = Std.parseInt(''+rawValue);
                            if (value == null || Math.isNaN(value)) value = 0;
                        }

                    case 'Float':
                        if (Std.is(rawValue, Int) || Std.is(rawValue, Float)) {
                            value = rawValue;
                        }
                        else {
                            value = Std.parseFloat(''+rawValue);
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

    } //setRawData

    /** Override this method to perform custom deserialisation on a specific field. If the overrided method
        returns `true`, default behavior will be skipped for the related field.*/
    public function setRawField(name:String, rawValue:Dynamic):Bool {

        return false;

    } //setRawField

#if editor

    public function getEditableData():{id:String, name:String, props:DynamicAccess<Dynamic>} {

        var clazz = Type.getClass(this);
        var classPath = Type.getClassName(clazz);
        var info = FieldInfo.editableFieldInfo(classPath);

        var result:DynamicAccess<Dynamic> = {};
        var props:DynamicAccess<Dynamic> = {};

        for (key in info.keys()) {
            var field = info.get(key);

            if (field.meta.exists('editable')) {
                if (key == 'id' || key == 'name') {
                    result.set(key, this.getProperty(key));
                } else {
                    props.set(key, this.getProperty(key));
                }
            }
        }

        result.set('props', props);

        return cast result;

    } //getEditableData

#end

} //CollectionEntry
