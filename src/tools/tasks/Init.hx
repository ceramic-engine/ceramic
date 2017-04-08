package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.FileSystem;

class Init extends tools.Task {

    override public function info(cwd:String):String {

        return "Initialize a new ceramic project.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var project = new Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);

        if (FileSystem.exists(projectPath)) {
            fail('A project already exist at path: ' + projectPath);
        }

        if (args.indexOf('--name') == -1) {
            fail('Project name (--name MyProject) is required.');
        }
        

    } //run

} //Init
