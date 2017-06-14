package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import haxe.Json;

class Update extends tools.Task {

    override public function info(cwd:String):String {

#if use_backend
        return "Update or install " + backend.name + " framework and dependencies.";
#else
        return "Update ceramic and its dependencies.";
#end

    } //info

    override function run(cwd:String, args:Array<String>):Void {

#if use_backend
        backend.runUpdate(cwd, args);
#else
        command('git', ['pull'], { cwd: settings.ceramicPath });
        command('npm', ['install'], { cwd: settings.ceramicPath });
#end

    } //run

} //Update