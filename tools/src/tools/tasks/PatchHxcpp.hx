package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class PatchHxcpp extends tools.Task {

    override public function info(cwd:String):String {

        return "Patch HXCPP toolchains to change a few flags.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // TODO

    } //run

} //PatchHxcpp
