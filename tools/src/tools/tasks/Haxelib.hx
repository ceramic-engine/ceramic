package tools.tasks;

import haxe.io.Path;
import tools.Helpers.*;

using StringTools;

class Haxelib extends tools.Task {

    override public function info(cwd:String):String {

        return "Print path to haxelib command";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var haxelib = Sys.systemName() == 'Windows' ? 'haxelib.cmd' : 'haxelib';
        stdoutWrite(Path.join([context.ceramicToolsPath, haxelib]) + '\n');

    }

}
