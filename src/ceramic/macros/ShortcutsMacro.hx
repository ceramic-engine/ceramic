package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class ShortcutsMacro {

    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();

        // Check class fields
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        // Also check parent fields
        var parentHold = Context.getLocalClass().get().superClass;
        var parent = parentHold != null ? parentHold.t : null;
        while (parent != null) {

            for (field in parent.get().fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
        }

        // Add app
        if (!fieldsByName.exists('app')) {

            fields.push({
                pos: Context.currentPos(),
                name: 'app',
                kind: FProp('get', 'null', TPath({pack: ['ceramic'], name: 'App'})),
                access: [APublic, AStatic],
                doc: 'App instance',
                meta: []
            });

            fields.push({
                pos: Context.currentPos(),
                name: 'get_app',
                kind: FFun({
                    args: [],
                    ret: TPath({pack: ['ceramic'], name: 'App'}),
                    expr: macro {
                        return ceramic.App.app;
                    }
                }),
                access: [APrivate, AStatic, AInline],
                doc: '',
                meta: [{
                    name: ':noCompletion',
                    params: [],
                    pos: Context.currentPos()
                }]
            });

        }

        // Add screen
        if (!fieldsByName.exists('screen')) {

            fields.push({
                pos: Context.currentPos(),
                name: 'screen',
                kind: FProp('get', 'null', TPath({pack: ['ceramic'], name: 'Screen'})),
                access: [APublic, AStatic],
                doc: 'Screen instance',
                meta: []
            });

            fields.push({
                pos: Context.currentPos(),
                name: 'get_screen',
                kind: FFun({
                    args: [],
                    ret: TPath({pack: ['ceramic'], name: 'Screen'}),
                    expr: macro {
                        return ceramic.App.app.screen;
                    }
                }),
                access: [APrivate, AStatic, AInline],
                doc: '',
                meta: [{
                    name: ':noCompletion',
                    params: [],
                    pos: Context.currentPos()
                }]
            });

        }

        // Add project
        if (!fieldsByName.exists('project')) {

            fields.push({
                pos: Context.currentPos(),
                name: 'project',
                kind: FProp('get', 'null', TPath({pack: [], name: 'Project'})),
                access: [APublic, AStatic],
                doc: 'Project instance',
                meta: []
            });

            fields.push({
                pos: Context.currentPos(),
                name: 'get_project',
                kind: FFun({
                    args: [],
                    ret: TPath({pack: [], name: 'Project'}),
                    expr: macro {
                        return ceramic.App.app.project;
                    }
                }),
                access: [APrivate, AStatic, AInline],
                doc: '',
                meta: [{
                    name: ':noCompletion',
                    params: [],
                    pos: Context.currentPos()
                }]
            });

        }

        return fields;

    } //build

}
