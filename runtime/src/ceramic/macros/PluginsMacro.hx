package ceramic.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

using StringTools;

/**
 * Macro for automatic plugin initialization in the Ceramic framework.
 * 
 * This macro discovers enabled plugins at compile-time based on compiler defines
 * and generates code to initialize them. It provides a centralized way to
 * initialize all plugins without manually maintaining a list.
 * 
 * ## How It Works
 * 
 * 1. Scans compiler defines for keys starting with `plugin_`
 * 2. Derives plugin class names from the define keys
 * 3. Checks if each plugin class exists and has a `pluginInit()` method
 * 4. Generates initialization calls for all valid plugins
 * 
 * ## Plugin Naming Convention
 * 
 * - Define: `plugin_<name>` (e.g., `plugin_spine`, `plugin_ui`)
 * - Class: `<Name>Plugin` (e.g., `SpinePlugin`, `UiPlugin`)
 * - Special cases handled: `imgui` -> `ImGuiPlugin`
 * 
 * ## Example
 * 
 * ```haxe
 * // In your main application:
 * PluginsMacro.initPlugins();
 * 
 * // With -D plugin_spine -D plugin_ui, generates:
 * // @:privateAccess ceramic.SpinePlugin.pluginInit();
 * // @:privateAccess ceramic.UiPlugin.pluginInit();
 * ```
 * 
 * ## Plugin Requirements
 * 
 * Plugins must:
 * - Be in the `ceramic` package
 * - Have a static `pluginInit()` method
 * - Follow the naming convention
 * 
 * @see ceramic.App Where plugins are initialized during app startup
 */
class PluginsMacro {

    /**
     * Resolves plugin classes and generates initialization calls for each enabled plugin.
     * 
     * This macro examines compiler defines at compile-time to determine which
     * plugins are enabled, then generates the appropriate initialization code.
     * Plugin initialization calls are made with @:privateAccess to allow
     * access to private pluginInit methods.
     * 
     * @return Expression block containing all plugin initialization calls
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