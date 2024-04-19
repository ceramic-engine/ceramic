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

}
