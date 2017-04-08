package tools;

import ceramic.Events;

class Task implements Events {

/// Events

    @event function out(data:String);

    @event function err(data:String);

    @event function complete(success:Bool);

/// Lifecycle

    public function new() {

    } //new

    public function info(cwd:String):String {

        return null;

    } //info

    public function run(cwd:String, args:Array<String>):Void {

        emitErr('This task has no implementation.');
        emitComplete(false);

    } //run

} //Task
