package ceramic.macros;

import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;

using StringTools;
using haxe.macro.ExprTools;

class EntityMacro {

    @:persistent static var fieldNamesByTypeName:Map<String,Array<String>> = null;

    static var processed:Map<String,Bool> = new Map();

    static var hasSuperDestroy:Bool = false;

    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN EntityMacro.build()');
        #end

        var fields = Context.getBuildFields();
        var classPath = Context.getLocalClass().toString();

        // Look for @editable, @fieldInfo or @autoFieldInfo meta
        var fieldInfoData:DynamicAccess<{type:String,?editable:Array<Expr>,index:Int}> = null;
        var storeAllFieldInfo = false;
        var storeEditableMeta = false;
        var localClass = Context.getLocalClass().get();
        for (meta in localClass.meta.get()) {
            if (meta.name == 'editable') {
                if (fieldInfoData == null)
                    fieldInfoData = {};
                storeEditableMeta = true;
            }
            else if (meta.name == 'fieldInfo' || meta.name == 'autoFieldInfo') {
                if (fieldInfoData == null)
                    fieldInfoData = {};
                storeAllFieldInfo = true;
            }
        }

        // Gather info from parents
        var inheritsFromStateMachine = false;
        var isStateMachine = false;
        if (localClass.pack.length == 1 && localClass.pack[0] == 'ceramic') {
            if (localClass.name == 'StateMachine' || localClass.name == 'StateMachineBase' || localClass.name == 'StateMachineImpl' || localClass.name.startsWith('StateMachineImpl_') || localClass.name.startsWith('StateMachine_')) {
                isStateMachine = true;
            }
        }
        var resolvedStateEnums:Array<haxe.macro.Type> = null;
        var parentHold = localClass.superClass;
        var parent = parentHold != null ? parentHold.t : null;
        var parentConstructor = null;
        while (parent != null) {

            var clazz = parent.get();

            if (parentConstructor == null) {
                parentConstructor = clazz.constructor?.get();
            }

            if (!storeAllFieldInfo) {
                for (meta in clazz.meta.get()) {
                    if (meta.name == 'autoFieldInfo') {
                        if (fieldInfoData == null)
                            fieldInfoData = {};
                        storeAllFieldInfo = true;
                    }
                }
            }

            if (!isStateMachine && !inheritsFromStateMachine && clazz.pack.length == 1 && clazz.pack[0] == 'ceramic') {
                if (clazz.name.startsWith('StateMachine_')) {
                    inheritsFromStateMachine = true;

                    var stateComplexType = StateMachineMacro.getStateTypeFromImplName(clazz.name);
                    if (stateComplexType != null) {
                        try {
                            var resolvedType = Context.resolveType(stateComplexType, Context.currentPos());
                            switch resolvedType {
                                default:
                                case TLazy(f):
                                    resolvedType = f();
                            }
                            switch resolvedType {
                                default:
                                case TEnum(t, params):
                                    if (resolvedStateEnums == null)
                                        resolvedStateEnums = [];
                                    resolvedStateEnums.push(resolvedType);
                                case TAbstract(t, params):
                                    if (resolvedStateEnums == null)
                                        resolvedStateEnums = [];
                                    resolvedStateEnums.push(resolvedType);
                            }
                        }
                        catch (e:Dynamic) {}
                    }
                }
            }

            parentHold = clazz.superClass;
            parent = parentHold != null ? parentHold.t : null;
        }

        var newFields:Array<Field> = [];

        var constructor = null;
        var fieldNames = [];
        for (field in fields) {
            if (field.name == 'new') {
                constructor = field;
            }
            else {
                fieldNames.push(field.name);
            }
        }
        var typeName = localClass.name;
        if (localClass.pack.length > 0) {
            typeName = localClass.pack.join('.') + '.' + typeName;
        }
        if (fieldNamesByTypeName == null) {
            fieldNamesByTypeName = new Map();
        }
        fieldNamesByTypeName.set(typeName, fieldNames);

        var componentFields = [];

        #if (!completion && !display)
        var ownFields:Array<String> = null;
        #end

        var hasDestroyOverride = false;
        var index = 0;
        var checkStateMachineFields = true; // Always true for now

        var constructorFn = null;
        var toAppendInConstructorSuper:Array<Expr> = null;

        for (field in fields) {

            if (!hasDestroyOverride && field.name == 'destroy') {
                hasDestroyOverride = true;
            }

            var hasMeta = hasOwnerOrComponentOrContentMeta(field);

            // Keep field info?
            if (fieldInfoData != null && !field.name.startsWith('unobserved') && (field.access == null || field.access.indexOf(AStatic) == -1)) {
                var editableMeta = storeEditableMeta ? getEditableMeta(field) : null;
                if (editableMeta != null || storeAllFieldInfo) {
                    switch(field.kind) {
                        case FieldType.FVar(type, expr) | FieldType.FProp(_, _, type, expr):
                            var resolvedType = Context.resolveType(type, Context.currentPos());
                            var typeStr = complexTypeToString(TypeTools.toComplexType(resolvedType));
                            if (typeStr == 'StdTypes') {
                                typeStr = complexTypeToString(type);
                            }
                            fieldInfoData.set(field.name, {
                                type: typeStr,
                                editable: editableMeta != null ? editableMeta.params : null,
                                index: index
                            });

                        default:
                            if (editableMeta != null)
                                throw new Error("Only variable/property fields can be marked as editable", field.pos);
                    }
                }
            }

            if (hasMeta.bool(0)) { // has component meta

                #if (!display && !completion)
                if (hasMeta.bool(2)) {
                    throw new Error("Component fields cannot have a `@content` meta", field.pos);
                }
                #end

                switch(field.kind) {
                    case FieldType.FVar(type, expr):

                        if (field.access.indexOf(AStatic) != -1) {
                            throw new Error("Component cannot be static", field.pos);
                        }

                        var fieldName = field.name;
                        var processedStateMachineType = false;

                        if (expr != null) {
                            // Compute type from expr
                            switch (expr.expr) {
                                case ENew(t,p):

                                    // Some syntactic sugar with StateMachine used as a component
                                    // StateMachine<S> will map to StateMachineComponent<S,E>,
                                    // E being our current Entity class, automatically resolved
                                    if (t.name == 'StateMachine' && (t.pack.length == 0 || (t.pack.length == 1 && t.pack[0] == 'ceramic'))) {
                                        if (t.params.length == 1) {
                                            var resolvedType:haxe.macro.Type = null;
                                            var isCeramicStateMachine = false;
                                            try {
                                                // Ensure we are matching ceramic's StateMachine type,
                                                // and not another type with the same name
                                                resolvedType = Context.resolveType(TPath({
                                                    pack: t.pack,
                                                    name: t.name,
                                                    params: [TPType(macro :Dynamic)]
                                                }), field.pos);
                                                if (resolvedType != null) {
                                                    switch resolvedType {
                                                        default:
                                                        case TLazy(f):
                                                            resolvedType = f();
                                                    }
                                                    switch resolvedType {
                                                        default:
                                                        case TInst(t, params):
                                                            var res = t.get();
                                                            if ((res.name == 'StateMachineBase' || res.name == 'StateMachineImpl' || res.name.startsWith('StateMachineImpl_')) && res.pack.length == 1 && res.pack[0] == 'ceramic') {
                                                                isCeramicStateMachine = true;
                                                            }
                                                    }
                                                }
                                            }
                                            catch (e:Dynamic) {}
                                            if (isCeramicStateMachine) {
                                                // This is indeed a ceramic StateMachine.
                                                checkStateMachineFields = true;
                                                processedStateMachineType = true;

                                                // Check if state is an enum or enum abstract type
                                                var resolvedTypeParam:haxe.macro.Type = null;
                                                var typeParamIsEnum:Bool = false;
                                                var typeParamIsEnumAbstract:Bool = false;
                                                try {
                                                    switch t.params[0] {
                                                        default:
                                                        case TPType(tp):
                                                            resolvedTypeParam = Context.resolveType(tp, field.pos);
                                                            if (resolvedTypeParam != null) {
                                                                switch resolvedTypeParam {
                                                                    default:
                                                                    case TLazy(f):
                                                                        resolvedTypeParam = f();
                                                                }
                                                                switch resolvedTypeParam {
                                                                    default:
                                                                    case TAbstract(t, params):
                                                                        if (t.get().meta.has(':enum')) {
                                                                            typeParamIsEnumAbstract = true;
                                                                        }
                                                                    case TEnum(t, params):
                                                                        typeParamIsEnum = true;
                                                                }
                                                            }
                                                    }
                                                }
                                                catch (e:Dynamic) {}

                                                if (typeParamIsEnum || typeParamIsEnumAbstract) {

                                                    // Yes, it's an enum or enum abstract type. Perform replace
                                                    var localClassParams = [];
                                                    for (param in localClass.params) {
                                                        localClassParams.push(TPType(TypeTools.toComplexType(param.t)));
                                                    }
                                                    t = {
                                                        pack: ['ceramic'],
                                                        name: 'StateMachineComponent',
                                                        params: [
                                                            t.params[0],
                                                            TPType(TPath({
                                                                pack: localClass.pack,
                                                                name: localClass.name,
                                                                params: localClassParams
                                                            }))
                                                        ]
                                                    }
                                                    expr = {
                                                        expr: ENew(t,p),
                                                        pos: field.pos
                                                    };

                                                    // Also keep enum type around to perform further checks after
                                                    if (resolvedStateEnums == null)
                                                        resolvedStateEnums = [];
                                                    resolvedStateEnums.push(resolvedTypeParam);
                                                }

                                            }
                                        }
                                    }

                                    if (type == null) {
                                        type = TPath(t);
                                    }

                                    if (constructor == null) {

                                        // Implicit constructor override because it is needed to initialize components

                                        var constructorArgs = [];
                                        var constructorExpr = new StringBuf();
                                        constructorExpr.add('{ super(');

                                        if (parentConstructor != null) {

                                            var didResolveConstructorField = false;
                                            try {
                                                switch TypeTools.follow(parentConstructor.type) {
                                                    case TFun(args, ret):
                                                        didResolveConstructorField = true;
                                                        if (args != null) {
                                                            for (a in 0...args.length) {
                                                                var arg = args[a];
                                                                constructorArgs.push({
                                                                    name: arg.name,
                                                                    opt: arg.opt,
                                                                    type: arg.t != null ? TypeTools.toComplexType(arg.t) : null
                                                                });
                                                                if (a > 0) {
                                                                    constructorExpr.add(', ');
                                                                }
                                                                constructorExpr.add(arg.name);
                                                            }
                                                        }
                                                    default:
                                                }
                                            }
                                            catch (e:Dynamic) {
                                                didResolveConstructorField = false;
                                            }

                                            if (!didResolveConstructorField) {
                                                Context.warning('Failed to resolve parent constructor field for class ' + classPath, Context.currentPos());
                                            }
                                        }
                                        constructorExpr.add('); }');

                                        constructor = {
                                            name: 'new',
                                            doc: null,
                                            meta: [],
                                            access: [APublic],
                                            kind: FFun({
                                                params: [],
                                                args: constructorArgs,
                                                ret: null,
                                                expr: Context.parse(constructorExpr.toString(), Context.currentPos())
                                            }),
                                            pos: Context.currentPos()
                                        };

                                        newFields.push(constructor);
                                    }

                                    // Add initialization code in constructor
                                    switch (constructor.kind) {
                                        case FFun(fn):

                                            // Ensure expr is surrounded with a block
                                            switch (fn.expr.expr) {
                                                case EBlock(exprs):
                                                default:
                                                    fn.expr.expr = EBlock([{
                                                        pos: fn.expr.pos,
                                                        expr: fn.expr.expr
                                                    }]);
                                            }

                                            constructorFn = fn;
                                            if (toAppendInConstructorSuper == null)
                                                toAppendInConstructorSuper = [];
                                            toAppendInConstructorSuper.push(
                                                macro this.$fieldName = @:privateAccess ${expr}
                                            );

                                        default:
                                            throw new Error("Invalid constructor", field.pos);
                                    }
                                default:
                                    throw new Error("Invalid component default value", field.pos);
                            }
                        }

                        // Check if this type is a StateMachine subclass to resolve associated enum (if any)
                        if (!processedStateMachineType) {
                            processedStateMachineType = true;
                            if (type != null) {
                                var resolvedType:haxe.macro.Type = null;
                                try {
                                    resolvedType = Context.resolveType(type, field.pos);
                                }
                                catch (e:Dynamic) {}
                                if (resolvedType != null) {
                                    switch resolvedType {
                                        default:
                                        case TLazy(f):
                                            resolvedType = f();
                                    }
                                    switch resolvedType {
                                        default:
                                        case TInst(t, params):
                                            var parent = t;
                                            while (parent != null) {

                                                var clazz = parent.get();

                                                if (clazz.pack.length == 1 && clazz.pack[0] == 'ceramic') {
                                                    if (clazz.name.startsWith('StateMachine_')) {
                                                        inheritsFromStateMachine = true;

                                                        var stateComplexType = StateMachineMacro.getStateTypeFromImplName(clazz.name);
                                                        if (stateComplexType != null) {
                                                            try {
                                                                var resolvedType = Context.resolveType(stateComplexType, Context.currentPos());
                                                                switch resolvedType {
                                                                    default:
                                                                    case TLazy(f):
                                                                        resolvedType = f();
                                                                }
                                                                switch resolvedType {
                                                                    default:
                                                                    case TEnum(t, params):
                                                                        if (resolvedStateEnums == null)
                                                                            resolvedStateEnums = [];
                                                                        resolvedStateEnums.push(resolvedType);
                                                                    case TAbstract(t, params):
                                                                        if (resolvedStateEnums == null)
                                                                            resolvedStateEnums = [];
                                                                        resolvedStateEnums.push(resolvedType);
                                                                }
                                                            }
                                                            catch (e:Dynamic) {}
                                                        }
                                                    }
                                                    break;
                                                }

                                                var parentHold = clazz.superClass;
                                                parent = parentHold != null ? parentHold.t : null;
                                            }
                                    }
                                }
                            }
                        }

                        // Create prop from var
                        var propField = {
                            pos: field.pos,
                            name: field.name,
                            kind: FProp('default', 'set', type),
                            access: [APublic],
                            doc: field.doc,
                            meta: []
                        };
                        newFields.push(propField);
                        componentFields.push(propField);

                        var setField = {
                            pos: field.pos,
                            name: 'set_' + field.name,
                            kind: FFun({
                                args: [
                                    {name: field.name, type: type}
                                ],
                                ret: type,
                                expr: macro {
                                    if (this.$fieldName == $i{fieldName}) return this.$fieldName;
                                    if (this.$fieldName != null) {
                                        @:privateAccess this.$fieldName.destroy();
                                    }
                                    this.$fieldName = $i{fieldName};
                                    if (this.$fieldName != null) {
                                        component($v{fieldName}, this.$fieldName);
                                        return this.$fieldName;
                                    }
                                    removeComponent($v{fieldName});
                                    return null;
                                }
                            }),
                            access: [APrivate],
                            doc: '',
                            meta: []
                        };
                        newFields.push(setField);

                    default:
                        throw new Error("Invalid component syntax", field.pos);
                }

            }
            else {
                #if (!completion && !display)
                if (hasMeta.bool(1)) { // has owner meta
                    if (ownFields == null) {
                        ownFields = [];
                    }
                    ownFields.push(field.name);
                    newFields.push(field);
                }
                else if (hasMeta.bool(2)) { // has content meta
                    switch(field.kind) {
                        case FieldType.FVar(type, expr):
                            if (field.access.indexOf(AStatic) != -1) {
                                throw new Error("Content field cannot be static", field.pos);
                            }

                            var fieldName = field.name;

                            // Create prop from var
                            var propField = {
                                pos: field.pos,
                                name: fieldName,
                                kind: FProp('default', 'set', type, expr),
                                access: field.access,
                                doc: field.doc,
                                meta: []
                            };
                            newFields.push(propField);

                            var setField = {
                                pos: field.pos,
                                name: 'set_' + fieldName,
                                kind: FFun({
                                    args: [
                                        {name: fieldName, type: type}
                                    ],
                                    ret: type,
                                    expr: macro {
                                        if (this.$fieldName != $i{fieldName}) {
                                            this.$fieldName = $i{fieldName};
                                            contentDirty = true;
                                        }
                                        return $i{fieldName};
                                    }
                                }),
                                access: [APrivate],
                                doc: '',
                                meta: []
                            }
                            newFields.push(setField);

                        default:
                            throw new Error("Invalid content field syntax", field.pos);
                    }
                }
                else {
                    newFields.push(field);
                }
                #else
                newFields.push(field);
                #end
            }

            index++;
        }

        // Append initialization in constructor
        if (constructorFn != null && toAppendInConstructorSuper != null) {

            var toAppend:Expr = {
                expr: EBlock(toAppendInConstructorSuper),
                pos: constructor.pos
            }

            constructorFn.expr = appendConstructorSuper(
                constructorFn.expr,
                toAppend
            );

        }

        #if (!completion && !display)
        // In some cases, destroy override is a requirement, add it if not there already
        if (ownFields != null && !hasDestroyOverride) {
            newFields.push({
                pos: Context.currentPos(),
                name: 'destroy',
                kind: FFun({
                    args: [],
                    ret: macro :Void,
                    expr: macro {
                        super.destroy();
                    }
                }),
                access: [AOverride],
                meta: []
            });
        }
        #end

        var isProcessed = processed.exists(classPath);
        if (!isProcessed) {
            processed.set(classPath, true);

            for (field in newFields) {
                if (field.name == 'destroy') {

                    switch(field.kind) {
                        case FieldType.FFun(fn):

                            // Ensure expr is surrounded with a block and tranform super.destroy() calls.
                            // Check that super.destroy() call exists at the same time
                            hasSuperDestroy = false;

                            switch (fn.expr.expr) {
                                case EBlock(exprs):
                                    fn.expr = transformSuperDestroy(fn.expr);
                                default:
                                    fn.expr.expr = EBlock([{
                                        pos: fn.expr.pos,
                                        expr: transformSuperDestroy(fn.expr).expr
                                    }]);
                            }

                            if (!hasSuperDestroy) {
                                Context.error("Call to super.destroy() is required", field.pos);
                            }

                            switch (fn.expr.expr) {
                                case EBlock(exprs):

                                    // Check lifecycle state first and continue only
                                    // if the entity is not destroyed already
                                    // Mark destroyed, but still allow call to super.destroy()
                                    exprs.unshift(macro {
                                        if (_lifecycleState <= -2) return;
                                        _lifecycleState = -2;
                                    });

                                    #if (!completion && !display)
                                    // Destroy owned entities as well
                                    if (ownFields != null) {
                                        for (name in ownFields) {
                                            exprs.unshift(macro {
                                                var toDestroy = this.$name;
                                                if (toDestroy != null) {
                                                    toDestroy.destroy();
                                                    this.$name = null;
                                                }
                                            });
                                        }
                                    }
                                    #end

                                default:
                            }

                        default:
                    }
                }
            }
        }

        #if (!completion && !display)
        // Add field info
        if (fieldInfoData != null) {
            var fieldInfoEntries = [];
            var pos = Context.currentPos();
            for (name => info in fieldInfoData) {
                var entries = [];
                if (info.editable != null) {
                    entries.push({
                        expr: {
                            expr: EArrayDecl(info.editable),
                            pos: pos
                        },
                        field: 'editable'
                    });
                }
                if (info.type != null) {
                    entries.push({
                        expr: {
                            expr: EConst(CString(info.type)),
                            pos: pos
                        },
                        field: 'type'
                    });
                }
                if (info.index != null) {
                    entries.push({
                        expr: {
                            expr: EConst(CInt(Std.string(info.index))),
                            pos: pos
                        },
                        field: 'index'
                    });
                }
                fieldInfoEntries.push({
                    expr: {
                        expr: EObjectDecl(entries),
                        pos: pos
                    },
                    field: name
                });
            }

            newFields.push({
                pos: pos,
                name: '_fieldInfo',
                kind: FProp('default', 'null', null, { expr: EObjectDecl(fieldInfoEntries), pos: pos }),
                access: [APublic, AStatic],
                doc: 'Field info',
                meta: [{
                    name: ':noCompletion',
                    params: [],
                    pos: pos
                }]
            });
        }
        #end

        // Check state machine enum state collisions
        var enumNames:Map<String,Bool> = null;
        if (resolvedStateEnums != null) {

            enumNames = new Map();

            var duplicateNames:Map<String,Bool> = new Map();

            for (type in resolvedStateEnums) {

                switch type {
                    default:
                    case TAbstract(t, params):
                        for (field in t.get().impl.get().statics.get()) {
                            if (field.meta.has(':enum') && field.meta.has(':impl')) {
                                var name = field.name;
                                if (!enumNames.exists(name)) {
                                    enumNames.set(name, true);
                                }
                                else if (!duplicateNames.exists(name)) {
                                    duplicateNames.set(name, true);
                                    Context.error("Duplicate state: enum value `" + name + "` is used by multiple StateMachine components", Context.currentPos());
                                }
                            }
                        }
                    case TEnum(t, params):
                        for (name in t.get().names) {
                            if (!enumNames.exists(name)) {
                                enumNames.set(name, true);
                            }
                            else if (!duplicateNames.exists(name)) {
                                duplicateNames.set(name, true);
                                Context.error("Duplicate state: enum value `" + name + "` is used by multiple StateMachine components", Context.currentPos());
                            }
                        }
                }

            }
        }

        if (checkStateMachineFields) {

            for (field in newFields) {
                var name = field.name;
                if (name.endsWith('_enter')) {
                    var stateName = name.substring(0, name.length - 6);
                    if (enumNames == null || !enumNames.exists(stateName)) {
                        Context.error("Unknown state value: " + stateName + "", field.pos);
                    }

                    // Check args
                    switch field.kind {
                        default:
                        case FFun(f):
                            if (f.args.length != 0) {
                                Context.error("Too many arguments", field.pos);
                            }
                    }
                }
                else if (name.endsWith('_exit')) {
                    var stateName = name.substring(0, name.length - 5);
                    if (enumNames == null || !enumNames.exists(stateName)) {
                        Context.error("Unknown state value: " + stateName + "", field.pos);
                    }

                    // Check args
                    switch field.kind {
                        default:
                        case FFun(f):
                            if (f.args.length != 0) {
                                Context.error("Too many arguments", field.pos);
                            }
                    }
                }
                else if (name.endsWith('_update')) {
                    var stateName = name.substring(0, name.length - 7);
                    if (enumNames == null || !enumNames.exists(stateName)) {
                        Context.error("Unknown state value: " + stateName + "", field.pos);
                    }

                    // Check args
                    switch field.kind {
                        default:
                        case FFun(f):
                            if (f.args.length != 1) {
                                Context.error("Missing argument: delta", field.pos);
                            }
                            else {
                                if (f.args[0].type == null) {
                                    f.args[0].type = macro :Float;
                                }
                            }
                    }
                }
            }

        }

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END EntityMacro.build()');
        #end

        return newFields;

    }

    /**
     * Replace `super.destroy();`
     * with `{ _lifecycleState = -1; super.destroy(); }`
     */
    static function transformSuperDestroy(e:Expr):Expr {

        // This super.destroy() call patch ensures
        // the parent destroy() method will not ignore our call as it would normally do
        // when the object is marked destroyed.

        switch (e.expr) {
            case ECall({expr: EField({expr: EConst(CIdent('super')), pos: _}, 'destroy'), pos: _}, _):
                hasSuperDestroy = true;
                return macro { _lifecycleState = -1; ${e}; };
            default:
                return ExprTools.map(e, transformSuperDestroy);
        }

    }

    static var _appendConstructorSuperToAppend:Expr;

    /**
     * Append constructor `super(...);`
     * with `toAppend` expr
     */
    static function appendConstructorSuper(e:Expr, toAppend:Expr):Expr {

        _appendConstructorSuperToAppend = toAppend;

        return doAppendConstructorSuper(e);

    }

    static function doAppendConstructorSuper(e:Expr):Expr {

        switch (e.expr) {
            case ECall({expr: EConst(CIdent('super')), pos: _}, _):
                return macro { ${e}; ${_appendConstructorSuperToAppend}; };
            default:
                return ExprTools.map(e, doAppendConstructorSuper);
        }

    }

    static function hasOwnerOrComponentOrContentMeta(field:Field):Flags {

        if (field.meta == null || field.meta.length == 0) return 0;

        var flags:Flags = 0;

        for (meta in field.meta) {
            if (meta.name == 'component') {
                flags.setBool(0, true);
            }
            #if (!completion && !display)
            else if (meta.name == 'owner') {
                flags.setBool(1, true);
            }
            else if (meta.name == 'content') {
                flags.setBool(2, true);
            }
            #end
        }

        return flags;

    }

    static function getEditableMeta(field:Field):MetadataEntry {

        if (field.meta == null || field.meta.length == 0) return null;

        for (meta in field.meta) {
            if (meta.name == 'editable') {
                return meta;
            }
        }

        return null;

    }

    static function complexTypeToString(type:ComplexType):String {

        var typeStr:String = null;

        if (type != null) {
            switch (type) {
                case TPath(p):
                    typeStr = p.name;
                    if (typeStr == 'StdTypes' && p.params != null) {
                        for (param in p.params) {
                            switch param {
                                case TPType(t):
                                    return complexTypeToString(t);
                                case TPExpr(e):
                                    return 'Dynamic';
                            }
                        }
                    }
                    if (p.pack != null && p.pack.length > 0) {
                        typeStr = p.pack.join('.') + '.' + typeStr;
                    }
                    if (p.params != null && p.params.length > 0) {
                        typeStr += '<';
                        var n = 0;
                        for (param in p.params) {
                            if (n > 0)
                                typeStr += ',';
                            switch param {
                                case TPType(t):
                                    var isStdType = false;
                                    switch t {
                                        case TPath(p):
                                            if (p.name == 'StdTypes') {
                                                isStdType = true;
                                                typeStr += p.sub;
                                            }
                                        default:
                                    }
                                    if (!isStdType)
                                        typeStr += complexTypeToString(t);
                                case TPExpr(e):
                                    typeStr += 'Dynamic';
                            }
                            n++;
                        }
                        typeStr += '>';
                    }
                default:
                    typeStr = 'Dynamic';
            }
        }
        else {
            typeStr = 'Dynamic';
        }

        return typeStr;

    }

/// Completion specific

    macro static public function buildForCompletion():Array<Field> {

        var fields = Context.getBuildFields();

        for (field in fields) {

            // Infer delta type
            if (field.name.endsWith('_update')) {

                switch field.kind {
                    default:
                    case FFun(f):
                        if (f.args.length > 0) {
                            var arg = f.args[0];
                            if (arg.type == null) {
                                arg.type = macro :Float;
                            }
                        }
                }
            }
        }

        return fields;

    }

    public static function getFieldNamesFromTypeName(typeName:String):Array<String> {

        if (fieldNamesByTypeName == null)
            return null;
        return fieldNamesByTypeName.get(typeName);

    }

}