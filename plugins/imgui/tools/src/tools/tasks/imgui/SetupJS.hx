package tools.tasks.imgui;

import tools.Helpers.*;
import tools.Project;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class SetupJS extends tools.Task {

    override public function info(cwd:String):String {

        return "Setup imgui-js files for this ceramic project.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        var webProjectPath = Path.join([cwd, 'project/web']);
        var imguiJSDistPath = Path.join([context.ceramicGitDepsPath, 'imgui-hx/lib/imgui-js/dist']);

        if (!FileSystem.exists(webProjectPath)) {
            FileSystem.createDirectory(webProjectPath);
        }

        for (name in [
            'imgui_impl.umd.js',
            'imgui.umd.js'
        ]) {
            var source = Path.join([imguiJSDistPath, name]);
            var dest = Path.join([webProjectPath, name]);
            if (!Files.haveSameLastModified(source, dest)) {
                success('Copy $name');
                File.copy(source, dest);
                Files.setToSameLastModified(source, dest);
            }
        }

    }

}
