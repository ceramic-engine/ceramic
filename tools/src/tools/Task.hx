package tools;

import tools.Helpers.*;
import tools.spec.BackendTools;
import tools.spec.ToolsPlugin;

class Task {

    /** Keep a reference to the current backend
        in context when creating the task. */
    var backend:BackendTools = null;

    /** Keep a reference to the current plugin
        in context when creating the task. */
    var plugin:ToolsPlugin = null;

    /** Whether this task will be hidden from ceramic help or not. */
    var hidden:Bool = false;

/// Lifecycle

    public function new() {

        backend = context.backend;
        plugin = context.plugin;

    }

    public function info(cwd:String):String {

        return null;

    }

    public function run(cwd:String, args:Array<String>):Void {

        fail('This task has no implementation.');

    }

}
