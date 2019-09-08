package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;

using haxe.macro.ExprTools;

class StateMachineMacro {

    static var usedNames:Map<String,Bool> = null;

    static var namesForTypePath:Map<String,String> = null;

    static var usedNamesWithEnumValues:Map<String,Array<String>> = null;

    static var stringStateMachineDefined:Bool = false;

    /** Depending on the generic type parameter used, will return (and create, if needed) a specific implementation. */
    macro static public function buildGeneric():ComplexType {

        var localType = Context.getLocalType();
        var currentPos = Context.currentPos();

        //trace('localType: $localType');

        if (usedNames == null) {
            namesForTypePath = new Map();
            usedNamesWithEnumValues = new Map();
            usedNames = new Map();
            usedNames.set('String', true); // Reserved
        }

        switch(localType) {

            case TInst(_, [TEnum(t, params)]):

                // Enum-based implementation (type-safe state machine)

                var enumType = t.get();
                var enumComplexType = TypeTools.toComplexType(TEnum(t, params));

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

                    // Generate enum switch to retrieve index from enum value
                    var enumCases = [];
                    var enumValues = [];
                    for (aConstruct in enumType.constructs) {
                        enumValues.push(aConstruct.name);
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

                    // Keep enum values as they will be needed in autoBuild macro
                    usedNamesWithEnumValues.set(implName, enumValues);

                    // Create dedicated type that uses our enum
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

    /** Called on `StateMachinImpl` subclasses. Will generate code that will automatically
        call `enter{State}()`, `update{State}(delta)` and `exit{State}()` from the enum definition.
        Won't do anything on dynamic (String-based) implementation */
    macro static public function buildFields():Array<Field> {

        var fields = Context.getBuildFields();
        var localClass = Context.getLocalClass().get();
        var currentPos = Context.currentPos();

        if (usedNamesWithEnumValues.exists(localClass.name)) {
            // Not transforming the class generated from genericBuild, only its subclasses
            return fields;
        }

        // Gather every field by name
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        var enumValues:Array<String> = null;

        // Also check parent fields
        var parentHold = localClass.superClass;
        var parent = parentHold != null ? parentHold.t : null;
        var numParents = 0;
        while (parent != null) {

            var fetchedParent = parent.get();

            if (enumValues == null) {
                enumValues = usedNamesWithEnumValues.get(fetchedParent.name);
            }

            for (field in fetchedParent.fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = fetchedParent.superClass;
            parent = parentHold != null ? parentHold.t : null;
            numParents++;
        }

        if (enumValues == null) {
            // We are not using an enum as generic type, stop here
            return fields;
        }

        var methodSuffixes = [];
        for (value in enumValues) {
            methodSuffixes.push(upperCaseToCamelCase(value));
        }

        var enterCases = [];
        var updateCases = [];
        var exitCases = [];

        for (i in 0...enumValues.length) {
            var enumValue = enumValues[i];
            var methodSuffix = methodSuffixes[i];

            enterCases.push({
                expr: {
                    expr: fieldsByName.exists('enter$methodSuffix') ? ECall({
                        expr: EConst(CIdent('enter$methodSuffix')),
                        pos: currentPos
                    }, []) : EBlock([]),
                    pos: currentPos
                },
                values: [{
                    expr: EConst(CIdent(enumValue)),
                    pos: currentPos
                }]
            });

            updateCases.push({
                expr: {
                    expr: fieldsByName.exists('update$methodSuffix') ? ECall({
                        expr: EConst(CIdent('update$methodSuffix')),
                        pos: currentPos
                    }, [macro delta]) : EBlock([]),
                    pos: currentPos
                },
                values: [{
                    expr: EConst(CIdent(enumValue)),
                    pos: currentPos
                }]
            });

            exitCases.push({
                expr: {
                    expr: fieldsByName.exists('exit$methodSuffix') ? ECall({
                        expr: EConst(CIdent('exit$methodSuffix')),
                        pos: currentPos
                    }, []) : EBlock([]),
                    pos: currentPos
                },
                values: [{
                    expr: EConst(CIdent(enumValue)),
                    pos: currentPos
                }]
            });
        }

        var enterSwitchExpr = {
            expr: ESwitch({
                expr: EParenthesis({
                    expr: EConst(CIdent('state')),
                    pos: currentPos
                }),
                pos: currentPos
            }, enterCases, null),
            pos: currentPos
        };

        var updateSwitchExpr = {
            expr: ESwitch({
                expr: EParenthesis({
                    expr: EConst(CIdent('state')),
                    pos: currentPos
                }),
                pos: currentPos
            }, updateCases, null),
            pos: currentPos
        };

        var exitSwitchExpr = {
            expr: ESwitch({
                expr: EParenthesis({
                    expr: EConst(CIdent('state')),
                    pos: currentPos
                }),
                pos: currentPos
            }, exitCases, null),
            pos: currentPos
        };

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
            access: [AOverride],
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

                    if (paused || state == null) return;
                    
                    // Call hook method from state (if any)
                    ${updateSwitchExpr};

                    if (currentStateInstance != null) {
                        currentStateInstance.update(delta);
                    }
                }
            }),
            access: [AOverride],
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
            access: [AOverride],
            doc: '',
            meta: []
        });

        return fields;

    } //buildFields

    /** Transforms `SOME_IDENTIFIER` to `SomeIdentifier` */
    static function upperCaseToCamelCase(input:String, firstLetterUppercase:Bool = true):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var nextLetterUpperCase = firstLetterUppercase;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '_') {
                nextLetterUpperCase = true;
            }
            else if (nextLetterUpperCase) {
                nextLetterUpperCase = false;
                res.add(c.toUpperCase());
            }
            else {
                res.add(c.toLowerCase());
            }

            i++;
        }

        return res.toString();

    } //upperCaseToCamelCase

} //StateMachineMacro
