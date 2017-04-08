package tools.tasks;

import tools.Tools.*;

class Setup extends tools.Task {

    override public function info(cwd:String):String {

        return "Setup a backend target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var targetName = args[2];

        if (targetName == null) {
            fail('You must provide a target to setup.');
        }

        var target = null;
        for (aTarget in backend.getBuildTargets()) {

            if (aTarget.name == targetName) {
                target = aTarget;
                break;
            }

        }

        if (target == null) {
            fail('Unknown target: $targetName');
        }

        // Get and run backend's setup task
        var task = backend.getSetupTask(target);
        task.run(cwd, args);

    } //run

} //Setup
