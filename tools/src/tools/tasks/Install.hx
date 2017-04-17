package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import haxe.Json;

class Install extends tools.Task {

    override public function info(cwd:String):String {

        return "Install or update " + backend.name + " framework and dependencies.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        backend.runInstall(cwd, args);

    } //run

} //Install