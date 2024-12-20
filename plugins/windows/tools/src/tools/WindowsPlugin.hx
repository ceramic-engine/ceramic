package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class WindowsPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Add tasks
        context.addTask('windows app', new tools.tasks.windows.Windows());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

        // Could be useful later
        /*if (app.mac) {
            app.paths.push(Path.join([context.plugins.get('mac').path, 'runtime/src']));
        }*/

    }

}
