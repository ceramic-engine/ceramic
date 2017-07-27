package tools.tasks;

import tools.Tools.*;

class Haxelib extends tools.Task {

    override public function info(cwd:String):String {

        return "Run haxelib binary provided by ceramic.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var result = haxelib(args.slice(2));
        if (result.status != 0) {
            js.Node.process.exit(result.status);
        }

    } //run

} //Haxelib
