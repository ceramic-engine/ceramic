package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import tools.Helpers.*;

class Update extends tools.Task {

    override public function info(cwd:String):String {

        return "Update or install " + context.backend.name + " framework and dependencies.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        context.backend.runUpdate(cwd, args);

    }

}
