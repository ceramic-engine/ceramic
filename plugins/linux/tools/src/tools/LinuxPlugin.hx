package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class LinuxPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Add tasks
        context.addTask('linux app', new tools.tasks.linux.Linux());

    }

    public function extendProject(project:Project):Void {

    }

}
