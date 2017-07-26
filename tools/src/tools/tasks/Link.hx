package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;

class Link extends tools.Task {

    override public function info(cwd:String):String {

        return "Make this ceramic command global.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        if (Sys.systemName() == 'Mac') {
            command('ln', ['-s', Path.join([settings.ceramicPath, 'ceramic']), 'ceramic'], { cwd: '/usr/local/bin' });
        }

    } //run

} //Link
