package tools;

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

        // Add tasks
        var tasks = context.tasks;
        tasks.set('spine export', new tools.tasks.spine.ExportSpine());
        tasks.set('spine run', new tools.tasks.spine.RunSpine());
        tasks.set('spine names', new tools.tasks.spine.GenerateNames());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

        if (app.plugins != null && Std.isOfType(app.plugins, Array)) {
            var plugins:Array<String> = app.plugins;
            if (plugins.indexOf('spine') != -1) {
                // Spine enabled

                // Add spine files module path
                app.paths.push(Path.join([context.plugins.get('Spine').path, 'runtime/src']));

                // Add hook to generate gen/assets/Spines.hx & related
                app.hooks.push({
                    'when': 'begin build',
                    'command': 'ceramic',
                    'args': ['spine', 'names']
                });
            }
        }

    }

}
