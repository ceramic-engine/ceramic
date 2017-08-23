package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;

class Update extends tools.Task {

    override public function info(cwd:String):String {

        return "Update or install " + backend.name + " framework and dependencies.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        backend.runUpdate(cwd, args);

    } //run

} //Update