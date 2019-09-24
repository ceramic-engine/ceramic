package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class ComponentMacro {

    #if (haxe_ver < 4)
    static var onReused:Bool = false;
    #end

    static var processed = new Map<String,Bool>();

    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN ComponentMacro.build()');
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
        var localClass = Context.getLocalClass().get();
        var classPath = Context.getLocalClass().toString();

        // Only transform fields on classes that directly implement Component interface
        var interfaces = localClass.interfaces;
        var directlyImplementsComponent = false;
        for (anInterface in interfaces) {
            if (anInterface.t.toString() == 'ceramic.Component') {
                directlyImplementsComponent = true;
                break;
            }
        }
        if (!directlyImplementsComponent) {
            // Not a direct interface implementation, keep fields as is
            return fields;
        }

        // Ensure that we inherit from ceramic.Entity
        var inheritsFromEntity = (classPath == 'ceramic.Entity');
        var parentHold = localClass.superClass;
        var parent = parentHold != null ? parentHold.t : null;
        var numParents = 0;
        while (parent != null) {

            if (!inheritsFromEntity && parentHold.t.toString() == 'ceramic.Entity') {
                inheritsFromEntity = true;
                break;
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
            numParents++;
        }
        if (!inheritsFromEntity) {
            Context.error("Class " + classPath + " implements ceramic.Component interface thus must inherit (directly or indirectly) from ceramic.Entity", Context.currentPos());
            return fields;
        }

        var hasEntityField = false;
        var hasInitializerNameField = false;
        for (field in fields) {
            if (!hasEntityField && field.name == 'entity') {
                hasEntityField = true;
                switch(field.kind) {
                    case FieldType.FVar(type, expr):
                        if (field.access.indexOf(AStatic) != -1) {
                            Context.error("Entity property cannot be static", field.pos);
                            return fields;
                        }
                        if (field.access.indexOf(APrivate) != -1) {
                            Context.error("Entity property cannot be private", field.pos);
                            return fields;
                        }
                        if (field.access.indexOf(APublic) == -1) {
                            field.access.push(APublic);
                        }
                    default:
                        Context.error("Invalid entity property", field.pos);
                        return fields;
                }
                var hasKeepMeta = false;
                if (field.meta != null) {
                    for (aMeta in field.meta) {
                        if (aMeta.name == ':keep') {
                            hasKeepMeta = true;
                            break;
                        }
                    }
                }
                if (!hasKeepMeta) {
                    if (field.meta == null) field.meta = [];
                    field.meta.push({
                        name: ':keep',
                        params: [],
                        pos: field.pos
                    });
                }
                if (hasInitializerNameField) break;
            }
            else if (!hasInitializerNameField && field.name == 'initializerName') {
                hasInitializerNameField = true;
                if (hasEntityField) break;
            }
        }

        if (!hasEntityField) {

            var field = {
                pos: Context.currentPos(),
                name: 'entity',
                kind: FVar(TPath({pack: ['ceramic'], name: 'Entity'})),
                access: [APublic],
                doc: '',
                meta: [{
                    name: ':keep',
                    params: [],
                    pos: Context.currentPos()
                }]
            };
            fields.push(field);
        }

        if (!hasInitializerNameField) {

            var field = {
                pos: Context.currentPos(),
                name: 'initializerName',
                kind: FProp('default', 'null', TPath({pack: [], name: 'String'}), macro null),
                access: [APublic],
                doc: '',
                meta: []
            };
            fields.push(field);
        }

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END ComponentMacro.build()');
        #end

        return fields;

    } //build

}
