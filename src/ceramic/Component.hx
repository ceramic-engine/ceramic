package ceramic;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

#if !macro
@:autoBuild(ceramic.ComponentMacro.build())
#end
class Component extends Entity implements Events {

    public function new() {

    } //new

    function init():Void {

    } //Void

}

class ComponentMacro {
#if macro

    static var processed = new Map<String,Bool>();

    macro static public function build():Array<Field> {
        var fields = Context.getBuildFields();
        var classPath = Context.getLocalClass().toString();

        for (field in fields) {
            if (field.name == 'new') {
                if (field.access.indexOf(APrivate) == -1 && field.access.indexOf(APublic) == -1) {
                    field.access.push(APublic);
                }
            }
            else if (field.name == 'init') {

                if (field.access.indexOf(AOverride) == -1) {
                    field.access.push(AOverride);
                }

                var isProcessed = processed.exists(classPath+'.init');
                if (!isProcessed) {
                    processed.set(classPath+'.init', true);
                    switch(field.kind) {
                        case FieldType.FFun(fn):
                            var printer = new haxe.macro.Printer();
                            var lines = printer.printExpr(fn.expr).split("\n");

                            // Check there is no explicit super.init() call
                            for (line in lines) {
                                if (line.indexOf('super.init();') != -1) {
                                    throw new Error("Explicit call to super.init() is not allowed. This is done automatically", field.pos);
                                }
                            }

                            switch (fn.expr.expr) {
                                case EBlock(exprs):

                                    // Add super.init(); at the top
                                    exprs.unshift(macro {
                                        super.init();
                                    });

                                default:
                            }

                        default:
                    }
                }
            }
        }

        if (Context.getLocalClass().get().superClass.t.toString() != 'ceramic.Component') {
            // Not a direct descendant, keep fields as is
            return fields;
        }

        var hasEntityField = false;
        for (field in fields) {
            if (field.name == 'entity') {
                hasEntityField = true;
                switch(field.kind) {
                    case FieldType.FVar(type, expr):
                        if (field.access.indexOf(AStatic) != -1) {
                            throw new Error("Entity property cannot be static", field.pos);
                        }
                        if (field.access.indexOf(APrivate) != -1) {
                            throw new Error("Entity property cannot be private", field.pos);
                        }
                        if (field.access.indexOf(APublic) == -1) {
                            field.access.push(APublic);
                        }
                    default:
                        throw new Error("Invalid entity property", field.pos);
                }
                break;
            }
        }

        if (!hasEntityField) {

            var field = {
                pos: Context.currentPos(),
                name: 'entity',
                kind: FVar(TPath({pack: ['ceramic'], name: 'Entity'})),
                access: [APublic],
                doc: '',
                meta: []
            };
            fields.push(field);
        }

        return fields;

    } //build

#end
}
