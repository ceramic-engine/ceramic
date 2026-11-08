// New code for the Haxe port of GPUI (no GPUI origin): the build macro of
// `glaze.Component` (see Component.hx). See NOTICE.md.
package glaze;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.MacroStringTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import haxe.macro.TypedExprTools;

using StringTools;

/**
 * A `@prop` field of the class being built.
 */
private class PropInfo {

    /** The prop name (the chained setter) */
    public final name:String;

    /** The storage field (`nameProp`) */
    public final storage:String;

    public final type:ComplexType;

    public final pos:Position;

    /** `true` when the prop is observable in persistent mode */
    public final observable:Bool;

    /** Index of the prop in the "set" masks */
    public final index:Int;

    public function new(name:String, storage:String, type:ComplexType, pos:Position, observable:Bool, index:Int) {
        this.name = name;
        this.storage = storage;
        this.type = type;
        this.pos = pos;
        this.observable = observable;
        this.index = index;
    }

}

/**
 * Builds every subclass of `glaze.Component` (`@:autoBuild`):
 *
 * - detects the mode: stateless (only `@prop` fields and methods) or
 *   persistent (`@observe`, `@compute`, `@autorun`, an `init()` or
 *   `destroy()` override, the class metadata `@persist`, or a persistent
 *   parent class);
 * - renames each `@prop var x` to the storage field `xProp` (`@:noCompletion`;
 *   the reads of `x` and `this.x` in the methods of the class are renamed
 *   too, as well as those of `children`, stored as `childrenProp`), and
 *   generates the chained setter `x(value):X`, unless the class defines a
 *   method `x`;
 * - generates `.at(key)`, `.child(...)`, `.children(...)`, the static
 *   `component(...)` with the parameters of the constructor, and the
 *   internals used by `ComponentBuilder`;
 * - in persistent mode, makes the data props and the `@observe` fields
 *   observable with tracker's macros (the class is not an entity: the same
 *   path as `tracker.Observable` on a plain class), turns `@compute`
 *   methods into an observable field kept up to date by an autorun, and
 *   starts the `@autorun` methods when the instance is created.
 */
class ComponentMacro {

    /** The number of props one "set" mask field holds */
    static inline final MASK_BITS = 30;

    macro static public function build():Array<Field> {

        final cls = Context.getLocalClass().get();
        final fields = Context.getBuildFields();
        final pos = Context.currentPos();
        final classPath = cls.pack.length > 0 ? cls.pack.join('.') + '.' + cls.name : cls.name;
        final thisPath:TypePath = {name: cls.name, pack: cls.pack, params: cls.params.length > 0 ? [for (p in cls.params) TPType(TypeTools.toComplexType(p.t))] : null};
        final thisType = TPath(thisPath);

        // The fields of the parents (methods not to generate again, tracker
        // fields already there) and the depth in the component hierarchy
        final parentFields = new Map<String, Bool>();
        var parentPersistent = false;
        var parentIsComponent = false;
        var depth = 0;
        var parentHold = cls.superClass;
        while (parentHold != null) {
            final parent = parentHold.t.get();
            final parentPath = parent.pack.length > 0 ? parent.pack.join('.') + '.' + parent.name : parent.name;
            if (parentPath == 'glaze.Component') {
                break;
            }
            parentIsComponent = true;
            if (parent.meta.has(':glazePersistent')) {
                parentPersistent = true;
            }
            for (field in parent.fields.get()) {
                parentFields.set(field.name, true);
            }
            depth++;
            parentHold = parent.superClass;
        }

        // Fields by name (the class and its parents, for tracker's macros)
        final fieldsByName = new Map<String, Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }
        for (name in parentFields.keys()) {
            fieldsByName.set(name, true);
        }

        // Mode
        var stateful = false;
        var persistMeta:Null<MetadataEntry> = null;
        for (meta in cls.meta.get()) {
            if (meta.name == 'persist') {
                persistMeta = meta;
            }
        }
        for (field in fields) {
            if (field.name == 'init' || field.name == 'destroy') {
                stateful = true;
            }
            if (field.meta != null) {
                for (meta in field.meta) {
                    if (meta.name == 'observe' || meta.name == 'compute' || meta.name == 'autorun') {
                        stateful = true;
                    }
                }
            }
        }
        if (persistMeta != null && persistMeta.params != null && persistMeta.params.length > 0) {
            if (stateful || parentPersistent) {
                Context.error('A component with @observe, @compute, @autorun, init() or destroy() keeps its state: it is always persistent (write @persist without parameter, or remove it)', persistMeta.pos);
            }
            Context.error('@persist takes no parameter: a component is persistent when it has one', persistMeta.pos);
        }
        final persistent = stateful || parentPersistent || persistMeta != null;
        if (persistent && parentIsComponent && !parentPersistent) {
            Context.error('A persistent component cannot extend a stateless one (${cls.superClass.t.get().name}): mark the parent @persist, or make this class stateless', pos);
        }
        if (persistent && !cls.meta.has(':glazePersistent')) {
            cls.meta.add(':glazePersistent', [], pos);
        }

        // Props
        final props:Array<PropInfo> = [];
        final renames = new Map<String, String>();
        var constructor:Null<Field> = null;
        var renderField:Null<Field> = null;
        final methodNames = new Map<String, Bool>();
        for (field in fields) {
            switch field.kind {
                case FFun(_):
                    methodNames.set(field.name, true);
                    if (field.name == 'new') {
                        constructor = field;
                    }
                    else if (field.name == 'render') {
                        renderField = field;
                    }
                case _:
            }
        }
        for (field in fields) {
            var propMeta:Null<MetadataEntry> = null;
            if (field.meta != null) {
                for (meta in field.meta) {
                    if (meta.name == 'prop') {
                        propMeta = meta;
                    }
                }
            }
            if (propMeta == null) {
                continue;
            }
            if (field.name == 'component') {
                Context.error('A @prop cannot be named "component": component() is the static method placing the component', field.pos);
            }
            if (field.access != null && field.access.indexOf(AStatic) != -1) {
                Context.error('A @prop cannot be static', field.pos);
            }
            var type:Null<ComplexType> = null;
            switch field.kind {
                case FVar(t, _):
                    type = t;
                case FProp(_, _, _, _):
                    Context.error('A @prop is a plain var (the chained setter is generated)', field.pos);
                case FFun(_):
                    Context.error('@prop applies to a var', field.pos);
            }
            if (type == null) {
                Context.error('A @prop needs an explicit type', field.pos);
            }
            var unobserved = false;
            if (propMeta.params != null) {
                for (param in propMeta.params) {
                    switch param.expr {
                        case EConst(CIdent('unobserved')):
                            unobserved = true;
                        case _:
                            Context.error('Unknown @prop parameter (only "unobserved" is accepted)', param.pos);
                    }
                }
            }
            final observable = persistent && !unobserved && !isFunctionType(type);
            final storage = field.name + 'Prop';
            if (fieldsByName.exists(storage)) {
                Context.error('The @prop "${field.name}" is stored as "$storage", which the class already defines', field.pos);
            }
            props.push(new PropInfo(field.name, storage, type, field.pos, observable, props.length));
            renames.set(field.name, storage);
            field.name = storage;
            fieldsByName.set(storage, true);
            final meta = [];
            for (m in field.meta) {
                if (m.name != 'prop') meta.push(m);
            }
            if (observable) {
                meta.push({name: 'observe', params: [], pos: field.pos});
            }
            // The storage field stays out of completion: the prop is read by
            // its own name in the class and set by its chained setter outside
            meta.push({name: ':noCompletion', params: [], pos: field.pos});
            field.meta = meta;
        }

        // Reads of the props (and of `children`, stored as `childrenProp`
        // in the base class) in the class's own code go to the storage fields
        renames.set('children', 'childrenProp');
        {
            for (field in fields) {
                switch field.kind {
                    case FFun(f):
                        if (f.expr != null) {
                            f.expr = new PropRenamer(renames, f.args).rename(f.expr);
                        }
                    case FVar(t, e):
                        if (e != null) {
                            field.kind = FVar(t, new PropRenamer(renames, null).rename(e));
                        }
                    case FProp(g, s, t, e):
                        if (e != null) {
                            field.kind = FProp(g, s, t, new PropRenamer(renames, null).rename(e));
                        }
                }
            }
        }

        // `render` implements the public abstract method of the base class
        if (renderField != null) {
            if (renderField.access == null) renderField.access = [];
            if (renderField.access.indexOf(APublic) == -1 && renderField.access.indexOf(APrivate) == -1) {
                renderField.access.push(APublic);
            }
        }

        final newFields:Array<Field> = [];

        // Chained setters
        final maskCount = Math.ceil(props.length / MASK_BITS);
        for (prop in props) {
            if (methodNames.exists(prop.name) || parentFields.exists(prop.name)) {
                // Written by hand (an alias, a conversion, a validation)
                continue;
            }
            final storage = prop.storage;
            final argName = prop.name;
            final body:Array<Expr> = [];
            body.push(macro this.$storage = $i{argName});
            if (persistent) {
                final mask = maskName(depth, Std.int(prop.index / MASK_BITS));
                final bit = 1 << (prop.index % MASK_BITS);
                body.push(macro this.$mask = this.$mask | $v{bit});
            }
            body.push(macro return this);
            newFields.push({
                pos: prop.pos,
                name: prop.name,
                kind: FFun({
                    args: [{name: argName, type: prop.type}],
                    ret: thisType,
                    expr: macro $b{body}
                }),
                access: [APublic],
                doc: 'Sets the `${prop.name}` prop.',
                meta: []
            });
        }

        // `.at(key)`, `.child(...)`, `.children(...)`
        if (!methodNames.exists('at')) {
            final overrideAccess = parentFields.exists('at') ? [APublic, AOverride] : [APublic];
            newFields.push({
                pos: pos,
                name: 'at',
                kind: FFun({
                    args: [{name: 'key', type: macro :glaze.ElementIdArg}],
                    ret: thisType,
                    expr: macro {
                        this.__key = key;
                        return this;
                    }
                }),
                access: overrideAccess,
                doc: 'The identity of this component in its parent (needed when the same `component()` call runs in a loop); for a stateless component, the id of the element isolating its states.',
                meta: []
            });
        }
        if (!methodNames.exists('child')) {
            final overrideAccess = parentFields.exists('child') ? [APublic, AOverride] : [APublic];
            newFields.push({
                pos: pos,
                name: 'child',
                kind: FFun({
                    args: [{name: 'child', type: macro :glaze.IntoElement}],
                    ret: thisType,
                    expr: macro {
                        if (child != null) {
                            var children = this.childrenProp;
                            if (children == null) {
                                children = [];
                                this.childrenProp = children;
                            }
                            children.push(child);
                        }
                        return this;
                    }
                }),
                access: overrideAccess,
                doc: 'Adds a child, available to `render` as `children` (a null child is skipped).',
                meta: []
            });
        }
        if (!methodNames.exists('children')) {
            final overrideAccess = parentFields.exists('children') ? [APublic, AOverride] : [APublic];
            newFields.push({
                pos: pos,
                name: 'children',
                kind: FFun({
                    args: [{name: 'children', type: macro :Array<glaze.IntoElement>}],
                    ret: thisType,
                    expr: macro {
                        var current = this.childrenProp;
                        for (child in children) {
                            if (child != null) {
                                if (current == null) {
                                    current = [];
                                    this.childrenProp = current;
                                }
                                current.push(child);
                            }
                        }
                        return this;
                    }
                }),
                access: overrideAccess,
                doc: 'Adds children, available to `render` as `children` (null children are skipped).',
                meta: []
            });
        }

        // The element id naming the class (a stateless component renders
        // under it, a persistent one is checked against it)
        if (!cls.isAbstract) {
            newFields.push({
                pos: pos,
                name: '__classElementId',
                kind: FVar(macro :Null<glaze.ElementId>, macro null),
                access: [AStatic, APrivate],
                meta: [{name: ':noCompletion', params: [], pos: pos}]
            });
            newFields.push({
                pos: pos,
                name: '__elementId',
                kind: FFun({
                    args: [],
                    ret: macro :glaze.ElementId,
                    expr: macro {
                        var id = __classElementId;
                        if (id == null) {
                            id = glaze.ElementId.Name($v{classPath});
                            __classElementId = id;
                        }
                        return id;
                    }
                }),
                access: parentFields.exists('__elementId') ? [APublic, AOverride] : [APublic],
                meta: [{name: ':noCompletion', params: [], pos: pos}]
            });
        }

        // The constructor arguments, which become those of `component(...)`
        var ctorArgs:Array<FunctionArg> = [];
        if (constructor != null) {
            switch constructor.kind {
                case FFun(f):
                    ctorArgs = f.args;
                case _:
            }
        }
        else {
            // The constructor of the closest parent, from its type
            var parentHold = cls.superClass;
            while (parentHold != null) {
                final parent = parentHold.t.get();
                if (parent.constructor != null) {
                    switch Context.follow(parent.constructor.get().type) {
                        case TFun(args, _):
                            ctorArgs = [for (a in args) {
                                name: a.name,
                                type: TypeTools.toComplexType(a.t),
                                opt: a.opt
                            }];
                        case _:
                    }
                    break;
                }
                parentHold = parent.superClass;
            }
        }
        for (arg in ctorArgs) {
            if (arg.type == null) {
                Context.error('The constructor of a component needs typed arguments: "${arg.name}" becomes an argument of component()', constructor != null ? constructor.pos : pos);
            }
            if (arg.name == 'pos' && persistent) {
                Context.error('A persistent component cannot have a constructor argument named "pos": component() uses it for its code position', constructor.pos);
            }
        }
        final ctorArgExprs:Array<Expr> = [for (arg in ctorArgs) macro $i{arg.name}];
        final typeParams:Array<TypeParamDecl> = [for (p in cls.params) {name: p.name}];

        if (!cls.isAbstract) {
            final componentArgs:Array<FunctionArg> = [for (arg in ctorArgs) {name: arg.name, type: arg.type, opt: arg.opt, value: arg.value, meta: arg.meta}];
            var componentBody:Expr;
            if (persistent) {
                componentArgs.push({name: 'pos', type: macro :haxe.PosInfos, opt: true});
                final statements:Array<Expr> = [];
                statements.push(macro final proto:$thisType = cast Type.createEmptyInstance(cast $p{cls.pack.concat([cls.name])}));
                // The identity: the position of the call, scoped by the class (two
                // classes on one line do not collide; the same class does, hence `.at`)
                statements.push(macro proto.__key = glaze.ElementId.NamedChild(glaze.ElementId.CodeLocation(pos.fileName, pos.lineNumber), $v{classPath}));
                for (arg in ctorArgs) {
                    final argField = '__arg_' + arg.name;
                    statements.push(macro proto.$argField = $i{arg.name});
                }
                statements.push(macro return proto);
                componentBody = macro $b{statements};
            }
            else {
                componentBody = macro return new $thisPath($a{ctorArgExprs});
            }
            if (fieldsByName.exists('component')) {
                Context.error('A component class cannot define "component": the static component() method is generated', pos);
            }
            newFields.push({
                pos: pos,
                name: 'component',
                kind: FFun({
                    args: componentArgs,
                    ret: thisType,
                    expr: componentBody,
                    params: typeParams
                }),
                access: [APublic, AStatic],
                doc: persistent
                    ? 'Places this component in a parent: the instance is found by the position of this call (or by `.at(key)`), created the first time, and destroyed when its parent stops rendering it. Chain the props after it.'
                    : 'Places this component in a parent: a new instance, rendered with the parent. Chain the props after it.',
                meta: []
            });
        }

        if (persistent) {
            buildPersistent(cls, fields, newFields, fieldsByName, props, ctorArgs, thisPath, depth, maskCount, classPath, pos);
            if (!parentPersistent) {
                buildOwner(newFields, pos);
            }
        }
        else {
            refuseStatelessOwner(classPath);
        }

        return fields.concat(newFields);
    }

    /**
     * The `tracker.Owner` implementation of a persistent component (in the
     * first persistent class of a hierarchy): the lifecycle is the one of the
     * host entity (`ComponentBuilder.ComponentHost`), which runs the destroy
     * handlers after `destroy()`, giving them the component.
     */
    static function buildOwner(newFields:Array<Field>, pos:Position):Void {
        final noCompletion = [{name: ':noCompletion', params: [], pos: pos}];
        final optionalOwner = Context.defined('tracker_optional_owner');
        final debugEvents = Context.defined('tracker_debug_events');

        newFields.push({
            pos: pos,
            name: '__ownerHost',
            kind: FVar(macro :Null<glaze.ComponentBuilder.ComponentHost>, macro null),
            access: [APrivate],
            meta: noCompletion
        });
        newFields.push({
            pos: pos,
            name: '__destroyHandlers',
            kind: FVar(macro :Null<Array<(tracker.Owner) -> Void>>, macro null),
            access: [APrivate],
            meta: noCompletion
        });
        newFields.push({
            pos: pos,
            name: '__destroyUnbinds',
            kind: FVar(macro :Null<Array<Null<() -> Void>>>, macro null),
            access: [APrivate],
            meta: noCompletion
        });
        newFields.push({
            pos: pos,
            name: '__attachHost',
            kind: FFun({
                args: [{name: 'host', type: macro :glaze.ComponentBuilder.ComponentHost}],
                ret: macro :Void,
                expr: macro this.__ownerHost = host
            }),
            access: [APublic, AOverride],
            meta: noCompletion
        });
        newFields.push({
            pos: pos,
            name: 'get_destroyed',
            kind: FFun({
                args: [],
                ret: macro :Bool,
                expr: macro {
                    final host = this.__ownerHost;
                    return host != null && host.destroyed;
                }
            }),
            access: [AOverride],
            meta: noCompletion
        });

        final onceArgs:Array<FunctionArg> = [
            {name: 'owner', type: macro :Null<tracker.Owner>, opt: optionalOwner},
            {name: 'handler', type: macro :(tracker.Owner) -> Void}
        ];
        if (debugEvents) {
            onceArgs.push({name: 'pos', type: macro :haxe.PosInfos, opt: true});
        }
        newFields.push({
            pos: pos,
            name: 'onceDestroy',
            kind: FFun({
                args: onceArgs,
                ret: macro :Void,
                expr: macro {
                    // An owner of this subscription: the handler goes away with it
                    var unbind:Null<() -> Void> = null;
                    if (owner != null) {
                        if (owner.destroyed) {
                            throw 'Failed to bind event destroy because owner is destroyed!';
                        }
                        final subscriptionOwner = owner;
                        var ownerDestroyed:Null<(tracker.Owner) -> Void> = null;
                        ownerDestroyed = _ -> {
                            ownerDestroyed = null;
                            this.offDestroy(handler);
                        };
                        subscriptionOwner.onceDestroy(null, ownerDestroyed);
                        unbind = () -> {
                            if (ownerDestroyed != null) {
                                subscriptionOwner.offDestroy(ownerDestroyed);
                                ownerDestroyed = null;
                            }
                        };
                    }
                    if (this.__destroyHandlers == null) {
                        this.__destroyHandlers = [];
                        this.__destroyUnbinds = [];
                    }
                    this.__destroyHandlers.push(handler);
                    this.__destroyUnbinds.push(unbind);
                }
            }),
            access: [APublic, AOverride],
            meta: []
        });
        newFields.push({
            pos: pos,
            name: 'offDestroy',
            kind: FFun({
                args: [{name: 'handler', type: macro :(tracker.Owner) -> Void, opt: true}],
                ret: macro :Void,
                expr: macro {
                    final handlers = this.__destroyHandlers;
                    if (handlers == null) {
                        return;
                    }
                    final unbinds = this.__destroyUnbinds;
                    if (handler == null) {
                        this.__destroyHandlers = null;
                        this.__destroyUnbinds = null;
                        for (unbind in unbinds) {
                            if (unbind != null) unbind();
                        }
                        return;
                    }
                    final index = handlers.indexOf(handler);
                    if (index != -1) {
                        final unbind = unbinds[index];
                        handlers.splice(index, 1);
                        unbinds.splice(index, 1);
                        if (unbind != null) unbind();
                    }
                }
            }),
            access: [APublic, AOverride],
            meta: []
        });
        newFields.push({
            pos: pos,
            name: '__emitDestroy',
            kind: FFun({
                args: [],
                ret: macro :Void,
                expr: macro {
                    final handlers = this.__destroyHandlers;
                    if (handlers == null) {
                        return;
                    }
                    final unbinds = this.__destroyUnbinds;
                    this.__destroyHandlers = null;
                    this.__destroyUnbinds = null;
                    for (i in 0...handlers.length) {
                        final unbind = unbinds[i];
                        if (unbind != null) unbind();
                        handlers[i](this);
                    }
                }
            }),
            access: [APublic, AOverride],
            meta: noCompletion
        });
    }

    /** The stateless component classes, checked once typed */
    static var statelessClasses:Null<Map<String, Bool>> = null;

    static final checkedStatelessClasses = new Map<String, Bool>();

    /**
     * A stateless component is rebuilt at every render: it cannot own
     * handlers. Once the code is typed, passing `this` where a
     * `tracker.Owner` is expected (an argument, a variable, an assignment)
     * in such a class is a compile error.
     */
    static function refuseStatelessOwner(classPath:String):Void {
        if (Context.defined('display') || Context.defined('completion')) {
            return;
        }
        if (statelessClasses == null) {
            statelessClasses = new Map();
            Context.onAfterTyping(checkStatelessOwners);
        }
        statelessClasses.set(classPath, true);
    }

    static function checkStatelessOwners(types:Array<ModuleType>):Void {
        for (type in types) {
            switch type {
                case TClassDecl(ref):
                    final cls = ref.get();
                    final path = cls.pack.length > 0 ? cls.pack.join('.') + '.' + cls.name : cls.name;
                    if (!statelessClasses.exists(path) || checkedStatelessClasses.exists(path)) {
                        continue;
                    }
                    checkedStatelessClasses.set(path, true);
                    final all = cls.fields.get().concat(cls.statics.get());
                    if (cls.constructor != null) {
                        all.push(cls.constructor.get());
                    }
                    for (field in all) {
                        final expr = field.expr();
                        if (expr != null) {
                            checkStatelessExpr(expr, cls.name);
                        }
                    }
                case _:
            }
        }
    }

    static function checkStatelessExpr(expr:TypedExpr, className:String):Void {
        switch expr.expr {
            case TCall(callee, args):
                checkOwnerArgs(callee.t, args, className);
            case TNew(c, _, args):
                final ctor = c.get().constructor;
                if (ctor != null) {
                    checkOwnerArgs(ctor.get().type, args, className);
                }
            case TVar(v, init) if (init != null && isThis(init) && isOwnerType(v.t)):
                refuseOwner(init.pos, className);
            case TBinop(OpAssign, lhs, rhs) if (isThis(rhs) && isOwnerType(lhs.t)):
                refuseOwner(rhs.pos, className);
            case _:
        }
        TypedExprTools.iter(expr, e -> checkStatelessExpr(e, className));
    }

    static function checkOwnerArgs(calleeType:Type, args:Array<TypedExpr>, className:String):Void {
        switch Context.follow(calleeType) {
            case TFun(params, _):
                for (i in 0...args.length) {
                    if (i < params.length && isThis(args[i]) && isOwnerType(params[i].t)) {
                        refuseOwner(args[i].pos, className);
                    }
                }
            case _:
        }
    }

    static function isThis(expr:TypedExpr):Bool {
        return switch expr.expr {
            case TConst(TThis): true;
            case TParenthesis(e) | TMeta(_, e) | TCast(e, null): isThis(e);
            case _: false;
        }
    }

    static function isOwnerType(type:Type):Bool {
        return switch type {
            case TAbstract(_.get() => {pack: [], name: 'Null'}, [t]): isOwnerType(t);
            case TType(_, _) | TLazy(_): isOwnerType(Context.follow(type, true));
            case TMono(ref):
                final bound = ref.get();
                bound != null && isOwnerType(bound);
            case TInst(_.get() => {pack: ['tracker'], name: 'Owner'}, _): true;
            case _: false;
        }
    }

    static function refuseOwner(pos:Position, className:String):Void {
        Context.error('$className is a stateless component: it is rebuilt at every render and cannot be an owner (make it persistent with @persist, or give an entity as the owner)', pos);
    }

    static function maskName(depth:Int, index:Int):String {
        return '__set' + depth + '_' + index;
    }

    /**
     * `true` for a function type, `Null<function type>` or a parenthesized one.
     */
    static function isFunctionType(type:ComplexType):Bool {
        return switch type {
            case TFunction(_, _): true;
            case TParent(t): isFunctionType(t);
            case TPath({name: 'Null', pack: [], params: [TPType(t)]}): isFunctionType(t);
            case TNamed(_, t): isFunctionType(t);
            case _: false;
        }
    }

    /**
     * The persistent mode: observable props and `@observe` fields through
     * tracker's macros, `@compute` as an observable field with an autorun,
     * the `@autorun` methods, the "set" masks and `__apply`, `__create`.
     */
    static function buildPersistent(cls:ClassType, fields:Array<Field>, newFields:Array<Field>, fieldsByName:Map<String, Bool>,
        props:Array<PropInfo>, ctorArgs:Array<FunctionArg>, thisPath:TypePath, depth:Int, maskCount:Int,
        classPath:String, pos:Position):Void {

        final thisType = TPath(thisPath);
        final overrideAccess = [APublic, AOverride];
        final noCompletion = [{name: ':noCompletion', params: [], pos: pos}];

        // `__persistent()`
        if (!cls.isAbstract) {
            newFields.push({
                pos: pos,
                name: '__persistent',
                kind: FFun({args: [], ret: macro :Bool, expr: macro return true}),
                access: overrideAccess,
                meta: noCompletion
            });
        }

        // The "set" masks and the constructor arguments carried by the placeholder
        for (i in 0...maskCount) {
            newFields.push({
                pos: pos,
                name: maskName(depth, i),
                kind: FVar(macro :Int, macro 0),
                access: [APrivate],
                meta: noCompletion
            });
        }
        if (!cls.isAbstract) {
            for (arg in ctorArgs) {
                final argField = '__arg_' + arg.name;
                newFields.push({
                    pos: pos,
                    name: argField,
                    kind: FVar(arg.opt == true ? TPath({name: 'Null', pack: [], params: [TPType(arg.type)]}) : arg.type, null),
                    access: [APrivate],
                    meta: noCompletion
                });
            }
            final ctorCallArgs:Array<Expr> = [for (arg in ctorArgs) {
                final argField = '__arg_' + arg.name;
                macro this.$argField;
            }];
            newFields.push({
                pos: pos,
                name: '__create',
                kind: FFun({
                    args: [],
                    ret: macro :glaze.Component,
                    expr: macro return new $thisPath($a{ctorCallArgs})
                }),
                access: overrideAccess,
                meta: noCompletion
            });
        }

        // `__apply(target)`: the props set on the placeholder go to the live instance
        final applyStatements:Array<Expr> = [];
        applyStatements.push(macro final changed = super.__apply(target));
        if (props.length > 0) {
            applyStatements.push(macro final live:$thisType = cast target);
            for (prop in props) {
                final mask = maskName(depth, Std.int(prop.index / MASK_BITS));
                final bit = 1 << (prop.index % MASK_BITS);
                final storage = prop.storage;
                // The raw storage of an observable prop (`unobservedXProp`):
                // reading the property would bind the parent's tracker
                final source = prop.observable ? 'unobserved' + capitalize(storage) : storage;
                applyStatements.push(macro if ((this.$mask & $v{bit}) != 0) live.$storage = this.$source);
            }
        }
        applyStatements.push(macro return changed);
        newFields.push({
            pos: pos,
            name: '__apply',
            kind: FFun({
                args: [{name: 'target', type: macro :glaze.Component}],
                ret: macro :Bool,
                expr: macro $b{applyStatements}
            }),
            access: overrideAccess,
            meta: noCompletion
        });

        // `@compute function x():T` becomes `@observe var x:T` computed by an autorun
        final autorunNames:Array<String> = [];
        final computeFields:Array<Field> = [];
        for (field in fields) {
            if (field.meta == null) continue;
            var isCompute = false;
            for (meta in field.meta) {
                if (meta.name == 'compute') isCompute = true;
            }
            if (!isCompute) continue;
            switch field.kind {
                case FFun(f):
                    if (f.ret == null) {
                        Context.error('A @compute method of a component needs a return type', field.pos);
                    }
                    if (f.args.length > 0) {
                        Context.error('A @compute method takes no argument', field.pos);
                    }
                    final name = field.name;
                    final computeName = 'compute' + capitalize(name);
                    final autorunName = '__compute' + capitalize(name);
                    field.name = computeName;
                    field.meta = [for (m in field.meta) if (m.name != 'compute') m];
                    field.meta.push({name: ':noCompletion', params: [], pos: field.pos});
                    fieldsByName.set(computeName, true);
                    computeFields.push({
                        pos: field.pos,
                        name: name,
                        kind: FVar(f.ret, null),
                        access: field.access != null ? [for (a in field.access) if (a != AOverride && a != AInline) a] : [],
                        doc: field.doc,
                        meta: [{name: 'observe', params: [], pos: field.pos}]
                    });
                    newFields.push({
                        pos: field.pos,
                        name: autorunName,
                        kind: FFun({
                            args: [],
                            ret: macro :Void,
                            expr: macro this.$name = this.$computeName()
                        }),
                        access: [APrivate],
                        meta: noCompletion
                    });
                    autorunNames.push(autorunName);
                case _:
                    Context.error('@compute applies to a method in a component', field.pos);
            }
        }
        for (field in computeFields) {
            fields.push(field);
        }

        // `@autorun` methods
        for (field in fields) {
            if (field.meta == null) continue;
            for (meta in field.meta) {
                if (meta.name == 'autorun') {
                    switch field.kind {
                        case FFun(f):
                            if (f.args.length > 0) {
                                Context.error('An @autorun method takes no argument', field.pos);
                            }
                            autorunNames.push(field.name);
                        case _:
                            Context.error('@autorun applies to a method', field.pos);
                    }
                }
            }
        }
        if (autorunNames.length > 0) {
            newFields.push({
                pos: pos,
                name: '__autoruns' + depth,
                kind: FVar(macro :Null<Array<tracker.Autorun>>, macro null),
                access: [APrivate],
                meta: noCompletion
            });
            final autorunsField = '__autoruns' + depth;
            final startStatements:Array<Expr> = [macro super.__start()];
            startStatements.push(macro final autoruns:Array<tracker.Autorun> = []);
            startStatements.push(macro this.$autorunsField = autoruns);
            for (name in autorunNames) {
                startStatements.push(macro autoruns.push(new tracker.Autorun(this.$name)));
            }
            newFields.push({
                pos: pos,
                name: '__start',
                kind: FFun({args: [], ret: macro :Void, expr: macro $b{startStatements}}),
                access: overrideAccess,
                meta: noCompletion
            });
            newFields.push({
                pos: pos,
                name: '__dispose',
                kind: FFun({
                    args: [],
                    ret: macro :Void,
                    expr: macro {
                        final autoruns = this.$autorunsField;
                        if (autoruns != null) {
                            this.$autorunsField = null;
                            for (autorun in autoruns) {
                                autorun.destroy();
                            }
                        }
                        super.__dispose();
                    }
                }),
                access: overrideAccess,
                meta: noCompletion
            });
        }

        // Observable fields (the data props and the `@observe` fields), with
        // tracker's macros on the "not an entity" path
        var nextEventIndex = @:privateAccess tracker.macros.EventsMacro._nextEventIndexes.exists(classPath)
            ? @:privateAccess tracker.macros.EventsMacro._nextEventIndexes.get(classPath) : 1;
        final observed:Array<Field> = [];
        for (field in fields) {
            if (field.meta == null) continue;
            for (meta in field.meta) {
                if (meta.name == 'observe') {
                    observed.push(field);
                    break;
                }
            }
        }
        if (observed.length > 0) {
            if (!fieldsByName.exists('observedDirty')) {
                final eventField:Field = {
                    pos: pos,
                    name: 'observedDirty',
                    kind: FFun({
                        args: [
                            {name: 'instance', type: thisType},
                            {name: 'fromSerializedField', type: macro :Bool}
                        ],
                        ret: macro :Void,
                        expr: null
                    }),
                    access: [],
                    doc: 'Event when any observable value as changed on this instance.',
                    meta: []
                };
                nextEventIndex = @:privateAccess tracker.macros.EventsMacro.createEventFields(
                    eventField, newFields, fields, fieldsByName, false, nextEventIndex, null, false, false
                );
                newFields.push({
                    pos: pos,
                    name: 'observedDirty',
                    kind: FVar(macro :Bool, macro false),
                    access: [APublic],
                    doc: 'Default is `false`, automatically set to `true` when any of this instance\'s observable variables has changed.',
                    meta: []
                });
                fieldsByName.set('observedDirty', true);
            }
            for (field in observed) {
                switch field.kind {
                    case FVar(_, _):
                    case _:
                        Context.error('An @observe field of a component is a plain var', field.pos);
                }
                var hasKeepMeta = false;
                for (meta in field.meta) {
                    if (meta.name == ':keep') hasKeepMeta = true;
                }
                fields.remove(field);
                nextEventIndex = @:privateAccess tracker.macros.ObservableMacro.createObserveFields(
                    field, newFields, fields, fieldsByName, false, nextEventIndex, null, false,
                    hasKeepMeta, true, false, null
                );
            }
            @:privateAccess tracker.macros.EventsMacro._nextEventIndexes.set(classPath, nextEventIndex);
        }
    }

    static function capitalize(name:String):String {
        var sanitized = name;
        while (sanitized.startsWith('_')) sanitized = sanitized.substr(1);
        while (sanitized.endsWith('_')) sanitized = sanitized.substr(0, sanitized.length - 1);
        return sanitized.substr(0, 1).toUpperCase() + sanitized.substr(1);
    }

}

/**
 * Renames the reads of the props (`x`, `this.x`, `$x` in strings) to their
 * storage fields in an expression, skipping the names shadowed by locals
 * (arguments, `var`s, loop variables, catch variables, pattern captures).
 */
private class PropRenamer {

    final renames:Map<String, String>;

    final scopes:Array<Array<String>> = [];

    public function new(renames:Map<String, String>, args:Null<Array<FunctionArg>>) {
        this.renames = renames;
        if (args != null) {
            scopes.push([for (arg in args) arg.name]);
        }
    }

    function shadowed(name:String):Bool {
        for (scope in scopes) {
            if (scope.indexOf(name) != -1) return true;
        }
        return false;
    }

    inline function declare(name:String):Void {
        if (scopes.length == 0) scopes.push([]);
        scopes[scopes.length - 1].push(name);
    }

    public function rename(e:Expr):Expr {
        if (e == null) return null;
        switch e.expr {
            case EConst(CIdent(s)):
                final storage = renames.get(s);
                if (storage != null && !shadowed(s)) {
                    return {expr: EConst(CIdent(storage)), pos: e.pos};
                }
                return e;
            case EConst(CString(s, SingleQuotes)):
                if (s.indexOf('$') != -1) {
                    final formatted = MacroStringTools.formatString(s, e.pos);
                    return switch formatted.expr {
                        case EConst(CString(_, _)): formatted;
                        case _: rename(formatted);
                    }
                }
                return e;
            case EField({expr: EConst(CIdent('this'))}, field, kind):
                final storage = renames.get(field);
                if (storage != null) {
                    return {expr: EField({expr: EConst(CIdent('this')), pos: e.pos}, storage, kind), pos: e.pos};
                }
                return e;
            case EFunction(kind, f):
                scopes.push([for (arg in f.args) arg.name]);
                final args = [for (arg in f.args) {name: arg.name, type: arg.type, opt: arg.opt, value: rename(arg.value), meta: arg.meta}];
                final body = rename(f.expr);
                scopes.pop();
                return {expr: EFunction(kind, {args: args, ret: f.ret, expr: body, params: f.params}), pos: e.pos};
            case EVars(vars):
                final result = [for (v in vars) {
                    final init = rename(v.expr);
                    declare(v.name);
                    ({name: v.name, type: v.type, expr: init, isFinal: v.isFinal, isStatic: v.isStatic, meta: v.meta} : Var);
                }];
                return {expr: EVars(result), pos: e.pos};
            case EBlock(exprs):
                scopes.push([]);
                final result = [for (sub in exprs) rename(sub)];
                scopes.pop();
                return {expr: EBlock(result), pos: e.pos};
            case EFor(it, body):
                scopes.push([]);
                final iterator = switch it.expr {
                    case EBinop(OpIn, left, right):
                        final iterated = rename(right);
                        declareLoopVariables(left);
                        {expr: EBinop(OpIn, left, iterated), pos: it.pos};
                    case _:
                        rename(it);
                }
                final renamedBody = rename(body);
                scopes.pop();
                return {expr: EFor(iterator, renamedBody), pos: e.pos};
            case ETry(tried, catches):
                final renamedTry = rename(tried);
                final result = [for (c in catches) {
                    scopes.push([c.name]);
                    final body = rename(c.expr);
                    scopes.pop();
                    ({name: c.name, type: c.type, expr: body} : Catch);
                }];
                return {expr: ETry(renamedTry, result), pos: e.pos};
            case ESwitch(subject, cases, def):
                final renamedSubject = rename(subject);
                final result = [for (c in cases) {
                    scopes.push([]);
                    for (value in c.values) {
                        declareCaptures(value);
                    }
                    final guard = rename(c.guard);
                    final body = rename(c.expr);
                    scopes.pop();
                    ({values: c.values, guard: guard, expr: body} : Case);
                }];
                return {expr: ESwitch(renamedSubject, result, rename(def)), pos: e.pos};
            case _:
                return ExprTools.map(e, rename);
        }
    }

    function declareLoopVariables(e:Expr):Void {
        switch e.expr {
            case EConst(CIdent(name)):
                declare(name);
            case EBinop(OpArrow, key, value):
                declareLoopVariables(key);
                declareLoopVariables(value);
            case _:
        }
    }

    /**
     * The identifiers of a pattern are captures (or enum constructors, which
     * cannot be props anyway)
     */
    function declareCaptures(e:Expr):Void {
        switch e.expr {
            case EConst(CIdent(name)):
                declare(name);
            case EBinop(OpAssign, {expr: EConst(CIdent(name))}, sub):
                declare(name);
                declareCaptures(sub);
            case _:
                ExprTools.iter(e, declareCaptures);
        }
    }

}
#end
