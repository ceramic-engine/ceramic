package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class WebPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('web project', new tools.tasks.web.Web());
        context.addTask('web minify', new tools.tasks.web.Minify());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

    }

}
