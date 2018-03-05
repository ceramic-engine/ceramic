package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class ObservableMacro {

    macro static public function build():Array<Field> {
        var fields = Context.getBuildFields();

        // Check class fields
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        // Also check parent fields
        var parentHold = Context.getLocalClass().get().superClass;
        var parent = parentHold != null ? parentHold.t : null;
        while (parent != null) {

            for (field in parent.get().fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
        }

        var newFields:Array<Field> = [];

        for (field in fields) {

            if (hasObserveMeta(field)) {
                
                switch(field.kind) {
                    case FieldType.FVar(type, expr):

                        var fieldName = field.name;
                        var capitalName = field.name.substr(0,1).toUpperCase() + field.name.substr(1);
                        var unobservedFieldName = 'unobserved' + capitalName;
                        var emitFieldNameChange = 'emit' + capitalName + 'Change';
                        var onFieldNameChange = 'on' + capitalName + 'Change';
                        var offFieldNameChange = 'off' + capitalName + 'Change';
                        var fieldNameChange = fieldName + 'Change';

                        if (expr != null) {
                            // Compute type from expr
                            switch (expr.expr) {
                                case ENew(t,p):
                                    if (type == null) {
                                        type = TPath(t);
                                    }
                                default:
                                    if (type == null) {
                                        throw new Error("Cannot resolve observable field type", field.pos);
                                    }
                            }
                        } else if (type == null) {
                            throw new Error("Observable field must define a type", field.pos);
                        }

                        // Create prop from var
                        var propField = {
                            pos: field.pos,
                            name: fieldName,
                            kind: FProp('get', 'set', type),
                            access: field.access,
                            doc: field.doc,
                            meta: []
                        };
                        newFields.push(propField);

                        var getField = {
                            pos: field.pos,
                            name: 'get_' + field.name,
                            kind: FFun({
                                args: [],
                                ret: type,
                                expr: macro {
                                    // Bind invalidation if getting value
                                    // inside an Autorun call
                                    if (ceramic.Autorun.current != null) {
                                        var autorun = ceramic.Autorun.current;
                                        var cb = function(_, _) {
                                            autorun.invalidate();
                                        };
                                        autorun.onceReset(null, function() {
                                            this.$offFieldNameChange(cb);
                                        });
                                        this.$onFieldNameChange(autorun, cb);
                                    }

                                    return this.$unobservedFieldName;
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
                                    var prevValue = this.$unobservedFieldName;
                                    if (prevValue == $i{fieldName}) {
                                        return prevValue;
                                    }
                                    this.$unobservedFieldName = $i{fieldName};
                                    this.$emitFieldNameChange($i{fieldName}, prevValue);
                                    return $i{fieldName}
                                }
                            }),
                            access: [APrivate, AInline],
                            doc: '',
                            meta: []
                        }
                        newFields.push(setField);

                        var invalidateField = {
                            pos: field.pos,
                            name: 'invalidate' + capitalName,
                            kind: FFun({
                                args: [],
                                ret: macro :Void,
                                expr: macro {
                                    var value = this.$unobservedFieldName;
                                    this.$emitFieldNameChange(value, value);
                                }
                            }),
                            access: [APublic, AInline],
                            doc: '',
                            meta: []
                        }
                        newFields.push(invalidateField);

                        // Rename original field from name to observedName
                        field.name = unobservedFieldName;
                        field.access = [].concat(field.access);
                        field.access.remove(APublic);
                        field.access.remove(APrivate);
                        newFields.push(field);

                        var eventField = {
                            pos: field.pos,
                            name: fieldNameChange,
                            kind: FFun({
                                args: [
                                    {name: 'current', type: type},
                                    {name: 'previous', type: type}
                                ],
                                ret: macro :Void,
                                expr: null
                            }),
                            access: [],
                            doc: 'Event when $fieldName field changes.',
                            meta: []
                        };

                        // Add related events
                        EventsMacro.createEventFields(eventField, newFields, fieldsByName);

                    default:
                        throw new Error("Invalid observed variable", field.pos);
                }
            }
            else {
                newFields.push(field);
            }

        }

        return newFields;

    } //build

    static function hasObserveMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'observe') {
                return true;
            }
        }

        return false;

    } //hasComponentMeta

}