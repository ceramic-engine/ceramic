package tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Files;

using StringTools;

class HeadlessTask extends tools.Task {

    override public function info(cwd:String):String {

        return "Run task (headless).";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var taskName = args[1];
        var debug = context.debug;

        var prevVariant = context.variant;
        setVariant('tasks');

        if (taskName == null) {
            fail('Task name argument is required');
        }

        var task = context.tasks.get('headless run');
        var taskArgs = [
            "headless",
            "run",
            "node",
            "--setup",
            "--assets",
            "--variant",
            "tasks",
            "--task",
            taskName
        ];

        if (debug) taskArgs.push('--debug');
        task.run(cwd, taskArgs);

        setVariant(prevVariant);

    }

}
