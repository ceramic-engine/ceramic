package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Build macro that implements lazy initialization for class fields.
 * 
 * This macro transforms fields marked with the `@lazy` metadata into properties
 * that are initialized on first access rather than at construction time.
 * This is useful for expensive computations or resources that may not always be needed.
 * 
 * ## Usage
 * 
 * Apply this macro to a class and mark fields with @lazy:
 * 
 * ```haxe
 * @:build(ceramic.macros.LazyMacro.build())
 * class MyClass {
 *     @lazy var expensiveResource = new ExpensiveResource();
 *     @lazy var computedValue = performComplexCalculation();
 * }
 * 
 * // The resources are not created until first access:
 * var obj = new MyClass(); // No resources allocated yet
 * var res = obj.expensiveResource; // ExpensiveResource created now
 * ```
 * 
 * ## How It Works
 * 
 * For each @lazy field, the macro generates:
 * 1. A private flag field (e.g., `lazyExpensiveResource`) to track initialization
 * 2. A property with get/set accessors replacing the original field
 * 3. A getter that checks the flag and initializes the value on first access
 * 4. A setter that allows the value to be changed after initialization
 * 
 * ## Requirements
 * 
 * - Fields must have an initialization expression
 * - Works with both instance and static fields
 * - Type can be inferred from the initialization expression
 * 
 * @see ceramic.Lazy For the interface that lazy-initialized objects can implement
 */
class LazyMacro {

    /**
     * Build macro entry point that processes fields marked with @lazy metadata.
     * 
     * Transforms lazy fields into properties with deferred initialization,
     * generating the necessary backing fields and accessor methods.
     * 
     * @return Modified array of fields with lazy initialization implemented
     */
    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN LazyMacro.build()');
        #end

        var fields = Context.getBuildFields();

        var newFields:Array<Field> = [];

        for (field in fields) {

            if (hasLazyMeta(field)) {
                
                switch(field.kind) {
                    case FieldType.FVar(type, expr):

                        if (newFields == null) newFields = [];

                        var fieldName = field.name;
                        var capitalName = field.name.substr(0,1).toUpperCase() + field.name.substr(1);
                        var lazyFieldName = 'lazy' + capitalName;
                        var isStatic = field.access.indexOf(AStatic) != -1;
                        var lazyFieldNameExpr = { expr: EConst(CIdent(lazyFieldName)), pos: field.pos };
                        var fieldNameExpr = { expr: EConst(CIdent(fieldName)), pos: field.pos };

                        if (expr != null) {
                            // Compute type from expr
                            switch (expr.expr) {
                                case ENew(t,p):
                                    if (type == null) {
                                        type = TPath(t);
                                    }
                                default:
                                    if (type == null) {
                                        throw new Error("Cannot resolve lazy variable type", field.pos);
                                    }
                            }
                        }
                        else {
                            throw new Error("Lazy variable expression is required", field.pos);
                        }

                        // Create lazy flag (true=should lazy load, false=already lazy loaded)
                        var lazyField = {
                            pos: field.pos,
                            name: lazyFieldName,
                            kind: FVar((macro :Bool), (macro true)),
                            access: field.access,
                            doc: field.doc,
                            meta: [{
                                name: ':noCompletion',
                                params: [],
                                pos: field.pos
                            }]
                        };
                        newFields.push(lazyField);

                        // Create prop from var
                        var propField = {
                            pos: field.pos,
                            name: field.name,
                            kind: FProp('get', 'set', type),
                            access: field.access,
                            doc: field.doc,
                            meta: [{
                                name: ':isVar',
                                params: [],
                                pos: field.pos
                            }]
                        };
                        newFields.push(propField);

                        var getField = {
                            pos: field.pos,
                            name: 'get_' + field.name,
                            kind: FFun({
                                args: [],
                                ret: type,
                                expr: macro {
                                    if ($e{lazyFieldNameExpr}) {
                                        $e{lazyFieldNameExpr} = false;
                                        $e{fieldNameExpr} = $expr;
                                    }
                                    return $e{fieldNameExpr};
                                }
                            }),
                            access: isStatic ? [APrivate, AStatic] : [APrivate],
                            doc: '',
                            meta: []
                        }
                        newFields.push(getField);

                        var setField = {
                            pos: field.pos,
                            name: 'set_' + field.name,
                            kind: FFun({
                                args: [
                                    {name: field.name + '_', type: type}
                                ],
                                ret: type,
                                expr: macro {
                                    return $e{fieldNameExpr} = $i{fieldName + '_'};
                                }
                            }),
                            access: isStatic ? [APrivate, AInline, AStatic] : [APrivate, AInline],
                            doc: '',
                            meta: []
                        }
                        newFields.push(setField);

                    default:
                        throw new Error("Invalid lazy variable", field.pos);
                }
            }
            else {
                newFields.push(field);
            }

        }

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END LazyMacro.build()');
        #end

        return newFields;

    }

    /**
     * Checks if a field has the @lazy metadata attached.
     * 
     * @param field The field to check
     * @return True if the field has @lazy metadata, false otherwise
     */
    static function hasLazyMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'lazy') {
                return true;
            }
        }

        return false;

    }

}