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

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Compute plugins registry path
        var pluginsRegistryPath = Path.join([context.dotCeramicPath, 'plugins.json']);
        var data = {
            plugins: {}
        };
        if (FileSystem.exists(pluginsRegistryPath)) {
            try {
                data = Json.parse(File.getContent(pluginsRegistryPath));
            }
            catch (e:Dynamic) {
                warning('Failed to open plugins.json: ' + e);
            }
        }

        // Print result
        for (key in Reflect.fields(data.plugins)) {
            var path:String = Reflect.field(data.plugins, key);
            print(key + ' ' + (Path.isAbsolute(path) ? path : Path.join([context.dotCeramicPath, '..', path])).gray());
        }

    } //run

} //ListPlugins
