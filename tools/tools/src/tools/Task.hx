package tools;

import tools.Tools.*;

class Task {

/// Lifecycle

    public function new() {

    } //new

    public function info(cwd:String):String {

        return null;

    } //info

    public function run(cwd:String, args:Array<String>):Void {

        fail('This task has no implementation.');

    } //run

} //Task
