package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;

class Path extends tools.Task {

    override public function info(cwd:String):String {

        return "Print ceramic path on this machine.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        js.Node.console.log(context.ceramicToolsPath);

    } //run

} //Link
