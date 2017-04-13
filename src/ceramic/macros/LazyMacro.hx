package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class LazyMacro {

    macro static public function build():Array<Field> {
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
                                    if (this.$lazyFieldName) {
                                        this.$lazyFieldName = false;
                                        this.$fieldName = $expr;
                                    }
                                    return this.$fieldName;
                                }
                            }),
                            access: [APrivate],
                            doc: '',
                            meta: []
                        }
                        newFields.push(getField);

                        var setField = {
                            pos: field.pos,
                            name: 'set_' + field.name,
                            kind: FFun({
                                args: [
                                    {name: field.name, type: type}
                                ],
                                ret: type,
                                expr: macro {
                                    return this.$fieldName = $i{fieldName};
                                }
                            }),
                            access: [APrivate, AInline],
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

        return newFields;

    } //build

    static function hasLazyMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'lazy' || meta.name == ':lazy') {
                return true;
            }
        }

        return false;

    } //hasComponentMeta

}