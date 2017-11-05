package ceramic;

import haxe.rtti.Meta;

@:build(ceramic.macros.CollectionsMacro.build())
class Collections {

    public function new() {}

} //Collections

@:forward
abstract Collection<T:CollectionEntry>(Array<T>) from Array<T> to Array<T> {

    public function new() {
        this = [];
    }

} //Collection

class CollectionEntry {

    public var id:String;

    public var name:String;

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

                switch (type) {

                    case 'Bool':
                        if (Std.is(rawValue, Bool)) {
                            value = rawValue;
                        }
                        else {
                            rawValue = ''+rawValue.toLowerCase().trim();
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
                            if (Math.isNaN(value)) value = 0;
                        }

                    case 'Float':
                        if (Std.is(rawValue, Int) || Std.is(rawValue, Float)) {
                            value = rawValue;
                        }
                        else {
                            value = Std.parseFloat(''+rawValue);
                            if (Math.isNaN(value)) value = 0.0;
                        }

                    case 'String':
                        value = ''+rawValue;

                    default:
                        var rawValue = ''+rawValue.toLowerCase().trim();
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

    } //setToRaw

} //CollectionEntry