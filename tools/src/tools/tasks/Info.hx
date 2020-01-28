package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;

class Info extends tools.Task {

    override public function info(cwd:String):String {

        return "Print project information depending on the current settings and defines.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        print(Json.stringify(project.app, null, '    '));

    }

}
