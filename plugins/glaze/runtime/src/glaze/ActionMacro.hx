// Ported from gpui-pre-macros 0.3.10: src/derive_action.rs, src/register_action.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.ClassType;

using StringTools;

private typedef ActionField = {
    name:String,
    jsonName:String,
    type:ComplexType,
    hasDefault:Bool,
    isFinal:Bool,
    optional:Bool,
    kind:String
};
#end

/**
 * Build macro of `Action` implementations (Rust: `#[derive(Action)]` and the
 * `actions!` macro). See `Action` for what it generates.
 */
class ActionMacro {

    #if macro

    public static function build():Array<Field> {
        final localClass = Context.getLocalClass();
        if (localClass == null) return null;
        final cls = localClass.get();
        if (cls.isInterface) return null;

        final fields = Context.getBuildFields();
        final pos = Context.currentPos();

        // Parse @:action(...)
        var nameArgument:Null<String> = null;
        var namespace:Null<String> = null;
        var noJson = false;
        var noRegister = false;
        var deprecatedAliases:Array<String> = [];
        var deprecated:Null<String> = null;

        for (meta in cls.meta.extract(':action')) {
            for (param in meta.params) {
                switch param.expr {
                    case EConst(CIdent('noJson')) | EConst(CIdent('no_json')):
                        noJson = true;
                    case EConst(CIdent('noRegister')) | EConst(CIdent('no_register')):
                        noRegister = true;
                    case EBinop(OpAssign, {expr: EConst(CIdent(key))}, value):
                        switch key {
                            case 'namespace':
                                namespace = identOrString(value);
                            case 'name':
                                nameArgument = identOrString(value);
                            case 'deprecated':
                                deprecated = identOrString(value);
                            case 'deprecatedAliases' | 'deprecated_aliases':
                                switch value.expr {
                                    case EArrayDecl(values):
                                        for (v in values) deprecatedAliases.push(identOrString(v));
                                    case _:
                                        Context.error('in @:action: deprecatedAliases expects an array of strings', value.pos);
                                }
                            case _:
                                Context.error('in @:action: \'$key\' argument not recognized, expected '
                                    + '\'namespace\', \'name\', \'noJson\', \'noRegister\', \'deprecatedAliases\', or \'deprecated\'', param.pos);
                        }
                    case _:
                        Context.error('in @:action: invalid argument', param.pos);
                }
            }
        }

        final name = nameArgument != null ? nameArgument : cls.name;
        if (name.indexOf('::') != -1) {
            Context.error('in @:action: `name = "$name"` must not contain `::`, also specify `namespace` instead', pos);
        }
        final fullName = namespace != null ? '$namespace::$name' : name;

        // Documentation, from the doc comment (Rust: `///` lines trimmed)
        var documentation:Null<String> = null;
        if (cls.doc != null) {
            final lines = [];
            for (line in cls.doc.split('\n')) {
                var l = line.trim();
                if (l.startsWith('*')) l = l.substr(1).trim();
                lines.push(l);
            }
            final doc = lines.join('\n').trim();
            if (doc.length > 0) documentation = doc;
        }

        // Instance data fields
        final dataFields:Array<ActionField> = [];
        var userConstructor:Null<Function> = null;
        final existing = new Map<String, Field>();
        for (field in fields) {
            existing.set(field.name, field);
            final isStatic = field.access != null && field.access.contains(AStatic);
            if (field.name == 'new') {
                switch field.kind {
                    case FFun(f): userConstructor = f;
                    case _:
                }
                continue;
            }
            if (isStatic) continue;
            switch field.kind {
                case FVar(t, e) | FProp('default', _, t, e) | FProp('null', _, t, e):
                    if (t == null) {
                        Context.error('Action fields need an explicit type', field.pos);
                    }
                    final isFinal = field.access != null && field.access.contains(AFinal);
                    var jsonName = toSnakeCase(field.name);
                    if (field.meta != null) {
                        for (m in field.meta) {
                            if (m.name == ':json' && m.params.length == 1) {
                                jsonName = identOrString(m.params[0]);
                            }
                        }
                    }
                    final hasDefault = e != null;
                    dataFields.push({
                        name: field.name,
                        jsonName: jsonName,
                        type: t,
                        hasDefault: hasDefault,
                        isFinal: isFinal,
                        optional: hasDefault || isNullType(t),
                        kind: basicKind(t)
                    });
                case _:
            }
        }

        final isUnit = dataFields.length == 0;
        final selfName = cls.name;
        final selfExpr = macro $i{selfName};
        final selfType:ComplexType = TPath({pack: [], name: selfName});
        final selfTypePath:TypePath = {pack: [], name: selfName};
        final nameExpr = macro $v{fullName};

        // Fields taking part in the generated constructor
        final ctorFields = [for (f in dataFields) if (!(f.isFinal && f.hasDefault)) f];

        var generatedConstructor = false;
        if (userConstructor == null) {
            generatedConstructor = true;
            final args:Array<FunctionArg> = [];
            final body:Array<Expr> = [];
            for (f in ctorFields) {
                args.push({name: f.name, type: f.type, opt: f.optional});
                final fname = f.name;
                if (f.hasDefault) {
                    body.push(macro if ($i{fname} != null) this.$fname = $i{fname});
                }
                else {
                    body.push(macro this.$fname = $i{fname});
                }
            }
            if (superHasField(cls, 'new')) {
                body.unshift(macro super());
            }
            fields.push({
                name: 'new',
                access: [APublic],
                kind: FFun({args: args, ret: null, expr: macro $b{body}}),
                pos: pos
            });
        }

        // Can the action be built with `new` from its fields?
        final canConstruct = generatedConstructor || (isUnit && userConstructor.args.filter(a -> !a.opt && a.value == null).length == 0);

        function addMethod(fieldName:String, access:Array<Access>, fn:Function) {
            if (existing.exists(fieldName)) return;
            final isStatic = access.contains(AStatic);
            if (!isStatic && superHasField(cls, fieldName)) {
                access.push(AOverride);
            }
            fields.push({name: fieldName, access: access, kind: FFun(fn), pos: pos});
        }

        // name()
        addMethod('name', [APublic], {args: [], ret: macro :String, expr: macro return $nameExpr});

        // nameForType()
        addMethod('nameForType', [APublic, AStatic], {args: [], ret: macro :String, expr: macro return $nameExpr});

        // Expression creating a copy of `src` (an expression of the action type)
        function constructFrom(src:Expr):Expr {
            if (canConstruct) {
                if (generatedConstructor) {
                    final args = [for (f in ctorFields) { final n = f.name; macro $src.$n; }];
                    return macro new $selfTypePath($a{args});
                }
                return macro new $selfTypePath();
            }
            final assigns = [for (f in dataFields) { final n = f.name; macro Reflect.setField(__copy, $v{n}, $src.$n); }];
            return macro {
                final __copy:$selfType = Type.createEmptyInstance($selfExpr);
                $b{assigns};
                __copy;
            };
        }

        // boxedClone()
        addMethod('boxedClone', [APublic], {
            args: [],
            ret: macro :glaze.Action,
            expr: macro return ${constructFrom(macro this)}
        });

        // partialEq()
        {
            var compare:Expr = macro true;
            for (f in dataFields) {
                final n = f.name;
                final test = f.kind != 'any'
                    ? macro this.$n == __other.$n
                    : macro glaze.ActionJson.valueEquals(this.$n, __other.$n);
                compare = macro $compare && $test;
            }
            final body = isUnit
                ? macro {
                    return action != null && (cast Type.getClass(action) : Class<Dynamic>) == (cast $selfExpr : Class<Dynamic>);
                }
                : macro {
                    if (action == null || (cast Type.getClass(action) : Class<Dynamic>) != (cast $selfExpr : Class<Dynamic>)) return false;
                    final __other:$selfType = cast action;
                    return $compare;
                };
            addMethod('partialEq', [APublic], {
                args: [{name: 'action', type: macro :glaze.Action}],
                ret: macro :Bool,
                expr: body
            });
        }

        // build(value)
        {
            var body:Expr;
            if (noJson) {
                final message = '$fullName cannot be built from JSON';
                body = macro throw new haxe.Exception($v{message});
            }
            else if (isUnit && canConstruct) {
                body = macro return new $selfTypePath();
            }
            else if (generatedConstructor) {
                final args = [for (f in ctorFields) {
                    final reader = switch f.kind {
                        case 'Bool': 'readBool';
                        case 'Int': 'readInt';
                        case 'Float': 'readFloat';
                        case 'String': 'readString';
                        case _: 'readAny';
                    }
                    macro glaze.ActionJson.$reader(__object, $v{f.jsonName}, $v{f.optional});
                }];
                body = macro {
                    final __object:Dynamic = glaze.ActionJson.object(value, $nameExpr);
                    return new $selfTypePath($a{args});
                };
            }
            else {
                final assigns = [for (f in dataFields) {
                    final n = f.name;
                    macro if (Reflect.hasField(__object, $v{f.jsonName})) Reflect.setField(__result, $v{n}, Reflect.field(__object, $v{f.jsonName}));
                }];
                body = macro {
                    final __object:Dynamic = glaze.ActionJson.object(value, $nameExpr);
                    final __result:$selfType = Type.createEmptyInstance($selfExpr);
                    $b{assigns};
                    return __result;
                };
            }
            addMethod('build', [APublic, AStatic], {
                args: [{name: 'value', type: macro :Dynamic}],
                ret: macro :glaze.Action,
                expr: body
            });
        }

        // deprecatedAliases(), deprecationMessage(), documentation()
        addMethod('deprecatedAliases', [APublic, AStatic], {
            args: [], ret: macro :Array<String>, expr: macro return $v{deprecatedAliases}
        });
        addMethod('deprecationMessage', [APublic, AStatic], {
            args: [], ret: macro :Null<String>, expr: macro return $v{deprecated}
        });
        addMethod('documentation', [APublic, AStatic], {
            args: [], ret: macro :Null<String>, expr: macro return $v{documentation}
        });

        // Registration (Rust: `register_action!` with `inventory`)
        if (!noRegister) {
            if (!cls.meta.has(':keep')) {
                cls.meta.add(':keep', [], pos);
            }
            final registration = macro glaze.ActionRegistry.registerMacroAction(new glaze.MacroActionData(
                $nameExpr,
                Type.getClassName($selfExpr),
                $selfExpr.build,
                $v{deprecatedAliases},
                $v{deprecated},
                $v{documentation}
            ));
            final init = existing.get('__init__');
            if (init != null) {
                switch init.kind {
                    case FFun(f):
                        f.expr = macro {
                            $registration;
                            ${f.expr};
                        };
                    case _:
                }
            }
            else {
                fields.push({
                    name: '__init__',
                    access: [AStatic],
                    kind: FFun({args: [], ret: null, expr: macro $registration}),
                    pos: pos
                });
            }
        }

        return fields;
    }

    static function identOrString(e:Expr):String {
        return switch e.expr {
            case EConst(CIdent(s)) | EConst(CString(s, _)): s;
            case EField(sub, field): identOrString(sub) + '::' + field;
            case _:
                Context.error('expected an identifier or a string', e.pos);
                null;
        }
    }

    static function superHasField(cls:ClassType, name:String):Bool {
        var sup = cls.superClass;
        while (sup != null) {
            final c = sup.t.get();
            if (name == 'new') {
                if (c.constructor != null) return true;
            }
            else {
                for (f in c.fields.get()) {
                    if (f.name == name) return true;
                }
            }
            sup = c.superClass;
        }
        return false;
    }

    static function isNullType(t:ComplexType):Bool {
        return switch t {
            case TPath({name: 'Null', pack: []}) | TPath({name: 'StdTypes', sub: 'Null'}): true;
            case TOptional(_): true;
            case _: false;
        }
    }

    /**
     * 'Bool', 'Int', 'Float', 'String' (also inside `Null<>`), or 'any'.
     */
    static function basicKind(t:ComplexType):String {
        return switch t {
            case TPath({name: 'Null', pack: [], params: [TPType(inner)]}): basicKind(inner);
            case TPath({name: name, pack: [], sub: null}) if (name == 'Bool' || name == 'Int' || name == 'Float' || name == 'String'):
                name;
            case _: 'any';
        }
    }

    static function toSnakeCase(name:String):String {
        final buf = new StringBuf();
        for (i in 0...name.length) {
            final c = name.charCodeAt(i);
            final isUpper = c >= 'A'.code && c <= 'Z'.code;
            if (isUpper) {
                final prev = i > 0 ? name.charCodeAt(i - 1) : -1;
                final next = i + 1 < name.length ? name.charCodeAt(i + 1) : -1;
                final prevLowerOrDigit = (prev >= 'a'.code && prev <= 'z'.code) || (prev >= '0'.code && prev <= '9'.code);
                final prevUpper = prev >= 'A'.code && prev <= 'Z'.code;
                final nextLower = next >= 'a'.code && next <= 'z'.code;
                if (i > 0 && (prevLowerOrDigit || (prevUpper && nextLower)) && prev != '_'.code) {
                    buf.addChar('_'.code);
                }
                buf.addChar(c + 32);
            }
            else {
                buf.addChar(c);
            }
        }
        return buf.toString();
    }

    #end

}
