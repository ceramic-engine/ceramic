package ceramic;

import haxe.rtti.Meta;
import haxe.rtti.CType;
import haxe.rtti.Rtti;

class FieldInfo {

    static var fieldInfoMap:Map<String,Map<String,String>> = new Map();

    public static function types(entityClass:String):Map<String,String> {

        var info = fieldInfoMap.get(entityClass);

        if (info == null) {
            info = new Map();
            fieldInfoMap.set(entityClass, info);

            var clazz = Type.resolveClass(entityClass);
            var usedFields = new Map();
            var rtti = Rtti.getRtti(clazz);

            while (clazz != null) {

                for (field in rtti.fields) {

                    var fieldType = stringFromCType(field.type);

                    if (!usedFields.exists(field.name)) {
                        usedFields.set(field.name, true);
                        info.set(field.name, fieldType);
                    }
                }

                clazz = Type.getSuperClass(clazz);
                if (clazz != null) rtti = Rtti.getRtti(clazz);

            }
        }

        return info;

    } //types

    public static function typeOf(entityClass:String, field:String):String {

        return types(entityClass).get(field);

    } //typeOf

    public static function stringFromCType(type:CType):String {
        
        var result = '';
        var i = 0;
        var len = 0;

        switch (type) {
            case CEnum(name, params), CClass(name, params), CTypedef(name, params), CAbstract(name, params):
                result += name;
                if (params.length > 0) {
                    result += '<';
                    i = 0; len = params.length;
                    for (param in params) {
                        result += stringFromCType(param);
                        if (i < len - 1) result += ',';
                        i++;
                    }
                    result += '>';
                }
            default:
                result = 'Dynamic';
        }

        return result;

    } //stringFromCType

} //FieldInfo
