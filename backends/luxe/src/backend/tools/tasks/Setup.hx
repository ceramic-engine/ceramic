package backend.tools.tasks;

import tools.Tools.*;

class Setup extends tools.Task {

/// Properties

    var target:tools.BuildTarget;

/// Lifecycle

    public function new(target:tools.BuildTarget) {

        super();

        this.target = target;

    } //new

    override function run(cwd:String, args:Array<String>):Void {

        //

    } //run

} //Setup
