package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;

using haxe.macro.ExprTools;

class StateMachineMacro {

    @:persistent static var stateTypeByImplName:Map<String,haxe.macro.ComplexType> = null;

    static var usedNames:Map<String,Bool> = null;

    static var namesForTypePath:Map<String,String> = null;

    static var usedNamesWithEnumValues:Map<String,Array<haxe.macro.Type.EnumField>> = null;

    static var usedNamesWithAbstractValues:Map<String,Array<String>> = null;

    static var entityTypes:Map<String,ComplexType> = null;

    static var stringStateMachineDefined:Bool = false;

    /** Depending on the generic type parameter used, will return (and create, if needed) a specific implementation. */
    macro static public function buildGeneric():ComplexType {

        var localType = Context.getLocalType();
        var currentPos = Context.currentPos();

        //trace('localType: $localType');

        if (stateTypeByImplName == null) {
            stateTypeByImplName = new Map();
        }

        if (usedNames == null) {
            namesForTypePath = new Map();
            usedNamesWithEnumValues = new Map();
            usedNamesWithAbstractValues = new Map();
            usedNames = new Map();
            usedNames.set('String', true); // Reserved
            entityTypes = new Map();
        }

        switch(localType) {

            case TInst(_, [TEnum(t, params), TInst(entityT, entityParams)]):

                createStaticStateMachine(currentPos, t, params);
                return createStaticStateMachine(currentPos, t, params, null, null, entityT, entityParams);

            case TInst(_, [TEnum(t, params)]):

                return createStaticStateMachine(currentPos, t, params, null, null);
            
            case TInst(_, [TAbstract(t, params), TInst(entityT, entityParams)]):

                var abstractType = t.get();
                if (abstractType.meta.has(':enum')) {
                    createStaticStateMachine(currentPos, null, null, t, params);
                    return createStaticStateMachine(currentPos, null, null, t, params, entityT, entityParams);
                }
            
            case TInst(_, [TAbstract(t, params)]):

                var abstractType = t.get();
                if (abstractType.pack.length == 0 && abstractType.name == 'Any') {

                    // Just referencing any implementation in code

                    return TPath({
                        pack: ['ceramic'],
                        name: 'StateMachineBase',
                        params: []
                    });
                }

                if (abstractType.meta.has(':enum')) {
                    return createStaticStateMachine(currentPos, null, null, t, params);
                }

            case TInst(_, [TInst(t, params)]):
                var classType = t.get();
                if (classType.pack.length == 0 && classType.name == 'String') {

                    // String-based implementation (dynamic state machine)

                    var implName = 'StateMachine_String';
                    if (!stringStateMachineDefined) {
                        stringStateMachineDefined = true;

                        // Ensure type is not already defined
                        // (could happen when using compilation server)
                        var existingType:haxe.macro.Type = null;
                        try {
                            existingType = Context.resolveType(TPath({
                                pack: ['ceramic'],
                                name: implName
                            }), currentPos);
                        }
                        catch (e:Dynamic) {}

                        if (existingType == null) {
                            Context.defineType({
                                pack: ['ceramic'],
                                name: implName,
                                pos: currentPos,
                                kind: TDClass({
                                    pack: ['ceramic'],
                                    name: 'StateMachineImpl',
                                    params: [TPType(TypeTools.toComplexType(TInst(t, params)))]
                                }),
                                fields: []
                            });
                        }
                    }

                    return TPath({
                        pack: ['ceramic'],
                        name: implName
                    });
                }

            case TInst(_, [TDynamic(t)]):

                // Just referencing any implementation in code

                return TPath({
                    pack: ['ceramic'],
                    name: 'StateMachineBase',
                    params: []
                });

            default:
        }

        Context.error("Invalid type parameter. Accepted: Enum or String.", currentPos);
        return null;

    }

    static function createStaticStateMachine(
        currentPos:Position,
        t:haxe.macro.Type.Ref<haxe.macro.Type.EnumType>,
        params:Array<haxe.macro.Type>,
        ?abstractT:haxe.macro.Type.Ref<haxe.macro.Type.AbstractType>,
        ?abstractParams:Array<haxe.macro.Type>,
        ?entityT:haxe.macro.Type.Ref<haxe.macro.Type.ClassType>,
        ?entityParams:Array<haxe.macro.Type>
        ) {

        // Enum-based implementation (type-safe state machine)

        var enumType = t != null ? t.get() : null;
        var enumComplexType = enumType != null ? TypeTools.toComplexType(TEnum(t, params)) : null;

        var abstractType = abstractT != null ? abstractT.get() : null;
        var abstractComplexType = abstractType != null ? TypeTools.toComplexType(TAbstract(abstractT, abstractParams)) : null;

        var entityType = entityT != null ? entityT.get() : null;
        var entityComplexType = entityType != null ? TypeTools.toComplexType(TInst(entityT, entityParams)) : null;

        var type:haxe.macro.Type = enumType != null ? TEnum(t, params) : TAbstract(abstractT, abstractParams);
        var typePathStr = '' + type;
        if (entityType != null) {
            var entityTypeInst:haxe.macro.Type = TInst(entityT, entityParams);
            typePathStr += '_' + entityTypeInst;
        }
        var implName = namesForTypePath.get(typePathStr);
        var parentImplName = null;
        if (implName == null) {
            var typeName = enumType != null ? enumType.name : abstractType.name;
            implName = 'StateMachine_' + typeName;
            if (entityType != null) {
                parentImplName = implName;
                implName += '_' + entityType.name;
            }
            var n = 0;
            while (usedNames.exists(implName)) {
                implName = 'StateMachine_' + typeName + n;
                n++;
            }
            usedNames.set(implName, true);
            namesForTypePath.set(typePathStr, implName);

            if (enumComplexType != null) {
                stateTypeByImplName.set(implName, enumComplexType);
            }
            else {
                stateTypeByImplName.set(implName, abstractComplexType);
            }

            // Gather enum values
            var enumValues:Array<haxe.macro.Type.EnumField> = null;
            if (enumType != null) {
                enumValues = [];
                for (aConstruct in enumType.constructs) {
                    enumValues.push(aConstruct);
                }
            }
            var abstractValues:Array<String> = null;
            if (abstractType != null) {
                abstractValues = [];
                for (field in abstractType.impl.get().statics.get()) {
                    if (field.meta.has(':enum') && field.meta.has(':impl')) {
                        abstractValues.push(field.name);
                    }
                }
            }

            // Keep enum values as they will be needed in autoBuild macro
            usedNamesWithEnumValues.set(implName, enumValues);

            // Keep abstract values as they will be needed in autoBuild macro
            usedNamesWithAbstractValues.set(implName, abstractValues);

            // Keep entity type linked with this implementation name (if any)
            if (entityComplexType != null) {
                entityTypes.set(implName, entityComplexType);
            }

            var fields:Array<Field> = [];
            
            if (entityComplexType == null) {
                
                if (enumType != null) {

                    // Enum type

                    fields.push({
                        pos: currentPos,
                        name: 'indexForEnumValue',
                        kind: FFun({
                            args: [{
                                name: 'enumValue',
                                type: enumComplexType
                            }],
                            ret: macro :Int,
                            expr: macro {
                                return enumValue == null ? -1 : enumValue.getIndex();
                            }
                        }),
                        access: [APrivate #if !haxe_server , AInline #end],
                        doc: '',
                        meta: []
                    });

                    fields.push({
                        pos: currentPos,
                        name: 'computeStateDefined',
                        kind: FFun({
                            args: [{
                                name: 'state',
                                type: enumComplexType
                            }],
                            ret: macro :Bool,
                            expr: macro {
                                return state != null;
                            }
                        }),
                        access: [AOverride],
                        doc: '',
                        meta: []
                    });
                }
                else {

                    // Abstract type

                    // A bit hacky, but I didn't find a simpler way to get this information
                    // TODO make it cleaner?
                    var isInt = false;//('' + abstractType.type) == 'TAbstract(Int,[])';
                    
                    var exprList = [];
                    exprList.push('{');
                    if (isInt) {
                        exprList.push('return untyped enumValue;');
                    }
                    else {
                        exprList.push('return switch enumValue {');

                        exprList.push('default: -1;');
                        for (i in 0...abstractValues.length) {
                            exprList.push('case ${abstractValues[i]}: $i;');
                        }

                        exprList.push('}');
                    }
                    exprList.push('}');

                    fields.push({
                        pos: currentPos,
                        name: 'indexForEnumValue',
                        kind: FFun({
                            args: [{
                                name: 'enumValue',
                                type: abstractComplexType
                            }],
                            ret: macro :Int,
                            expr: Context.parse(exprList.join('\n'), currentPos)
                        }),
                        access: [APrivate #if !haxe_server , AInline #end],
                        doc: '',
                        meta: []
                    });

                    fields.push({
                        pos: currentPos,
                        name: 'computeStateDefined',
                        kind: FFun({
                            args: [{
                                name: 'state',
                                type: abstractComplexType
                            }],
                            ret: macro :Bool,
                            expr: macro {
                                return true; // Always true in case of abstracts because we can't assign null
                            }
                        }),
                        access: [AOverride],
                        doc: '',
                        meta: []
                    });
                }

                fields.push({
                    pos: currentPos,
                    name: 'stateInstancesByIndex',
                    kind: FVar(macro :Array<ceramic.State>, macro []),
                    access: [APrivate],
                    doc: '',
                    meta: []
                });
                
                fields.push({
                    pos: currentPos,
                    name: 'set',
                    kind: FFun({
                        args: [{
                            name: 'key',
                            type: (enumType != null ? enumComplexType : abstractComplexType)
                        }, {
                            name: 'stateInstance',
                            type: macro :ceramic.State
                        }],
                        ret: macro :Void,
                        expr: macro {

                            var index = indexForEnumValue(key);
                            if (index == -1) {
                                throw 'Invalid enum value: ' + key;
                            }

                            var existing = stateInstancesByIndex[index];
                            if (existing != null) {
                                if (existing == currentStateInstance) {
                                    currentStateInstance = null;
                                }
                                if (existing != stateInstance) {
                                    existing.destroy();
                                }
                            }

                            stateInstancesByIndex[index] = stateInstance;

                            if (stateInstance != null) {
                                stateInstance.machine = cast this;

                                if (index == indexForEnumValue(state)) {
                                    // We changed state instance for the current state,
                                    // so we need to update `currentStateInstance` accordingly
                                    if (currentStateInstance == null) {
                                        currentStateInstance = stateInstance;
                                        currentStateInstance.enter();
                                    }
                                }
                            }
                        }
                    }),
                    access: [AOverride],
                    doc: '',
                    meta: []
                });
                
                fields.push({
                    pos: currentPos,
                    name: 'get',
                    kind: FFun({
                        args: [{
                            name: 'key',
                            type: (enumType != null ? enumComplexType : abstractComplexType)
                        }],
                        ret: macro :ceramic.State,
                        expr: macro {

                            var index = indexForEnumValue(key);
                            if (index == -1) {
                                return null;
                            }

                            return stateInstancesByIndex[index];
                        }
                    }),
                    access: [AOverride],
                    doc: '',
                    meta: []
                });
            }

            if (entityComplexType != null) {

                fields.push({
                    pos: currentPos,
                    name: 'entity',
                    kind: FProp('default', 'null', entityComplexType, macro null),
                    access: [APublic],
                    doc: '',
                    meta: []
                });
            }

            // Ensure type is not already defined
            // (could happen when using compilation server)
            var existingType:haxe.macro.Type = null;
            try {
                existingType = Context.resolveType(TPath({
                    pack: ['ceramic'],
                    name: implName
                }), currentPos);
            }
            catch (e:Dynamic) {}

            if (existingType == null) {

                var meta = [{
                    name: ':autoBuild',
                    params: [ macro ceramic.macros.StateMachineMacro.buildFields() ],
                    pos: currentPos
                }];
                if (parentImplName == null) {
                    meta.push({
                        name: ':build',
                        params: [ macro ceramic.macros.StateMachineMacro.buildFields() ],
                        pos: currentPos
                    });
                }
                // Create dedicated type that uses our enum/abstract
                Context.defineType({
                    pack: ['ceramic'],
                    name: implName,
                    pos: currentPos,
                    kind: TDClass({
                        pack: ['ceramic'],
                        name: parentImplName != null ? parentImplName : 'StateMachineImpl',
                        params: parentImplName != null ? [] : [TPType(enumType != null ? enumComplexType : abstractComplexType)]
                    }),
                    fields: fields,
                    meta: meta
                });
            }
        }

        return TPath({
            pack: ['ceramic'],
            name: implName
        });

    }

    /** Called on `StateMachinImpl` subclasses. Will generate code that will automatically
        call `enter{State}()`, `update{State}(delta)` and `exit{State}()` from the enum definition.
        Won't do anything on dynamic (String-based) implementation */
    static function buildFields():Array<Field> {

        var fields = Context.getBuildFields();
        var localClass = Context.getLocalClass().get();
        var currentPos = Context.currentPos();

        // Not inserting `self calls` in the class generated from genericBuild, only its subclasses
        var callSelfMethods:Bool = !usedNamesWithEnumValues.exists(localClass.name);

        // Gather every field by name
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        if (fieldsByName.exists('_enterState')) {
            // Already processed
            return fields;
        }

        //trace('BUILD ${localClass.name}');

        var enumValues:Array<haxe.macro.Type.EnumField> = null;
        var abstractValues:Array<String> = null;
        var entityComplexType:ComplexType = entityTypes.get(localClass.name);

        // Also check parent fields
        var parentHold = localClass.superClass;
        var parent = parentHold != null ? parentHold.t : null;
        var numParents = 0;
        while (parent != null) {

            var fetchedParent = parent.get();

            if (enumValues == null && abstractValues == null) {
                enumValues = usedNamesWithEnumValues.get(fetchedParent.name);
                abstractValues = usedNamesWithAbstractValues.get(fetchedParent.name);
            }
            
            if (entityComplexType == null) {
                entityComplexType = entityTypes.get(fetchedParent.name);
            }

            for (field in fetchedParent.fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = fetchedParent.superClass;
            parent = parentHold != null ? parentHold.t : null;
            numParents++;
        }

        if (entityComplexType != null) {
            if (enumValues == null && abstractValues == null) {
                enumValues = usedNamesWithEnumValues.get(localClass.name);
                abstractValues = usedNamesWithAbstractValues.get(localClass.name);
            }
        }

        if (enumValues == null && abstractValues == null) {
            // We are not using an enum or abstract as generic type, stop here
            return fields;
        }

        var callEntityMethods = false;
        var entityFieldsByName = new Map<String,Bool>();
        if (entityComplexType != null) {
            try {
                var resolvedEntityType:haxe.macro.Type = Context.resolveType(entityComplexType, Context.currentPos());
                if (resolvedEntityType != null) {
                    switch resolvedEntityType {
                        default:
                        case TLazy(f):
                            resolvedEntityType = f();
                    }
                    switch resolvedEntityType {
                        default:
                        case TInst(t, params):
                            var classType = t.get();

                            var typeName = classType.name;
                            if (classType.pack.length > 0) {
                                typeName = classType.pack.join('.') + '.' + typeName;
                            }
                            // We may need to fetch field names from entity macro directly,
                            // Because our state machine type might actually be currently resolved
                            // from entity macro execution, meaning class is not totally ready.
                            // To workaround this limitation, EntityMacro starts with gathering all field
                            // names and makes them available from the following helper, even before it
                            // has finished building entity class.
                            var classFieldNames = EntityMacro.getFieldNamesFromTypeName(typeName);
                            if (classFieldNames != null) {
                                for (name in classFieldNames) {
                                    entityFieldsByName.set(name, true);
                                }
                            }
                            else {
                                for (field in classType.fields.get()) {
                                    entityFieldsByName.set(field.name, true);
                                }
                            }

                            // Check parents
                            var parentHold = classType.superClass;
                            var parent = parentHold != null ? parentHold.t : null;
                            var numParents = 0;
                            while (parent != null) {
                    
                                var fetchedParent = parent.get();
                    
                                for (field in fetchedParent.fields.get()) {
                                    entityFieldsByName.set(field.name, true);
                                }
                    
                                parentHold = fetchedParent.superClass;
                                parent = parentHold != null ? parentHold.t : null;
                                numParents++;
                            }

                            callEntityMethods = true;
                    }
                }
            }
            catch (e:Dynamic) {}
        }

        if (!callEntityMethods && !callSelfMethods) {
            // Nothing to add in this situation
            return fields;
        }

        var stateValues = [];
        if (enumValues != null) {
            for (value in enumValues) {
                stateValues.push(value.name);
            }
        }
        else {
            for (value in abstractValues) {
                stateValues.push(value);
            }
        }

        var enterExprs = [];
        var updateExprs = [];
        var exitExprs = [];

        if (enumValues != null) {
            enterExprs.push('switch state.getIndex() {');
            updateExprs.push('switch state.getIndex() {');
            exitExprs.push('switch state.getIndex() {');
        }
        else {
            enterExprs.push('switch state {');
            updateExprs.push('switch state {');
            exitExprs.push('switch state {');
        }
        
        enterExprs.push('default:');
        updateExprs.push('default:');
        exitExprs.push('default:');

        for (i in 0...stateValues.length) {
            var stateValue = stateValues[i];

            if (enumValues != null) {
                var enumValue = enumValues[i];
                enterExprs.push('case ' + enumValue.index + ':');
                updateExprs.push('case ' + enumValue.index + ':');
                exitExprs.push('case ' + enumValue.index + ':');
            }
            else {
                enterExprs.push('case ' + stateValue + ':');
                updateExprs.push('case ' + stateValue + ':');
                exitExprs.push('case ' + stateValue + ':');
            }

            if (callSelfMethods && fieldsByName.exists(stateValue + '_enter')) {
                enterExprs.push(stateValue + '_enter();');
            }
            if (callEntityMethods && entityFieldsByName.exists(stateValue + '_enter')) {
                enterExprs.push('@:privateAccess entity.' + stateValue + '_enter();');
            }

            if (callSelfMethods && fieldsByName.exists(stateValue + '_update')) {
                updateExprs.push(stateValue + '_update(delta);');
            }
            if (callEntityMethods && entityFieldsByName.exists(stateValue + '_update')) {
                updateExprs.push('@:privateAccess entity.' + stateValue + '_update(delta);');
            }

            if (callSelfMethods && fieldsByName.exists(stateValue + '_exit')) {
                exitExprs.push(stateValue + '_exit();');
            }
            if (callEntityMethods && entityFieldsByName.exists(stateValue + '_exit')) {
                exitExprs.push('@:privateAccess entity.' + stateValue + '_exit();');
            }
        }

        enterExprs.push('}');
        updateExprs.push('}');
        exitExprs.push('}');

        var enterSwitchExpr = Context.parse(enterExprs.join('\n'), currentPos);
        var updateSwitchExpr = Context.parse(updateExprs.join('\n'), currentPos);
        var exitSwitchExpr = Context.parse(exitExprs.join('\n'), currentPos);

        // Add method overrides
        //
        fields.push({
            pos: currentPos,
            name: '_enterState',
            kind: FFun({
                args: [],
                ret: macro :Void,
                expr: macro {
                    
                    // Call hook method from state (if any)
                    ${enterSwitchExpr};
                    
                    // Enter new state object (if any)
                    currentStateInstance = get(state);
                    if (currentStateInstance != null) {
                        currentStateInstance.enter();
                    }
                }
            }),
            access: [APrivate, AOverride],
            doc: '',
            meta: []
        });

        fields.push({
            pos: currentPos,
            name: '_updateState',
            kind: FFun({
                args: [{
                    name: 'delta',
                    type: macro :Float
                }],
                ret: macro :Void,
                expr: macro {

                    var state = this.state;

                    if (paused || !stateDefined) return;
                    
                    // Call hook method from state (if any)
                    ${updateSwitchExpr};

                    if (currentStateInstance != null) {
                        currentStateInstance.update(delta);
                    }
                }
            }),
            access: [APrivate, AOverride],
            doc: '',
            meta: []
        });

        fields.push({
            pos: currentPos,
            name: '_exitState',
            kind: FFun({
                args: [],
                ret: macro :Void,
                expr: macro {
                    
                    // Call hook method from state (if any)
                    ${exitSwitchExpr};

                    // Exit previous state object (if any)
                    if (currentStateInstance != null) {
                        currentStateInstance.exit();
                        currentStateInstance = null;
                    }
                }
            }),
            access: [APrivate, AOverride],
            doc: '',
            meta: []
        });

        return fields;

    }

    public static function getStateTypeFromImplName(implName:String):haxe.macro.ComplexType {

        if (stateTypeByImplName == null)
            return null;
        return stateTypeByImplName.get(implName);

    }

}
