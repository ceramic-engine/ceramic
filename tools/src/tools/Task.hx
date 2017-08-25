package tools;

import tools.Helpers.*;
import tools.spec.BackendTools;

class Task {

    /** Keep a reference to the current backend
        in context when creating the task. */
    var backend:BackendTools = null;

/// Lifecycle

    public function new() {

        backend = context.backend;

    } //new

    public function info(cwd:String):String {

        return null;

    } //info

    public function run(cwd:String, args:Array<String>):Void {

        fail('This task has no implementation.');

    } //run

} //Task
