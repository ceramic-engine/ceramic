package tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Files;

using StringTools;

class Script extends tools.Task {

    override public function info(cwd:String):String {

        return "Run script (headless).";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var scriptName = args[1];
        var debug = context.debug;
        context.variant = 'scripts';

        if (scriptName == null) {
            fail('Script name argument is required');
        }

        var task = context.tasks.get('headless run');
        var taskArgs = [
            "headless",
            "run",
            "node",
            "--setup",
            "--assets",
            "--variant",
            "scripts",
            "--script",
            scriptName
        ];

        if (debug) taskArgs.push('--debug');
        task.run(cwd, taskArgs);

    } //run

} //Script
