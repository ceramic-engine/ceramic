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

        // Sort plugins alphabetically by displayed name (fall back to id)
        var keys = [for (key in context.plugins.keys()) key];
        keys.sort(function(a, b) {
            var na = (context.plugins.get(a).name ?? a).toLowerCase();
            var nb = (context.plugins.get(b).name ?? b).toLowerCase();
            return na < nb ? -1 : (na > nb ? 1 : 0);
        });

        // Print result
        for (key in keys) {
            var info = context.plugins.get(key);
            var path:String = info.path;
            var name:String = info.name;
            print(name + ' ' + path.gray());
        }

    }

}
