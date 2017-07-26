package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;

class Unlink extends tools.Task {

    override public function info(cwd:String):String {

        return "Remove global ceramic command.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        if (Sys.systemName() == 'Mac') {
            command('rm', ['ceramic'], { cwd: '/usr/local/bin' });
        }

    } //run

} //Unlink
