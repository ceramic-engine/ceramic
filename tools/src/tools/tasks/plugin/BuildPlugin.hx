package tools.tasks.plugin;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using tools.Colors;

class BuildPlugin extends tools.Task {

    override public function info(cwd:String):String {

        return "Build the current plugin or all enabled plugins (with --all).";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Compute plugin(s) to build
        var pluginPaths = [];
        var all = extractArgFlag(args, 'all', true);

        if (all) {
            for (plugin in context.plugins) {
                pluginPaths.push(plugin.path);
            }
            for (plugin in context.unbuiltPlugins) {
                pluginPaths.push(plugin.path);
            }
        }
        else {
            pluginPaths.push(cwd);
        }

        for (pluginPath in pluginPaths) {

            // Change cwd
            var prevCwd = context.cwd;
            context.cwd = pluginPath;

            var toolsPluginPath = Path.join([pluginPath, 'tools/src/tools/ToolsPlugin.hx']);
            var toolsPluginIndexPath = Path.join([pluginPath, 'index.js']);

            if (all) {
                if (FileSystem.exists(toolsPluginPath)) {
                    print('Build ' + pluginPath.bold());
                }
                else {
                    print('Skip ' + pluginPath.bold());
                    if (FileSystem.exists(toolsPluginIndexPath)) {
                        FileSystem.deleteFile(toolsPluginIndexPath);
                    }
                    if (FileSystem.exists(toolsPluginIndexPath + '.map')) {
                        FileSystem.deleteFile(toolsPluginIndexPath + '.map');
                    }
                    continue;
                }
            }

            // Use same HXML as completion
            var task = new PluginHxml();
            task.run(pluginPath, args.concat(['--output', 'plugin-build.hxml']));

            // Run haxe
            var result = haxe(['plugin-build.hxml']);

            // Remove plugin-build.hxml
            FileSystem.deleteFile(Path.join([pluginPath, 'plugin-build.hxml']));

            // Did it build fine?
            if (result.status != 0) {
                fail('Failed to build plugin.');
            }

            // Patch require
            var targetFile = Path.join([pluginPath, 'index.js']);
            var content = File.getContent(targetFile);
            var lines = content.split("\n");
            var firstLine = lines[0];
            lines[0] = 'require=m=>rReq(m);' + firstLine;
            content = lines.join("\n");
            File.saveContent(targetFile, content);

            context.cwd = prevCwd;

        }

    }

}
