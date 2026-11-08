// New code for the Haxe port of GPUI (no GPUI origin): the `component()`
// notation of Glaze on `RenderOnce` classes. See NOTICE.md.
package glaze;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

/**
 * Build macro of every `RenderOnce` class (`@:autoBuild` on the interface):
 * a class with a public constructor gets a static `component(...)` with the
 * constructor's parameters (type parameters kept) that returns `new X(...)`,
 * so a component is placed in a tree as `X.component(...)`, the notation of
 * `glaze.Component`. Nothing is generated for an abstract class, a class
 * without a public constructor of its own, or a class that already defines
 * `component` (a hand written one, like the stateful `Input.component()`),
 * or a `glaze.Component` (a `RenderOnce` too, built by `ComponentMacro`,
 * which generates its `component(...)`: the two macros may run in any order
 * on such a class, and this one more than once when the class also
 * implements an interface extending `RenderOnce`).
 */
class RenderOnceMacro {

    #if macro

    public static function build():Array<Field> {

        final localClass = Context.getLocalClass();
        if (localClass == null) return null;
        final cls = localClass.get();
        if (cls.isInterface || cls.isAbstract) return null;
        if (extendsComponent(cls)) return null;

        final fields = Context.getBuildFields();

        var constructor:Null<Function> = null;
        for (field in fields) {
            if (field.name == 'component') return null;
            if (field.name == 'new') {
                switch field.kind {
                    case FFun(f):
                        if (field.access != null && Lambda.exists(field.access, a -> a.match(APublic))) {
                            constructor = f;
                        }
                    case _:
                }
            }
        }
        if (constructor == null) return null;

        final pos = Context.currentPos();

        // The class with its own type parameters, as the return type and the
        // type of the `new`
        final selfType = Context.toComplexType(Context.getLocalType());
        final typePath:TypePath = switch selfType {
            case TPath(p): p;
            case _: return null;
        }

        // Type parameters of the class, with their constraints
        final params:Array<TypeParamDecl> = [];
        for (param in cls.params) {
            final constraints:Array<ComplexType> = switch param.t {
                case TInst(ref, _):
                    switch ref.get().kind {
                        case KTypeParameter(list): [for (t in list) Context.toComplexType(t)];
                        case _: [];
                    }
                case _: [];
            }
            params.push({name: param.name, constraints: constraints});
        }

        final args:Array<FunctionArg> = [for (arg in constructor.args) {
            name: arg.name,
            opt: arg.opt,
            type: arg.type,
            value: arg.value,
            meta: arg.meta
        }];
        final callArgs:Array<Expr> = [for (arg in constructor.args) macro $i{arg.name}];

        fields.push({
            name: 'component',
            doc: 'Places a `${cls.name}` in a tree: `${cls.name}.component(...)` is `new ${cls.name}(...)` with the same arguments.',
            access: [APublic, AStatic],
            pos: pos,
            kind: FFun({
                args: args,
                params: params,
                ret: selfType,
                expr: macro return ${{expr: ENew(typePath, callArgs), pos: pos}}
            })
        });

        return fields;

    }

    /**
     * Whether `cls` descends from `glaze.Component`.
     */
    static function extendsComponent(cls:ClassType):Bool {
        var parent = cls.superClass;
        while (parent != null) {
            final parentClass = parent.t.get();
            if (parentClass.name == 'Component' && parentClass.pack.join('.') == 'glaze') {
                return true;
            }
            parent = parentClass.superClass;
        }
        return false;
    }

    #end

}
