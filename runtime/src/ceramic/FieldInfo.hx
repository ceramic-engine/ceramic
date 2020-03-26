package ceramic;

import haxe.DynamicAccess;

/**
 * Extract field information from a given class type.
 * This is expected to only work with Entity subclasses marked with @editable, @fieldInfo or @autoFieldInfo
 * or classes using FieldInfoMacro. 
 */
class FieldInfo {

    static var fieldInfoMap:Map<String,Map<String,String>> = new Map();

    public static function types(targetClass:String, recursive:Bool = true):Map<String,String> {

        var info = fieldInfoMap.get(targetClass);

        if (info == null) {
            info = new Map();
            fieldInfoMap.set(targetClass, info);

            var clazz = Type.resolveClass(targetClass);
            var clazzStr = '' + clazz;
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

        return info;

    }

    public static function typeOf(targetClass:String, field:String):String {

        return types(targetClass).get(field);

    }

#if editor

    static var editableFieldInfoMap:Map<String,Map<String,{type:String, meta:DynamicAccess<Dynamic>}>> = new Map();

    public static function editableFieldInfo(targetClass:String, recursive:Bool = true):Map<String,{type:String, meta:DynamicAccess<Dynamic>}> {

        var info = editableFieldInfoMap.get(targetClass);

        if (info == null) {
            info = new Map();
            editableFieldInfoMap.set(targetClass, info);

            var clazz = Type.resolveClass(targetClass);
            var clazzStr = '' + clazz;

            while (clazz != null) {

                var storedFieldInfo:DynamicAccess<Dynamic> = Reflect.field(clazz, '_fieldInfo');

                if (storedFieldInfo != null) {
                    for (key => val in storedFieldInfo) {
                        if (Reflect.hasField(val, 'editable')) {
                            if (!info.exists(key))
                                info.set(key, {
                                    type: val.type,
                                    meta: {
                                        editable: val.editable
                                    }
                                });
                        }
                    }
                }

                if (!recursive)
                    break;

                clazz = Type.getSuperClass(clazz);
                
            }
        }

        return info;

    }

#end

}
