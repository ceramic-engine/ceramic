package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class ImGuiPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('imgui setup js', new tools.tasks.imgui.SetupJS());

    }

    public function extendProject(project:Project):Void {

    }

}
