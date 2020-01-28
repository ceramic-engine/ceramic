package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;
import js.node.Os;

using StringTools;

class Version extends tools.Task {

    override public function info(cwd:String):String {

        return "Print ceramic tools version.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var toolsPath = context.ceramicToolsPath;
        var homedir:String = untyped Os.homedir();

        // Git version?
        var hash:String = null;
        var date:String = null;
        if (commandExists('git')) {
            hash = command('git', ['rev-parse', '--short', 'HEAD'], { cwd: toolsPath, mute: true }).stdout.trim();
            if (hash != null && hash != '') {
                date = command('git', ['show', '-s', '--format=%ci', hash], { cwd: toolsPath, mute: true }).stdout.trim();
            }
        }

        if (toolsPath.startsWith(homedir)) {
            toolsPath = Path.join(['~', toolsPath.substring(homedir.length)]);
        }

        if (context.isEmbeddedInElectron && toolsPath.endsWith('/Contents/Resources/app/node_modules/ceramic-tools')) {
            toolsPath = toolsPath.substring(0, toolsPath.length - '/Contents/Resources/app/node_modules/ceramic-tools'.length);
        }
        
        print(context.ceramicVersion + ' (' + toolsPath + ')' + (date != null ? ' $date' : ''));

    }

}
