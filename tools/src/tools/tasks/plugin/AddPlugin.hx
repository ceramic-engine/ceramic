package tools.tasks.plugin;

import tools.Helpers.*;
import tools.Project;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class AddPlugin extends tools.Task {

    override public function info(cwd:String):String {

        return "Add a plugin to ceramic.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Get plugin path
        var path = extractArgValue(args, 'path', true);
        if (path == null) {
            fail('You must specify a plugin path.');
        }

        // Relative path or not?
        var relative = !extractArgFlag(args, 'absolute', true) && (extractArgFlag(args, 'relative', true) || context.isLocalDotCeramic);

        // Parse plugin
        var pluginProjectPath = Path.join([path, 'ceramic.yml']);
        var project = new Project();
        project.loadPluginFile(pluginProjectPath);

        // Get plugin name
        var pluginName = project.plugin.name;

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

        // Set plugin
        Reflect.setField(data.plugins, pluginName, relative ? getRelativePath(path, Path.join([context.dotCeramicPath, '..'])) : path);

        // Save
        File.saveContent(pluginsRegistryPath, Json.stringify(data, null, '  '));

    } //run

} //AddPlugin
