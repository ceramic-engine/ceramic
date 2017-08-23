package tools.tasks.plugin;

import tools.Helpers.*;
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class RemovePlugin extends tools.Task {

    override public function info(cwd:String):String {

        return "Remove a ceramic plugin.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Get plugin path or name
        var path = extractArgValue(args, 'path', true);
        var name = extractArgValue(args, 'name', true);
        if (path == null && name == null) {
            fail('You must specify a plugin path or name.');
        }

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

        // Remove plugin
        var newPlugins:Dynamic = {};
        for (key in Reflect.fields(data.plugins)) {
            if (name == null || name != key) {
                var absPath = path != null ? Path.isAbsolute(path) ? path : Path.join([context.cwd, path]) : null;
                var otherPath:String = Reflect.field(data.plugins, key);
                otherPath = Path.isAbsolute(otherPath) ? otherPath : Path.join([context.cwd, otherPath]);
                if (absPath == null || absPath != otherPath) {
                    Reflect.setField(newPlugins, key, Reflect.field(data.plugins, key));
                }
            }
        }
        data.plugins = newPlugins;

        // Save
        File.saveContent(pluginsRegistryPath, Json.stringify(data, null, '  '));

    } //run

} //RemovePlugin
