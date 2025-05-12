package tools;

import haxe.io.Path;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;

@:keep
class AndroidPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('android bind', new tools.tasks.android.Bind());
        context.addTask('android compile', new tools.tasks.android.Compile());
        context.addTask('android studio', new tools.tasks.android.AndroidStudio());
        context.addTask('android export apk', new tools.tasks.android.ExportAPK());
        context.addTask('android update template', new tools.tasks.android.UpdateTemplate());
        context.addTask('android ndk stack', new tools.tasks.android.NdkStack());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;

        if (app.android) {
            // Do android stuff
        }

    }

}
