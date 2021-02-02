package ceramic.macros;

import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.DynamicAccess;

using haxe.macro.ExprTools;
using StringTools;

class EntityMacro {

    #if (haxe_ver < 4)
    static var onReused:Bool = false;
    #end

    static var processed:Map<String,Bool> = new Map();

    static var hasSuperDestroy:Bool = false;

    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN EntityMacro.build()');
        #end

        #if (haxe_ver < 4)
        if (!onReused) {
            onReused = true;
            Context.onMacroContextReused(function() {
                processed = new Map();
                return true;
            });
        }
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
        if (!storeAllFieldInfo) {
            var parentHold = localClass.superClass;
            var parent = parentHold != null ? parentHold.t : null;
            while (parent != null) {

                for (meta in parent.get().meta.get()) {
                    if (meta.name == 'autoFieldInfo') {
                        if (fieldInfoData == null)
                            fieldInfoData = {};
                        storeAllFieldInfo = true;
                        break;
                    }
                }

                parentHold = parent.get().superClass;
                parent = parentHold != null ? parentHold.t : null;
            }
        }

        var newFields:Array<Field> = [];

        var constructor = null;
        for (field in fields) {
            if (field.name == 'new') {
                constructor = field;
                break;
            }
        }

        var componentFields = [];
        var ownFields:Array<String> = null;
        #if (!display && !completion)
        var hasDestroyOverride = false;
        #end
        var index = 0;

        for (field in fields) {

            #if (!display && !completion)
            if (!hasDestroyOverride && field.name == 'destroy') {
                hasDestroyOverride = true;
            }
            #end

            var hasMeta = hasOwnerOrComponentMeta(field);

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

            if (hasMeta == 2 || hasMeta == 3) { // has component meta

                switch(field.kind) {
                    case FieldType.FVar(type, expr):

                        if (field.access.indexOf(AStatic) != -1) {
                            throw new Error("Component cannot be static", field.pos);
                        }
                        if (field.access.indexOf(APrivate) != -1) {
                            throw new Error("Component cannot be private", field.pos);
                        }

                        var fieldName = field.name;

                        if (expr != null) {
                            // Compute type from expr
                            switch (expr.expr) {
                                case ENew(t,p):
                                    if (type == null) {
                                        type = TPath(t);
                                    }
                                    if (constructor == null) {
                                        throw new Error("A constructor is required to initialize a component's default instance", field.pos);
                                    }
                                    else {
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

                                                fn.expr = appendConstructorSuper(
                                                    fn.expr,
                                                    macro this.$fieldName = @:privateAccess ${expr}
                                                );

                                            default:
                                                throw new Error("Invalid constructor", field.pos);
                                        }
                                    }
                                default:
                                    throw new Error("Invalid component default value", field.pos);
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
                        }
                        newFields.push(setField);

                    default:
                        throw new Error("Invalid component syntax", field.pos);
                }

            }
            else if (hasMeta == 1 || hasMeta == 3) { // has owner meta
                if (ownFields == null) {
                    ownFields = [];
                }
                ownFields.push(field.name);
                newFields.push(field);
            }
            else {
                newFields.push(field);
            }

            index++;
        }

        #if (!display && !completion)
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

                                default:
                            }

                        default:
                    }
                }
            }
        }

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

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END EntityMacro.build()');
        #end

        return newFields;

    }

    /** Replace `super.destroy();`
        with `{ _lifecycleState = -1; super.destroy(); }`
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

    /** Append constructor `super(...);`
        with `toAppend` expr */
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

    static function hasOwnerOrComponentMeta(field:Field):Int {

        if (field.meta == null || field.meta.length == 0) return 0;

        var hasComponentMeta = false;
        var hasOwnerMeta = false;

        for (meta in field.meta) {
            if (meta.name == 'component') {
                hasComponentMeta = true;
            }
            else if (meta.name == 'owner') {
                hasOwnerMeta = true;
            }
        }

        if (hasComponentMeta && hasOwnerMeta) {
            return 3;
        }
        else if (hasComponentMeta) {
            return 2;
        }
        else if (hasOwnerMeta) {
            return 1;
        }
        else {
            return 0;
        }

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

}