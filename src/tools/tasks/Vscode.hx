package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;

using StringTools;

class Vscode extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate project files for Visual Studio Code.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        //

    } //run

} //Vscode
