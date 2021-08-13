package tools.tasks.web;

import sys.io.File;
import sys.FileSystem;
import tools.Helpers.*;
import haxe.io.Path;

using StringTools;


class Minify extends tools.Task {

    override public function info(cwd:String):String {

        return "Minify exported javascript file in web project";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);
        var jsName:String = project.app.name;

        var webProjectPath = Path.join([cwd, 'project/web']);
        //var jsFilePath = Path.join([webProjectPath, jsName + '.js']);

        var terserCmd = Path.join([context.ceramicToolsPath, 'node_modules/terser/bin/terser']);

        var cmdArgs = [terserCmd];

        cmdArgs.push('$jsName.js');

        if (context.debug || context.defines.exists('js-source-map')) {
            if (FileSystem.exists(Path.join([webProjectPath, '$jsName.js.map']))) {
                cmdArgs.push('--source-map');
                cmdArgs.push('content=\'$jsName.js.map\'');
            }
        }
        else {
            var minSourceMap = Path.join([webProjectPath, '$jsName.min.js.map']);
            if (FileSystem.exists(minSourceMap)) {
                FileSystem.deleteFile(minSourceMap);
            }
        }

        cmdArgs.push('--compress');
        cmdArgs.push('--mangle');
        cmdArgs.push('--keep-classnames');
        cmdArgs.push('--keep-fnames');

        cmdArgs.push('--output');
        cmdArgs.push('$jsName.min.js');

        node(cmdArgs, {
            cwd: webProjectPath
        });

    }

}
