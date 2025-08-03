package ceramic.macros;

import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;

using StringTools;
using haxe.macro.ExprTools;

/**
 * Build macro that generates runtime field type information for classes.
 * 
 * This macro provides a lightweight alternative to Haxe's @:rtti metadata,
 * exposing only the field type information needed for runtime introspection
 * without the overhead of full runtime type information.
 * 
 * The macro automatically generates a static `_fieldInfo` property containing
 * type information for all non-static fields (variables and properties) in
 * the class.
 * 
 * ## Usage
 * 
 * Apply this macro to a class using the @:build metadata:
 * 
 * ```haxe
 * @:build(ceramic.macros.FieldInfoMacro.build())
 * class MyClass {
 *     public var intField:Int = 0;
 *     public var stringField:String = "";
 *     public var customField:MyCustomType;
 * }
 * 
 * // At runtime, access field types:
 * var fieldInfo = MyClass._fieldInfo;
 * trace(fieldInfo.intField.type); // "Int"
 * trace(fieldInfo.stringField.type); // "String"
 * trace(fieldInfo.customField.type); // "MyCustomType"
 * ```
 * 
 * ## Generated Structure
 * 
 * The macro generates a static field `_fieldInfo` with the following structure:
 * - Keys: Field names from the class
 * - Values: Objects containing `type` property with the field's type as a string
 * 
 * ## Features
 * 
 * - Processes all instance fields (excludes static fields)
 * - Handles both variables (FVar) and properties (FProp)
 * - Resolves complex types including generics
 * - Fallback to Dynamic for unresolvable types
 * - Marked with @:noCompletion to hide from IDE autocomplete
 * 
 * @see ceramic.FieldInfo For runtime access to field type information
 */
class FieldInfoMacro {

    /**
     * Build macro entry point that processes class fields and generates runtime type information.
     * 
     * This method is called at compile-time when the macro is applied to a class.
     * It examines all non-static fields, extracts their type information, and
     * generates a static `_fieldInfo` property containing this data.
     * 
     * @return Modified array of fields including the generated _fieldInfo field
     */
    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();

        var fieldInfoData:DynamicAccess<{type:String}> = {};
        var storeAllFieldInfo = true;

        for (field in fields) {

            if (storeAllFieldInfo && (field.access == null || field.access.indexOf(AStatic) == -1)) {
                switch(field.kind) {
                    case FieldType.FVar(type, expr) | FieldType.FProp(_, _, type, expr):
                        var resolvedType = Context.resolveType(type, Context.currentPos());
                        var typeStr = complexTypeToString(TypeTools.toComplexType(resolvedType));
                        if (typeStr == 'StdTypes') {
                            typeStr = complexTypeToString(type);
                        }
                        fieldInfoData.set(field.name, {
                            type: typeStr
                        });

                    default:
                }
            }

        }

        // Add field info
        if (fieldInfoData != null) {
            var fieldInfoEntries = [];
            var pos = Context.currentPos();
            for (name => info in fieldInfoData) {
                var entries = [];
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

    /**
     * Converts a Haxe ComplexType to its string representation.
     * 
     * This method handles various type structures including:
     * - Simple types (Int, String, etc.)
     * - Fully qualified types with packages (ceramic.Visual)
     * - Generic types with type parameters (Array<String>, Map<Int,String>)
     * - Nested generic types
     * 
     * Falls back to "Dynamic" for types that cannot be resolved.
     * 
     * @param type The ComplexType to convert
     * @return String representation of the type suitable for runtime use
     */
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
