package tools;

import tools.Context;
import tools.Helpers;
import tools.Helpers.*;
import haxe.io.Path;

@:keep
class ToolsPlugin {

    static function main():Void {
        
        var module:Dynamic = js.Node.module;
        module.exports = new ToolsPlugin();

    }

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Add tasks
        var tasks = context.tasks;
        tasks.set('android bind', new tools.tasks.android.Bind());
        tasks.set('android compile', new tools.tasks.android.Compile());
        tasks.set('android studio', new tools.tasks.android.AndroidStudio());
        tasks.set('android ndk stack', new tools.tasks.android.NdkStack());
        tasks.set('android export apk', new tools.tasks.android.ExportAPK());

    }

    public function extendProject(project:Project):Void {

        var app = project.app;
        
        if (app.android) {
            // Do android stuff
        }

    }

}
