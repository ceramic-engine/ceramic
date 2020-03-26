package ceramic.macros;

import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.DynamicAccess;

using haxe.macro.ExprTools;
using StringTools;

/**
 * Used to expose var/property field types and editable metadata to runtime.
 * This is an alternative to marking classes with @:rtti which exposes much more informations than what we actually need.
 */
class FieldInfoMacro {

    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();

        var fieldInfoData:DynamicAccess<{type:String,?editable:Array<Expr>}> = {};
        var storeEditableMeta = true;
        var storeAllFieldInfo = true;

        for (field in fields) {

            var editableMeta = storeEditableMeta ? getEditableMeta(field) : null;
            if (editableMeta != null || storeAllFieldInfo && (field.access == null || field.access.indexOf(AStatic) == -1)) {
                switch(field.kind) {
                    case FieldType.FVar(type, expr) | FieldType.FProp(_, _, type, expr):
                        var resolvedType = Context.resolveType(type, Context.currentPos());
                        var typeStr = complexTypeToString(TypeTools.toComplexType(resolvedType));
                        if (typeStr == 'StdTypes') {
                            typeStr = complexTypeToString(type);
                        }
                        fieldInfoData.set(field.name, {
                            type: typeStr,
                            editable: editableMeta != null ? editableMeta.params : null
                        });

                    default:
                        if (editableMeta != null)
                            throw new Error("Only variable/property fields can be marked as editable", field.pos);
                }
            }
            
        }

        // Add field info
        if (fieldInfoData != null) {
            var fieldInfoEntries = [];
            var pos = Context.currentPos();
            for (name => info in fieldInfoData) {
                var entries = [];
                if (info.editable != null) {
                    entries.push({
                        expr: {
                            expr: EArrayDecl(info.editable),
                            pos: pos
                        },
                        field: 'editable'
                    });
                }
                if (info.type != null) {
                    entries.push({
                        expr: {
                            expr: EConst(CString(info.type)),
                            pos: pos
                        },
                        field: 'type'
                    });
                }
                fieldInfoEntries.push({
                    expr: {
                        expr: EObjectDecl(entries),
                        pos: pos
                    },
                    field: name
                });
            }

            fields.push({
                pos: pos,
                name: '_fieldInfo',
                kind: FProp('default', 'null', null, { expr: EObjectDecl(fieldInfoEntries), pos: pos }),
                access: [APublic, AStatic],
                doc: 'Field info',
                meta: [{
                    name: ':noCompletion',
                    params: [],
                    pos: pos
                }]
            });
        }

        return fields;

    }

    static function getEditableMeta(field:Field):MetadataEntry {

        if (field.meta == null || field.meta.length == 0) return null;

        for (meta in field.meta) {
            if (meta.name == 'editable') {
                return meta;
            }
        }

        return null;

    }

    static function complexTypeToString(type:ComplexType):String {

        var typeStr:String = null;

        if (type != null) {
            switch (type) {
                case TPath(p):
                    typeStr = p.name;
                    if (p.pack != null && p.pack.length > 0) {
                        typeStr = p.pack.join('.') + '.' + typeStr;
                    }
                    if (p.params != null && p.params.length > 0) {
                        typeStr += '<';
                        var n = 0;
                        for (param in p.params) {
                            if (n > 0)
                                typeStr += ',';
                            switch param {
                                case TPType(t):
                                    typeStr += complexTypeToString(t);
                                case TPExpr(e):
                                    typeStr += 'Dynamic';
                            }
                            n++;
                        }
                        typeStr += '>';
                    }
                default:
                    typeStr = 'Dynamic';
            }
        }
        else {
            typeStr = 'Dynamic';
        }

        return typeStr;

    }

}
