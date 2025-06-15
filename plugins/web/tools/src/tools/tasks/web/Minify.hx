package tools.tasks.web;

import haxe.io.Path;
import process.Process;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;


class Minify extends tools.Task {

    override public function info(cwd:String):String {

        return "Minify exported javascript file in web project";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);
        var jsNames:Array<String> = [project.app.name, 'audio-worklets'];

        var webProjectPath = Path.join([cwd, 'project/web']);

        for (jsName in jsNames) {
            if (FileSystem.exists(Path.join([webProjectPath, '$jsName.js']))) {
                var cmdArgs = [];
                cmdArgs.push(Path.join([context.plugins.get('web').path, 'resources/uglifyjs/node_modules/.bin/uglifyjs']));
                cmdArgs.push('$jsName.js');

                print('Minify javascript: $jsName');

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
                cmdArgs.push('--keep-fnames');

                cmdArgs.push('--output');
                cmdArgs.push('$jsName.min.js');

                node(cmdArgs, {
                    cwd: webProjectPath
                });
            }
        }

    }

}
