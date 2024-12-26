package ceramic;

import haxe.rtti.Meta;

/**
 * Utility to get runtime metadata
 */
class FieldMeta {

    static var metaMap:Map<String,Map<String,Map<String,Dynamic>>> = new Map();

    static var metaMapRecursive:Map<String,Map<String,Map<String,Dynamic>>> = new Map();

    extern inline overload public static function hasMeta(clazz:Class<Dynamic>, field:String, meta:String, recursive:Bool = true):Bool {

        var targetClass = Type.getClassName(clazz);
        return _hasMeta(clazz, targetClass, field, meta, recursive);

    }

    extern inline overload public static function hasMeta(targetClass:String, field:String, meta:String, recursive:Bool = true):Bool {

        var clazz = Type.resolveClass(targetClass);
        return _hasMeta(clazz, targetClass, field, meta, recursive);

    }

    static function _hasMeta(clazz:Class<Dynamic>, targetClass:String, field:String, meta:String, recursive:Bool):Bool {

        var allMeta = _getMeta(clazz, targetClass, field, recursive);
        return allMeta != null ? allMeta.exists(meta) : false;

    }

    extern inline overload public static function getMeta(clazz:Class<Dynamic>, field:String, recursive:Bool = true):ReadOnlyMap<String,Dynamic> {

        var targetClass = Type.getClassName(clazz);
        return _getMeta(clazz, targetClass, field, recursive);

    }

    extern inline overload public static function getMeta(targetClass:String, field:String, recursive:Bool = true):ReadOnlyMap<String,Dynamic> {

        var clazz = Type.resolveClass(targetClass);
        return _getMeta(clazz, targetClass, field, recursive);

    }

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