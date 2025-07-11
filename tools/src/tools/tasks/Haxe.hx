package tools.tasks;

import haxe.io.Path;
import tools.Helpers.*;

using StringTools;

class Haxe extends tools.Task {

    override public function info(cwd:String):String {

        return "Print path to haxe command";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var haxe = Sys.systemName() == 'Windows' ? 'haxe.cmd' : 'haxe';
        stdoutWrite(Path.join([context.ceramicToolsPath, haxe]) + '\n');

    }

}
