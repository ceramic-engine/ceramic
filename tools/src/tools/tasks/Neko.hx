package tools.tasks;

import haxe.io.Path;
import tools.Helpers.*;

using StringTools;

class Neko extends tools.Task {

    override public function info(cwd:String):String {

        return "Print path to neko command";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var neko = Sys.systemName() == 'Windows' ? 'neko.cmd' : 'neko';
        stdoutWrite(Path.join([context.ceramicToolsPath, neko]) + '\n');

    }

}
