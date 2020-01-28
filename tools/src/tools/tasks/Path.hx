package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;

class Path extends tools.Task {

    override public function info(cwd:String):String {

        return "Print ceramic path on this machine.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        print(context.ceramicToolsPath);

    }

}
