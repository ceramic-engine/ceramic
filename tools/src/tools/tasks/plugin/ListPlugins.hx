package tools.tasks.plugin;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using tools.Colors;

class ListPlugins extends tools.Task {

    override public function info(cwd:String):String {

        return "List enabled plugins.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Print result
        for (key in context.plugins.keys()) {
            var info = context.plugins.get(key);
            var path:String = info.path;
            var name:String = info.name;
            print(name + ' ' + path.gray());
        }

    }

}
