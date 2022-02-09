package ceramic;

import ceramic.ReadOnlyMap;
import haxe.DynamicAccess;

/**
 * Extract field information from a given class type.
 * This is expected to only work with Entity subclasses marked with @editable, @fieldInfo or @autoFieldInfo
 * or classes using FieldInfoMacro.
 */
class FieldInfo {

    static var fieldInfoMap:Map<String,Map<String,String>> = new Map();

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

    public static function typeOf(targetClass:String, field:String):String {

        return types(targetClass).get(field);

    }

#if editor

    static var editableFieldInfoMap:Map<String,Map<String,{type:String, meta:DynamicAccess<Dynamic>, index:Int}>> = new Map();

    public static function editableFieldInfo(targetClass:String, recursive:Bool = true):ReadOnlyMap<String,{type:String, meta:DynamicAccess<Dynamic>, index:Int}> {

        var info = editableFieldInfoMap.get(targetClass);

        var indexStart = 10000000;

        if (info == null) {
            info = new Map();
            editableFieldInfoMap.set(targetClass, info);

            var clazz = Type.resolveClass(targetClass);

            var toSort = [];

            while (clazz != null) {

                var storedFieldInfo:DynamicAccess<Dynamic> = Reflect.field(clazz, '_fieldInfo');

                if (storedFieldInfo != null) {
                    for (key => val in storedFieldInfo) {
                        if (Reflect.hasField(val, 'editable')) {
                            if (!info.exists(key)) {
                                var item:{type:String, meta:DynamicAccess<Dynamic>, index:Int} = {
                                    type: val.type,
                                    meta: {
                                        editable: val.editable
                                    },
                                    index: indexStart + Std.int(val.index)
                                };
                                info.set(key, item);
                                toSort.push(item);
                            }
                            else {
                                info.get(key).index = indexStart + Std.int(val.index);
                            }
                        }
                    }
                }

                if (!recursive)
                    break;

                clazz = Type.getSuperClass(clazz);
                indexStart -= 10000;

            }

            toSort.sort((a, b) -> {
                var indexA = a.index;
                var indexB = b.index;
                if (indexA > indexB)
                    return 1;
                else if (indexA < indexB)
                    return -1;
                else
                    return 0;
            });
            var i = 0;
            for (item in toSort) {
                item.index = i++;
            }
        }

        return cast info;

    }

#end

}
