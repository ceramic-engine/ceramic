package tools.tasks;

import tools.Tools.*;

class Build extends tools.Task {

    override public function info(cwd:String):String {

        return "Build/Run project for the given backend and target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var targetName = args[2];

        if (targetName == null) {
            fail('You must specify a target to setup.');
        }

        // Find target from name
        //
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

        // Add target define
        if (!settings.defines.exists(target.name)) {
            settings.defines.set(target.name, '');
        }

        // TODO

        // Get and run backend's build task
        var task = backend.getSetupTask(target);
        task.run(cwd, args);

    } //run

} //Buildup
