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
        /*var parentHold = Context.getLocalClass().get().superClass;
        var parent = parentHold != null ? parentHold.t : null;
        while (parent != null) {

            for (field in parent.get().fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
        }*/

        var pos = Context.currentPos();

        // Add app
        if (!fieldsByName.exists('app')) {

            fields.push({
                pos: pos,
                name: 'app',
                kind: FProp('get', 'null', TPath({pack: ['ceramic'], name: 'App'})),
                access: [APublic, AStatic],
                doc: 'App instance',
                meta: []
            });

            fields.push({
                pos: pos,
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
                    pos: pos
                }]
            });

        }

        // Add screen
        if (!fieldsByName.exists('screen')) {

            fields.push({
                pos: pos,
                name: 'screen',
                kind: FProp('get', 'null', TPath({pack: ['ceramic'], name: 'Screen'})),
                access: [APublic, AStatic],
                doc: 'Screen instance',
                meta: []
            });

            fields.push({
                pos: pos,
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
                    pos: pos
                }]
            });

        }

        // Add screen
        if (!fieldsByName.exists('settings')) {

            fields.push({
                pos: pos,
                name: 'settings',
                kind: FProp('get', 'null', TPath({pack: ['ceramic'], name: 'Settings'})),
                access: [APublic, AStatic],
                doc: 'Settings instance',
                meta: []
            });

            fields.push({
                pos: pos,
                name: 'get_settings',
                kind: FFun({
                    args: [],
                    ret: TPath({pack: ['ceramic'], name: 'Settings'}),
                    expr: macro {
                        return ceramic.App.app.settings;
                    }
                }),
                access: [APrivate, AStatic, AInline],
                doc: '',
                meta: [{
                    name: ':noCompletion',
                    params: [],
                    pos: pos
                }]
            });

        }

        // Add project
        if (!fieldsByName.exists('project')) {

            fields.push({
                pos: pos,
                name: 'project',
                kind: FProp('get', 'null', TPath({pack: [], name: 'Project'})),
                access: [APublic, AStatic],
                doc: 'Project instance',
                meta: []
            });

            fields.push({
                pos: pos,
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
                    pos: pos
                }]
            });

        }

        // Add log
        if (!fieldsByName.exists('log')) {

            fields.push({
                pos: pos,
                name: 'log',
                kind: FFun({
                    args: [
                        {
                            name: 'value',
                            type: macro :Dynamic
                        },
                        {
                            name: 'pos',
                            type: macro :haxe.PosInfos,
                            opt: true
                        }
                    ],
                    ret: macro :Void,
                    expr: macro {
                        ceramic.App.app.logger.log($i{'value'}, $i{'pos'});
                    }
                }),
                access: [APublic, AStatic, AInline],
                doc: 'Log message',
                meta: []
            });

        }

        // Add warning
        if (!fieldsByName.exists('warning')) {

            fields.push({
                pos: pos,
                name: 'warning',
                kind: FFun({
                    args: [
                        {
                            name: 'value',
                            type: macro :Dynamic
                        },
                        {
                            name: 'pos',
                            type: macro :haxe.PosInfos,
                            opt: true
                        }
                    ],
                    ret: macro :Void,
                    expr: macro {
                        ceramic.App.app.logger.warning($i{'value'}, $i{'pos'});
                    }
                }),
                access: [APublic, AStatic, AInline],
                doc: 'Log warning',
                meta: []
            });

        }

        // Add error
        if (!fieldsByName.exists('error')) {

            fields.push({
                pos: pos,
                name: 'error',
                kind: FFun({
                    args: [
                        {
                            name: 'value',
                            type: macro :Dynamic
                        },
                        {
                            name: 'pos',
                            type: macro :haxe.PosInfos,
                            opt: true
                        }
                    ],
                    ret: macro :Void,
                    expr: macro {
                        ceramic.App.app.logger.error($i{'value'}, $i{'pos'});
                    }
                }),
                access: [APublic, AStatic, AInline],
                doc: 'Log error',
                meta: []
            });

        }

        return fields;

    } //build

}
