package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;

class Path extends tools.Task {

    override public function info(cwd:String):String {

        return "Print ceramic path on this machine.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        success(settings.ceramicPath);

    } //run

} //Link
