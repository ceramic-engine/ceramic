package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class DialogsPlugin {

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
            if (plugins.indexOf('dialogs') != -1) {
                app.paths.push(Path.join([context.plugins.get('dialogs').path, 'runtime/src']));
            }
        }

    }

}
