package ceramic;

import haxe.rtti.Meta;
import haxe.rtti.CType;
import haxe.rtti.Rtti;
import haxe.DynamicAccess;

class FieldInfo {

    static var fieldInfoMap:Map<String,Map<String,String>> = new Map();

    static var rttiMap:Map<String,Classdef> = new Map();

    public static function types(targetClass:String):Map<String,String> {

        var info = fieldInfoMap.get(targetClass);

        if (info == null) {
            info = new Map();
            fieldInfoMap.set(targetClass, info);

            var clazz = Type.resolveClass(targetClass);
            var clazzStr = '' + clazz;
            var usedFields = new Map();
            var rtti = rttiMap.get(clazzStr);
            if (rtti == null) {
                rtti = Utils.getRtti(clazz);
                rttiMap.set(clazzStr, rtti);
            }

            while (clazz != null) {

                for (field in rtti.fields) {

                    var fieldType = stringFromCType(field.type);

                    if (!usedFields.exists(field.name)) {
                        usedFields.set(field.name, true);
                        info.set(field.name, fieldType);
                    }
                }

                clazz = Type.getSuperClass(clazz);
                if (clazz != null) {
                    clazzStr = '' + clazz;
                    rtti = rttiMap.get(clazzStr);
                    if (rtti == null) {
                        rtti = Utils.getRtti(clazz);
                        rttiMap.set(clazzStr, rtti);
                    }
                }

            }
        }

        return info;

    }

    public static function typeOf(targetClass:String, field:String):String {

        return types(targetClass).get(field);

    }

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

    }

#if editor

    static var editableFieldInfoMap:Map<String,Map<String,{type:String, meta:DynamicAccess<Dynamic>}>> = new Map();

    public static function editableFieldInfo(targetClass:String):Map<String,{type:String, meta:DynamicAccess<Dynamic>}> {

        var info = editableFieldInfoMap.get(targetClass);

        if (info == null) {
            info = new Map();
            editableFieldInfoMap.set(targetClass, info);

            var clazz = Type.resolveClass(targetClass);
            var usedFields = new Map();
            var rtti = Utils.getRtti(clazz);

            while (clazz != null) {

                var meta = Meta.getFields(clazz);
                for (field in rtti.fields) {
                    var k = field.name;
                    var v = Reflect.field(meta, k);
                    var fieldType = FieldInfo.stringFromCType(field.type);
                    if (v != null && Reflect.hasField(v, 'editable') && !usedFields.exists(k)) {
                        usedFields.set(k, true);
                        info.set(k, {
                            type: fieldType,
                            meta: v
                        });
                    }
                }

                clazz = Type.getSuperClass(clazz);
                if (clazz != null) rtti = Utils.getRtti(clazz);

            }
        }

        return info;

    }

#end

}
