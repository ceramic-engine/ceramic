package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;

using haxe.macro.ExprTools;

class StateMachineMacro {

    static var usedNames:Map<String,Bool> = null;

    static var namesForTypePath:Map<String,String> = null;

    static var stringStateMachineDefined:Bool = false;

    macro static public function buildGeneric():ComplexType {

        var localType = Context.getLocalType();
        var currentPos = Context.currentPos();

        //trace('localType: $localType');

        if (usedNames == null) {
            namesForTypePath = new Map();
            usedNames = new Map();
            usedNames.set('String', true); // Reserved
        }

        switch(localType) {

            case TInst(_, [TEnum(t, params)]):

                // Enum-based implementation (type-safe state machine)

                var enumType = t.get();
                var enumComplexType = TypeTools.toComplexType(TEnum(t, params));

                var enumCases = [];
                for (aConstruct in enumType.constructs) {
                    enumCases.push({
                        expr: {
                            expr: EConst(CInt(''+aConstruct.index)),
                            pos: currentPos
                        },
                        values: [{
                            expr: EConst(CIdent(aConstruct.name)),
                            pos: currentPos
                        }]
                    });
                }
                var enumReturnSwitchExpr = {
                    expr: EReturn({
                        expr: ESwitch({
                            expr: EParenthesis({
                                expr: EConst(CIdent('enumValue')),
                                pos: currentPos
                            }),
                            pos: currentPos
                        }, enumCases, null),
                        pos: currentPos
                    }),
                    pos: currentPos
                };

                var type:haxe.macro.Type = TEnum(t, params);
                var typePathStr = '' + type;
                var implName = namesForTypePath.get(typePathStr);
                if (implName == null) {
                    implName = 'StateMachine_' + enumType.name;
                    var n = 0;
                    while (usedNames.exists(implName)) {
                        implName = 'StateMachine_' + enumType.name + n;
                        n++;
                    }
                    usedNames.set(implName, true);
                    namesForTypePath.set(typePathStr, implName);

                    Context.defineType({
                        pack: ['ceramic'],
                        name: implName,
                        pos: currentPos,
                        kind: TDClass({
                            pack: ['ceramic'],
                            name: 'StateMachineImpl',
                            params: [TPType(enumComplexType)]
                        }),
                        fields: [{
                            pos: currentPos,
                            name: 'indexForEnumValue',
                            kind: FFun({
                                args: [{
                                    name: 'enumValue',
                                    type: enumComplexType
                                }],
                                ret: macro :Int,
                                expr: macro {
                                    return enumValue == null ? -1 : ${enumReturnSwitchExpr};
                                }
                            }),
                            access: [APrivate, AInline],
                            doc: '',
                            meta: []
                        }, {
                            pos: currentPos,
                            name: 'stateInstancesByIndex',
                            kind: FVar(macro :Array<ceramic.State>, macro []),
                            access: [APrivate],
                            doc: '',
                            meta: []
                        }, {
                            pos: currentPos,
                            name: 'set',
                            kind: FFun({
                                args: [{
                                    name: 'key',
                                    type: enumComplexType
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
                                        stateInstance.machine = this;

                                        if (key == state) {
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
                        }, {
                            pos: currentPos,
                            name: 'get',
                            kind: FFun({
                                args: [{
                                    name: 'key',
                                    type: enumComplexType
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
                        }]
                    });
                }

                return TPath({
                    pack: ['ceramic'],
                    name: implName
                });

            case TInst(_, [TInst(t, params)]):
                var classType = t.get();
                if (classType.pack.length == 0 && classType.name == 'String') {

                    // String-based implementation (dynamic state machine)

                    var implName = 'StateMachine_String';
                    if (!stringStateMachineDefined) {
                        stringStateMachineDefined = true;

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

                    return TPath({
                        pack: ['ceramic'],
                        name: implName
                    });
                }

            case TInst(_, [TDynamic(t)]):

                // Just referencing any implementation in code

                return TPath({
                    pack: ['ceramic'],
                    name: 'StateMachineImpl',
                    params: [TPType(macro :Dynamic)]
                });

            default:
        }

        Context.error("Invalid type parameter. Accepted: Enum or String.", currentPos);
        return null;

    } //build

    macro static public function buildFields():Array<Field> {

        var fields = Context.getBuildFields();

        return fields;

    } //buildFields

} //StateMachineMacro
