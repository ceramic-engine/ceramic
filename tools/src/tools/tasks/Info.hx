package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;

class Info extends tools.Task {

    override public function info(cwd:String):String {

        return "Print project information depending on the current settings and defines.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        var project = new Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        print(Json.stringify(project.app, null, '    '));

    } //run

} //Info
