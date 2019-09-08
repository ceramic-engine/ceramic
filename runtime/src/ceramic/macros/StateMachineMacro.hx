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

        //trace('localType: $localType');

        if (usedNames == null) {
            namesForTypePath = new Map();
            usedNames = new Map();
            usedNames.set('String', true); // Reserved
        }

        switch(localType) {

            case TInst(_, [TEnum(t, params)]):
                var enumType = t.get();

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
                        pos: Context.currentPos(),
                        kind: TDClass({
                            pack: ['ceramic'],
                            name: 'StateMachineImpl',
                            params: [TPType(TypeTools.toComplexType(TEnum(t, params)))]
                        }),
                        fields: []
                    });
                }

                return TPath({
                    pack: ['ceramic'],
                    name: implName
                });

            case TInst(_, [TInst(t, params)]):
                var classType = t.get();
                if (classType.pack.length == 0 && classType.name == 'String') {
                    var implName = 'StateMachine_String';
                    if (!stringStateMachineDefined) {
                        stringStateMachineDefined = true;

                        Context.defineType({
                            pack: ['ceramic'],
                            name: implName,
                            pos: Context.currentPos(),
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

                return TPath({
                    pack: ['ceramic'],
                    name: 'StateMachineImpl',
                    params: [TPType(macro :Dynamic)]
                });

            default:
        }

        Context.error("Invalid type parameter. Accepted: Enum or String.", Context.currentPos());
        return null;

    } //build

    macro static public function buildFields():Array<Field> {

        var fields = Context.getBuildFields();

        return fields;

    } //buildFields

} //StateMachineMacro
