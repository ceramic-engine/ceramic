package tools;

import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class ShadePlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('shade', new tools.tasks.shade.Shade());

    }

}
