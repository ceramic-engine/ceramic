package tools.tasks.plugin;

import tools.Helpers.*;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

class BuildPlugin extends tools.Task {

    override public function info(cwd:String):String {

        return "Build the current plugin.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Use same HXML as completion
        var task = new PluginHxml();
        task.run(cwd, args.concat(['--output', 'build.hxml']));

        // Run haxe
        var result = haxe(['build.hxml']);

        // Remove build.hxml
        FileSystem.deleteFile(Path.join([cwd, 'build.hxml']));

        // Did it build fine?
        if (result.status != 0) {
            fail('Failed to build plugin.');
        }

        // Patch require
        var targetFile = Path.join([cwd, 'index.js']);
        var content = File.getContent(targetFile);
        var lines = content.split("\n");
        var firstLine = lines[0];
        lines[0] = 'require=m=>rReq(m);';
        while (lines[0].length < firstLine.length) {
            lines[0] += '/';
        }
        content = lines.join("\n");
        File.saveContent(targetFile, content);

    } //run

} //BuildPlugin
