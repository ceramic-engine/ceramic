package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;

class EntityMacro {

    static var onReused = false;

    static var processed = new Map<String,Bool>();

    static var specialFields = [
        'destroy' => true,
        'dispose' => true,
        'restore' => true
    ];

    macro static public function build():Array<Field> {

        if (!onReused) {
            onReused = true;
            Context.onMacroContextReused(function() {
                processed = new Map();
                return true;
            });
        }

        var fields = Context.getBuildFields();
        var classPath = Context.getLocalClass().toString();

        var newFields:Array<Field> = [];

        var constructor = null;
        for (field in fields) {
            if (field.name == 'new') {
                constructor = field;
                break;
            }
        }

        var componentFields = [];

        for (field in fields) {

            if (hasComponentMeta(field)) {

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
                                                
                                                switch (fn.expr.expr) {
                                                    case EBlock(exprs):

                                                        exprs.push(macro {
                                                            this.$fieldName = @:privateAccess ${expr};
                                                        });

                                                    default:
                                                        throw new Error("Invalid constructor body", field.pos);
                                                }

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
            else {
                newFields.push(field);
            }
        }

        var isProcessed = processed.exists(classPath);
        if (!isProcessed) {
            processed.set(classPath, true);

            for (field in newFields) {
                if (specialFields.exists(field.name)) {
                    if (field.name == 'destroy') {

                        switch(field.kind) {
                            case FieldType.FFun(fn):
                                var printer = new haxe.macro.Printer();
                                var lines = printer.printExpr(fn.expr).split("\n");

                                // Check there is no explicit super.destroy() call
                                for (line in lines) {
                                    if (line.indexOf('super.destroy();') != -1) {
                                        throw new Error("Explicit call to super.destroy() is not allowed. This is done automatically", field.pos);
                                    }
                                }

                                // Ensure expr is surrounded with a block
                                switch (fn.expr.expr) {
                                    case EBlock(exprs):
                                    default:
                                        fn.expr.expr = EBlock([{
                                            pos: fn.expr.pos,
                                            expr: fn.expr.expr
                                        }]);
                                }

                                switch (fn.expr.expr) {
                                    case EBlock(exprs):

                                        // Add if destroyed check at the top
                                        exprs.unshift(macro {
                                            if (destroyed) return;
                                            super.destroy();
                                        });

                                    default:
                                }

                            default:
                        }
                    }
                    else if (field.name == 'dispose') {

                        switch(field.kind) {
                            case FieldType.FFun(fn):
                                var printer = new haxe.macro.Printer();
                                var lines = printer.printExpr(fn.expr).split("\n");

                                // Check there is no explicit super.dispose() call
                                for (line in lines) {
                                    if (line.indexOf('super.dispose();') != -1) {
                                        throw new Error("Explicit call to super.dispose() is not allowed. This is done automatically", field.pos);
                                    }
                                }

                                // Ensure expr is surrounded with a block
                                switch (fn.expr.expr) {
                                    case EBlock(exprs):
                                    default:
                                        fn.expr.expr = EBlock([{
                                            pos: fn.expr.pos,
                                            expr: fn.expr.expr
                                        }]);
                                }

                                // Add if destroyed check at the top
                                switch (fn.expr.expr) {
                                    case EBlock(exprs):

                                        exprs.unshift(macro {
                                            if (disposed) return;
                                            super.dispose();
                                        });

                                    default:
                                }

                            default:
                        }
                    }
                    else if (field.name == 'restore') {

                        switch(field.kind) {
                            case FieldType.FFun(fn):
                                var printer = new haxe.macro.Printer();
                                var lines = printer.printExpr(fn.expr).split("\n");

                                // Check there is no explicit super.restore() call
                                for (line in lines) {
                                    if (line.indexOf('super.restore();') != -1) {
                                        throw new Error("Explicit call to super.restore() is not allowed. This is done automatically", field.pos);
                                    }
                                }

                                // Ensure expr is surrounded with a block
                                switch (fn.expr.expr) {
                                    case EBlock(exprs):
                                    default:
                                        fn.expr.expr = EBlock([{
                                            pos: fn.expr.pos,
                                            expr: fn.expr.expr
                                        }]);
                                }

                                switch (fn.expr.expr) {
                                    case EBlock(exprs):

                                        // Add if destroyed check at the top
                                        exprs.unshift(macro {
                                            super.restore();
                                        });

                                    default:
                                }

                            default:
                        }
                    }
                }
            }
        }

        return newFields;

    } //build

    static function hasComponentMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'component') {
                return true;
            }
        }

        return false;

    } //hasComponentMeta

}