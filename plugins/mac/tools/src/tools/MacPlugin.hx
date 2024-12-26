package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class MacPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Add tasks
        #if mac
        context.addTask('mac app', new tools.tasks.mac.Mac());
        context.addTask('mac compile', new tools.tasks.mac.Compile());
        #end

    }

    public function extendProject(project:Project):Void {

    }

}
