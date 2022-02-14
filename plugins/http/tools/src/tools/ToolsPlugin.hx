package tools;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

using StringTools;

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

    var didCheckTinkFuture = false;

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

                    if (!didCheckTinkFuture) {
                        // Remove an annoying deprecation warning that pops up on code that is not from us
                        var tinkFuturePath = Path.join([context.cwd, '.haxelib', 'tink_core', '2,0,2', 'src', 'tink', 'core', 'Future.hx']);
                        if (FileSystem.exists(tinkFuturePath)) {
                            var data = File.getContent(tinkFuturePath);
                            var newData = data.replace(" @:deprecated('use Future.irreversible()", " //@:deprecated('use Future.irreversible()");
                            if (data != newData) {
                                success('Patch tink_core Future.hx');
                                File.saveContent(tinkFuturePath, newData);
                            }
                            didCheckTinkFuture = true;
                        }
                    }
                }
            }
        }

    }

}
