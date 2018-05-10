package ceramic;

import haxe.rtti.Meta;
import ceramic.Assert.*;
import ceramic.Shortcuts.*;

using StringTools;

@:allow(ceramic.SerializeModel)
@:allow(ceramic.SaveModel)
class Serialize {

    public static function serialize(serializable:Serializable):String {

        _serializedMap = new Map();

        var serialized = serializeValue(serializable);

        var s = new haxe.Serializer();
        s.serialize(serialized);
        s.serialize(_serializedMap);
        var result = s.toString();

        _serializedMap = null;

        //trace(result);

        return result;

    } //serialize

    public static function deserialize(serializable:Serializable, data:String):Void {

        var u = new haxe.Unserializer(data);
        var serialized = u.unserialize();
        _serializedMap = u.unserialize();
        _deserializedMap = new Map();

        var deserialized = deserializeValue(serialized, serializable);

        _deserializedMap = null;
        _serializedMap = null;

    } //deserialize

/// Internal

    static var _serializedMap:Map<String,{ id:String, type:String, props:Dynamic }> = null;

    static var _deserializedMap:Map<String,Serializable> = null;

    static var _onAddSerializable:Serializable->Void = null;

    static var _appendSerialize:Bool = false;

    static function serializeValue(value:Dynamic):Dynamic {

        if (value == null) return null;
        if (_serializedMap == null) return null;

        if (Std.is(value, Serializable)) {

            var clazz = Type.getClass(value);
            var props:Dynamic = {};
            var id = value._serializeId;

            assert(id != null, 'Serializable id must not be null');

            if (_deserializedMap != null) {
                _deserializedMap.set(id, value);
            }

            if (_serializedMap.exists(id)) {
                return { id: id };
            }

            var result = {
                id: id,
                type: Type.getClassName(clazz),
                props: {}
            };

            _serializedMap.set(id, result);

            var fieldsMeta = Meta.getFields(clazz);
            var prefixLen = 'unobserved'.length;
            for (fieldRealName in Reflect.fields(fieldsMeta)) {
                var fieldInfo = Reflect.field(fieldsMeta, fieldRealName);

                if (Reflect.hasField(fieldInfo, 'serialize')) {
                    var fieldName = fieldRealName;
                    if (fieldName.startsWith('unobserved')) {
                        fieldName = fieldName.charAt(prefixLen).toLowerCase() + fieldName.substr(prefixLen + 1);
                    }

                    var val = serializeValue(Extensions.getProperty(value, fieldRealName));
                    Reflect.setField(result.props, fieldName, val);
                }
            }

            if (_onAddSerializable != null) {
                _onAddSerializable(value);
            }

            return { id: id };

        }
        else if (Std.is(value, Array)) {

            var result:Array<Dynamic> = [];

            var array:Array<Dynamic> = value;
            for (item in array) {
                result.push(serializeValue(item));
            }

            return result;

        }
        else if (Std.is(value, String) || Std.is(value, Int) || Std.is(value, Float) || Std.is(value, Bool)) {

            return value;

        }
        else {

            // Use Haxe's built in serializer as a fallback
            var serializer = new haxe.Serializer();
            serializer.useCache = true;
            serializer.serialize(value);

            return { hx: serializer.toString() };

        }

    } //serializeValue

    static function deserializeValue(value:Dynamic, ?serializable:Serializable):Dynamic {

        if (value == null) return null;
        if (_serializedMap == null) return null;
        if (_deserializedMap == null) return null;

        if (Std.is(value, Array)) {

            var result:Array<Dynamic> = [];

            var array:Array<Dynamic> = value;
            for (item in array) {
                result.push(deserializeValue(item));
            }

            return result;

        }
        else if (Std.is(value, String) || Std.is(value, Int) || Std.is(value, Float) || Std.is(value, Bool)) {

            return value;

        }
        else if (value.id != null) {

            if (_deserializedMap.exists(value.id)) {
                return _deserializedMap.get(value.id);
            }
            else if (_serializedMap.exists(value.id)) {

                var info = _serializedMap.get(value.id);
                
                var clazz = Type.resolveClass(info.type);
                if (clazz == null) {
                    warning('Failed to resolve class for serialized type: ' + info.type);
                    return null;
                }

                if (serializable != null && Type.getClass(serializable) != clazz) {
                    throw 'Type mismatch when deserializing object expected $clazz, got ' + Type.getClass(serializable);
                }

                // Create instance (without calling constructor)
                var instance = serializable != null && Type.getClass(serializable) == clazz ? serializable : Type.createEmptyInstance(clazz);

                assert(instance != null, 'Created empty instance should not be null');

                // Add instance in mapping
                instance._serializeId = value.id;
                _deserializedMap.set(value.id, instance);

                // Iterate over each serializable field and either put a default value
                // or the one provided by serialized data.
                //
                var fieldsMeta = Meta.getFields(clazz);
                var prefixLen = 'unobserved'.length;
                var methods = new Map<String,Bool>();
                for (method in Type.getInstanceFields(clazz)) {
                    methods.set(method, true);
                }

                for (fieldRealName in Reflect.fields(fieldsMeta)) {
                    var fieldInfo = Reflect.field(fieldsMeta, fieldRealName);

                    if (Reflect.hasField(fieldInfo, 'serialize')) {
                        var fieldName = fieldRealName;
                        if (fieldName.startsWith('unobserved')) {
                            fieldName = fieldName.charAt(prefixLen).toLowerCase() + fieldName.substr(prefixLen + 1);
                        }

                        if (Reflect.hasField(info.props, fieldName)) {
                            // Value provided by data, use it
                            var val = deserializeValue(Reflect.field(info.props, fieldName));
                            Extensions.setProperty(instance, fieldRealName, val);
                        }
                        else if (methods.exists('_default_' + fieldName)) {
                            // No value in data, but a default one for this class, use it
                            var val = Reflect.callMethod(instance, Reflect.field(instance, '_default_' + fieldName), []);
                            Extensions.setProperty(instance, fieldRealName, val);
                        }
                    }
                }

                return instance;

            }
            else {
                return null;
            }

        }
        else if (value.hx != null) {

            var u = new haxe.Unserializer(value.hx);
            return u.unserialize();

        }
        else {

            return null;

        }

    } //deserializeValue

} //Serialize
