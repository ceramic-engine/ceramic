package ceramic.macros;

import haxe.macro.ExprTools;
import haxe.macro.Printer;
import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;

using StringTools;

class ObservableMacro {

    static var _toRename:Map<String,String> = null;

    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN ObservableMacro.build()');
        #end

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();
        var localClass = Context.getLocalClass().get();

        // Get next event index for this class path
        var classPath = localClass.pack != null && localClass.pack.length > 0 ? localClass.pack.join('.') + '.' + localClass.name : localClass.name;
        var nextEventIndex = EventsMacro._nextEventIndexes.exists(classPath) ? EventsMacro._nextEventIndexes.get(classPath) : 1;

        // Check class fields
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        // Check if events should be dispatched dynamically by default on this class
        #if (!completion && !display)
        var dynamicDispatch = EventsMacro.hasDynamicEventsMeta(localClass.meta.get());
        #else
        var dynamicDispatch = false;
        #end

        // Also check parent fields
        var inheritsFromEntity = (classPath == 'ceramic.Entity');
        var parentHold = localClass.superClass;
        var parent = parentHold != null ? parentHold.t : null;
        var numParents = 0;
        while (parent != null) {

            if (!inheritsFromEntity && parentHold.t.toString() == 'ceramic.Entity') {
                inheritsFromEntity = true;
            }

            for (field in parent.get().fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
            numParents++;
        }

        var newFields:Array<Field> = [];

        // In case of dynamic dispatch, check if event dispatcher
        // field was added already on current class fields
        var dispatcherName:String = null;
        if (dynamicDispatch) {
            dispatcherName = '__events' + numParents;
            if (!fieldsByName.exists(dispatcherName)) {
                EventsMacro.createEventDispatcherField(pos, newFields, dispatcherName);
            }
        }

        var unchangedFields:Array<Field> = [];

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
            nextEventIndex = EventsMacro.createEventFields(eventField, newFields, fields, fieldsByName, dynamicDispatch, nextEventIndex, dispatcherName, inheritsFromEntity);

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

        _toRename = null;
        var toRename:Map<String,String> = null;

        for (field in fields) {

            var metasCase = hasRelevantMeta(field);
            var hasKeepMeta = metasCase >= 10;
            if (metasCase >= 10) metasCase -= 10;

            if (metasCase >= 1 && metasCase <= 3) {

                // @observe
                // @serialize

                var hasObserveMeta = metasCase == 1 || metasCase == 3;
                var hasSerializeMeta = metasCase == 2 || metasCase == 3;

                nextEventIndex = createObserveFields(
                    field, newFields, fields, fieldsByName,
                    dynamicDispatch, nextEventIndex, dispatcherName, inheritsFromEntity,
                    hasKeepMeta, hasObserveMeta, hasSerializeMeta,
                    toRename
                );
                toRename = _toRename;
            }
            else if (metasCase == 4) {

                // @compute

                switch field.kind {
                    case FFun(f):
                        //
                    default:
                        throw new Error("Invalid computed variable", field.pos);
                }
            }
            else {
                unchangedFields.push(field);
                newFields.push(field);
            }

        }

#if (!display && !completion)
        // Any field to rename?
        if (toRename != null) {
            for (field in unchangedFields) {
                if (toRename.exists(field.name)) {
                    var name = field.name;
                    var newName = toRename.get(name);
                    field.name = newName;
                    var isSetter = name.substring(0, 4) == 'set_';
                    var selfName = name.substring(4);
                    var newSelfName = newName.substring(4);

                    // Also rename setter/getter content to make it query the unobserved field
                    switch (field.kind) {
                        case FieldType.FFun(fn):
                            var setterArgIsSelfName = (isSetter && fn.args[0].name == selfName);

                            function renameIdent(input:String) {
                                if (input == selfName) return newSelfName;
                                return input;
                            }

                            function renameIdentInString(input:String) {
                                // TODO?
                                return input;
                            }

                            var updateExpr:Expr->Expr;
                            updateExpr = function(e:Expr):Expr {
                                switch (e.expr) {
                                    case EConst(c):
                                        switch (c) {
                                            case CIdent(s):
                                                if (setterArgIsSelfName) {
                                                    return { expr: EConst(CIdent(s)), pos: e.pos };
                                                } else {
                                                    return { expr: EConst(CIdent(renameIdent(s))), pos: e.pos };
                                                }
                                            case CString(s):
                                                return { expr: EConst(CString(renameIdentInString(s))), pos: e.pos };
                                            case _:
                                                return ExprTools.map(e, updateExpr);
                                        }
                                    case EField(_e, _field):
                                        var isThis = false;
                                        switch (_e.expr) {
                                            case EConst(CIdent(s)):
                                                isThis = (s == 'this');
                                            case _:
                                        }
                                        if (isThis) {
                                            return { expr: EField(_e, renameIdent(_field)), pos: e.pos };
                                        } else {
                                            return e;
                                        }
                                    case _:
                                        return ExprTools.map(e, updateExpr);
                                }
                            };
                            fn.expr = ExprTools.map(fn.expr, updateExpr);

                        default:
                    }
                }
            }
        }
#end

        // Store next event index for this class path
        EventsMacro._nextEventIndexes.set(classPath, nextEventIndex);

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END ObservableMacro.build()');
        #end

        return newFields;

    } //build

    static function createObserveFields(
        field:Field, newFields:Array<Field>, existingFields:Array<Field>, fieldsByName:Map<String,Bool>,
        dynamicDispatch:Bool, eventIndex:Int, dispatcherName:String, inheritsFromEntity:Bool,
        hasKeepMeta:Bool, hasObserveMeta:Bool, hasSerializeMeta:Bool,
        toRename:Map<String,String>):Int {

        var isProp = false;
        var get:String = null;
        var set:String = null;
        var type:Null<ComplexType>;
        var expr:Null<Expr>;

        switch(field.kind) {

            case FieldType.FVar(_type, _expr):
                type = _type;
                expr = _expr;

            case FieldType.FProp(_get, _set, _type, _expr):
                get = _get;
                set = _set;
                type = _type;
                expr = _expr;
                isProp = true;

            default:
                throw new Error("Invalid observed variable", field.pos);
        }

        var fieldName = field.name;
        var sanitizedName = field.name;
        while (sanitizedName.startsWith('_')) sanitizedName = sanitizedName.substr(1);
        while (sanitizedName.endsWith('_')) sanitizedName = sanitizedName.substr(0, sanitizedName.length - 1);
        var capitalName = sanitizedName.substr(0,1).toUpperCase() + sanitizedName.substr(1);
        var unobservedFieldName = 'unobserved' + capitalName;
        var emitFieldNameChange = 'emit' + capitalName + 'Change';
        var onFieldNameChange = 'on' + capitalName + 'Change';
        var offFieldNameChange = 'off' + capitalName + 'Change';
        var fieldNameAutoruns = fieldName + 'Autoruns';
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
        
        if (isProp) {
            // Original is already a property (may have getter/setter)
            if (get == 'get') {
                if (toRename == null) toRename = new Map();
                toRename.set('get_' + fieldName, 'get_' + unobservedFieldName);
            }
            if (set == 'set') {
                if (toRename == null) toRename = new Map();
                toRename.set('set_' + fieldName, 'set_' + unobservedFieldName);
            }
        }

        // Create prop from var
        var propField = {
            pos: field.pos,
            name: fieldName,
            kind: FProp('get', 'set', type),
            access: field.access,
            doc: field.doc,
            meta: hasKeepMeta ? [{
                name: ':keep',
                params: [],
                pos: Context.currentPos()
            }] : []
        };
        newFields.push(propField);

        var fieldAutoruns = {
            pos: field.pos,
            name: fieldNameAutoruns,
            kind: FVar(TPath({
                name: 'Array',
                pack: [],
                params: [
                    TPType(
                        macro :ceramic.Autorun
                    )
                ]
            }), macro null),
            access: [APrivate],
        };
        newFields.push(fieldAutoruns);

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
                        if (this.$fieldNameAutoruns == null) {
                            this.$fieldNameAutoruns = ceramic.Autorun.getAutorunArray();
                        }
                        autorun.bindToAutorunArray(this.$fieldNameAutoruns);
                    }

                    return this.$unobservedFieldName;
                }
            }),
            access: [APrivate],
            doc: '',
            meta: hasKeepMeta ? [{
                name: ':keep',
                params: [],
                pos: Context.currentPos()
            }] : []
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
                    
                    if (this.$fieldNameAutoruns != null) {
                        var fieldAutoruns = this.$fieldNameAutoruns;
                        this.$fieldNameAutoruns = null;

                        for (i in 0...fieldAutoruns.length) {
                            var autorun = fieldAutoruns[i];
                            if (autorun != null) {
                                autorun.invalidate();
                            }
                        }

                        ceramic.Autorun.recycleAutorunArray(fieldAutoruns);
                    }

                    return $i{fieldName}
                }
            }),
            access: [APrivate #if !haxe_server , AInline #end],
            doc: '',
            meta: hasKeepMeta ? [{
                name: ':keep',
                params: [],
                pos: Context.currentPos()
            }] : []
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
                    
                    if (this.$fieldNameAutoruns != null) {
                        var fieldAutoruns = this.$fieldNameAutoruns;
                        this.$fieldNameAutoruns = null;

                        for (i in 0...fieldAutoruns.length) {
                            var autorun = fieldAutoruns[i];
                            if (autorun != null) {
                                autorun.invalidate();
                            }
                        }

                        ceramic.Autorun.recycleAutorunArray(fieldAutoruns);
                    }
                }
            }),
            access: [APublic #if !haxe_server , AInline #end],
            doc: '',
            meta: hasKeepMeta ? [{
                name: ':keep',
                params: [],
                pos: Context.currentPos()
            }] : []
        }
        newFields.push(invalidateField);

        // Rename original field from name to unobservedName
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
            access: [APublic #if !haxe_server , AInline #end],
            doc: '',
            meta: []
        }
        newFields.push(invalidateField);

        newFields.push(field);
        var unobservedField = {
            pos: field.pos,
            name: unobservedFieldName,
            kind: FVar(type, null),
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
        eventIndex = EventsMacro.createEventFields(eventField, newFields, existingFields, fieldsByName, dynamicDispatch, eventIndex, dispatcherName, inheritsFromEntity);
    
        // In case it was initialized on this iteration
        _toRename = toRename;

        return eventIndex;

    } //createObserveFields

    static function hasRelevantMeta(field:Field):Int {

        // We also make @serialize properties observable because this
        // is useful for continuous serialization. This obviously only affect
        // @serialize properties on classes that implement Observable macro

        if (field.meta == null || field.meta.length == 0) return 0;

        var hasObserveMeta = false;
        var hasSerializeMeta = false;
        var hasKeepMeta = false;
        var hasComputeMeta = false;

        for (meta in field.meta) {
            if (meta.name == 'observe') {
                hasObserveMeta = true;
            }
            else if (meta.name == 'serialize') {
                hasSerializeMeta = true;
            }
            else if (meta.name == 'compute') {
                hasComputeMeta = true;
            }
            else if (meta.name == ':keep') {
                hasKeepMeta = true;
            }
        }

        if (hasComputeMeta) {
            return hasKeepMeta ? 14 : 4;
        }
        else if (hasObserveMeta && hasSerializeMeta) {
            return hasKeepMeta ? 13 : 3;
        }
        else if (hasSerializeMeta) {
            return hasKeepMeta ? 12 : 2;
        }
        else if (hasObserveMeta) {
            return hasKeepMeta ? 11 : 1;
        }
        return hasKeepMeta ? 10 : 0;

    } //hasRelevantMeta

}