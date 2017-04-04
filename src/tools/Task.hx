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

    public function run():Void {

        emitErr('This task has no implementation.');
        emitComplete(false);

    } //run

} //Task
