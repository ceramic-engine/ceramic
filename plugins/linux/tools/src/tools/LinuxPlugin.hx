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

        // Add tasks
        #if linux
        context.addTask('linux app', new tools.tasks.linux.Linux());
        context.addTask('linux compile', new tools.tasks.linux.Compile());
        #end

    }

    public function extendProject(project:Project):Void {

    }

}
