package ceramic.macros;

import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;

using StringTools;

class ObservableMacro {

    macro static public function build():Array<Field> {
        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        // Check class fields
        var localClass = Context.getLocalClass().get();
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        // Also check parent fields
        var parentHold = localClass.superClass;
        var parent = parentHold != null ? parentHold.t : null;
        while (parent != null) {

            for (field in parent.get().fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
        }

        var newFields:Array<Field> = [];

        var localClassParams:Array<TypeParam> = null;
        if (localClass.params != null) {
            localClassParams = [];
            for (param in localClass.params) {
                localClassParams.push(TPType(TypeTools.toComplexType(param.t)));
            }
        }

        if (!fieldsByName.exists('observedDirty')) {

            var eventField = {
                pos: pos,
                name: 'observedDirty',
                kind: FFun({
                    args: [
                        {
                            name: 'instance',
                            type: TPath({
                                name: localClass.name,
                                pack: localClass.pack,
                                params: localClassParams
                            })
                        },
                        {
                            name: 'fromSerializedField',
                            type: macro :Bool
                        }
                    ],
                    ret: macro :Void,
                    expr: null
                }),
                access: [],
                doc: 'Event when any observable value as changed on this instance.',
                meta: []
            };

            // Add event
            EventsMacro.createEventFields(eventField, newFields, fieldsByName);

            // Create observedDirty var
            newFields.push({
                pos: pos,
                name: 'observedDirty',
                kind: FVar(macro :Bool, macro false),
                access: [APublic],
                doc: 'Default is `false`, automatically set to `true` when any of this instance\'s observable variables has changed.',
                meta: []
            });

        }

        for (field in fields) {

            var metasCase = hasObserveOrSerializeMeta(field);

            if (metasCase != 0) {

                var hasObserveMeta = metasCase == 1 || metasCase == 3;
                var hasSerializeMeta = metasCase == 2 || metasCase == 3;
                
                switch(field.kind) {
                    case FieldType.FVar(type, expr):

                        var fieldName = field.name;
                        var sanitizedName = field.name;
                        while (sanitizedName.startsWith('_')) sanitizedName = sanitizedName.substr(1);
                        while (sanitizedName.endsWith('_')) sanitizedName = sanitizedName.substr(0, sanitizedName.length - 1);
                        var capitalName = sanitizedName.substr(0,1).toUpperCase() + sanitizedName.substr(1);
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

#if (!display && !completion)
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
                                    if (!observedDirty) {
                                        observedDirty = true;
                                        emitObservedDirty(this, $v{hasSerializeMeta});
                                    }
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
#else

                        var invalidateField = {
                            pos: field.pos,
                            name: 'invalidate' + capitalName,
                            kind: FFun({
                                args: [],
                                ret: macro :Void,
                                expr: macro {}
                            }),
                            access: [APublic, AInline],
                            doc: '',
                            meta: []
                        }
                        newFields.push(invalidateField);

                        newFields.push(field);
                        var unobservedField = {
                            pos: field.pos,
                            name: unobservedFieldName,
                            kind: field.kind,
                            access: [].concat(field.access),
                            doc: '',
                            meta: []
                        };
                        unobservedField.access.remove(APublic);
                        unobservedField.access.remove(APrivate);
                        newFields.push(unobservedField);
#end

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

    static function hasObserveOrSerializeMeta(field:Field):Int {

        // We also make @serialize properties observable because this
        // is useful for continuous serialization. This obviously only affect
        // @serialize properties on classes that implement Observable macro

        if (field.meta == null || field.meta.length == 0) return 0;

        var hasObserveMeta = false;
        var hasSerializeMeta = false;

        for (meta in field.meta) {
            if (meta.name == 'observe') {
                hasObserveMeta = true;
            }
            else if (meta.name == 'serialize') {
                hasSerializeMeta = true;
            }
        }

        if (hasObserveMeta && hasSerializeMeta) {
            return 3;
        }
        else if (hasSerializeMeta) {
            return 2;
        }
        else if (hasObserveMeta) {
            return 1;
        }
        return 0;

    } //hasComponentMeta

}