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

        // Add tasks
        context.addTask('windows app', new tools.tasks.windows.Windows());
        context.addTask('windows cross setup', new tools.tasks.windows.CrossSetup());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

        // Could be useful later
        /*if (app.mac) {
            app.paths.push(Path.join([context.plugins.get('mac').path, 'runtime/src']));
        }*/

    }

}
