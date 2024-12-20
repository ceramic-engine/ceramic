package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class ElectronPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Add tasks
        context.addTask('electron project', new tools.tasks.electron.ExportElectron());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

    }

}
