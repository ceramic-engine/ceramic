package tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;

class Unlink extends tools.Task {

    override public function info(cwd:String):String {

        return "Remove global ceramic command.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        if (Sys.systemName() == 'Mac') {
            command('rm', ['ceramic'], { cwd: '/usr/local/bin' });
        }
        else if (Sys.systemName() == 'Windows') {
            var haxePath = Sys.getEnv('HAXEPATH');
            if (haxePath == null || !FileSystem.exists(Path.join([haxePath, 'ceramic.cmd']))) {
                fail('There is nothing to unlink.');
            }
            FileSystem.deleteFile(Path.join([haxePath, 'ceramic.cmd']));
        }

    }

}
