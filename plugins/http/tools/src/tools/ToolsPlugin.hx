package tools;

import haxe.Json;
import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class ToolsPlugin {

    static function main():Void {

        var module:Dynamic = js.Node.module;
        module.exports = new ToolsPlugin();

    }

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

        if (app.plugins != null && Std.isOfType(app.plugins, Array)) {
            var plugins:Array<String> = app.plugins;
            if (plugins.indexOf('http') != -1) {
                // HTTP enabled
                app.paths.push(Path.join([context.plugins.get('Http').path, 'runtime/src']));

                if (context.backend != null) {
                    var availableTargets = context.backend.getBuildTargets();
                    var target = getTargetName(context.args, availableTargets);
                    var backend = context.backend.name;

                    switch [backend, target] {
                        case [_, 'ios' | 'android' | 'windows' | 'mac' | 'linux']:
                            // Use akifox HTTP
                            app.libs.push('akifox-asynchttp');
                            app.defines.akifox_asynchttp = 'dev';
                        default:
                    }
                }
            }
        }

    }

}
