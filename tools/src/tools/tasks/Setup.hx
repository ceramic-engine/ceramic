package tools.tasks;

import tools.Tools.*;

class Setup extends tools.Task {

    override public function info(cwd:String):String {

        return "Setup a target using " + backend.name + " backend on current project.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var availableTargets = backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);

        if (targetName == null) {
            fail('You must specify a target to setup.');
        }

        // Find target from name
        //
        var target = null;
        for (aTarget in availableTargets) {

            if (aTarget.name == targetName) {
                target = aTarget;
                break;
            }

        }

        if (target == null) {
            fail('Unknown target: $targetName');
        }

        // Add backend define
        if (!settings.defines.exists('luxe')) {
            settings.defines.set('luxe', '');
        }

        // Add target define
        if (!settings.defines.exists(target.name)) {
            settings.defines.set(target.name, '');
        }

        // Get and run backend's setup task
        backend.runSetup(cwd, args, target);

    } //run

} //Setup
