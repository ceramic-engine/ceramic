package tools.tasks;

import tools.Tools.*;

class Haxe extends tools.Task {

    override public function info(cwd:String):String {

        return "Run haxe binary provided by ceramic.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var result = haxe(args.slice(2));
        if (result.status != 0) {
            js.Node.process.exit(result.status);
        }

    } //run

} //Haxe
