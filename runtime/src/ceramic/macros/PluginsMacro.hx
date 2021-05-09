package ceramic.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

using StringTools;

class PluginsMacro {

    /**
     * Resolves plugin classes and calls pluginInit() for each of them.
     */
    macro public static function initPlugins() {

        var exprs:Array<Expr> = [];

        for (key => val in Context.getDefines()) {
            if (key.startsWith('plugin_')) {
                var pluginName = key.substring('plugin_'.length);
                var pluginTypeName = pluginName.charAt(0).toUpperCase() + pluginName.substring(1) + 'Plugin';

                // Special cases (better if we did not have to do that though)
                if (pluginTypeName == 'ImguiPlugin')
                    pluginTypeName = 'ImGuiPlugin';

                var pluginType = TPath({
                    pack: ['ceramic'],
                    name: pluginTypeName
                });
                try {
                    var resolvedType = Context.resolveType(pluginType, Context.currentPos());
                    if (resolvedType != null) {
                        switch resolvedType {
                            default:
                            case TInst(t, params):
                                var classType = t.get();
                                for (field in classType.statics.get()) {
                                    if (field.name == 'pluginInit') {
                                        exprs.push(
                                            Context.parse(
                                                '@:privateAccess ceramic.' + pluginTypeName + '.pluginInit()', 
                                                Context.currentPos()
                                            )
                                        );
                                        break;
                                    }
                                }
                        }
                    }
                }
                catch (e:Dynamic) {}
            }
        }

        return {
            expr: EBlock(exprs),
            pos: Context.currentPos()
        };

    }

}