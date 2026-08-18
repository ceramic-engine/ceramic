package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class IosPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('ios bind', new tools.tasks.ios.Bind());
        context.addTask('ios xcode', new tools.tasks.ios.Xcode());
        context.addTask('ios compile', new tools.tasks.ios.Compile());
        context.addTask('ios run device', new tools.tasks.ios.RunDevice());

    }

    public function extendProject(project:Project):Void {

    }

}
