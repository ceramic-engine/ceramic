package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;

class Local extends tools.Task {

    override public function info(cwd:String):String {

        return "Build a local copy of ceramic tools. Will include local plugin tools as well.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args);

        command('node', [Path.join([settings.ceramicPath, 'build-tools.js']), cwd]);

    } //run

} //Local
