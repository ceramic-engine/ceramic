package ceramic;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Shortcuts adds convenience identifiers to access ceramic app, screen, ... */
#if !macro
@:autoBuild(ceramic.ShortcutsMacro.build())
#end
interface Shortcuts {}

class ShortcutsMacro {
#if macro

    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();

        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
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

        return fields;

    } //build

#end
}
