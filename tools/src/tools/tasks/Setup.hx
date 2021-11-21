package tools.tasks;

import haxe.io.Path;
import js.node.Os;
import sys.FileSystem;
import tools.Helpers.*;

using StringTools;

class Setup extends tools.Task {

    override public function info(cwd:String):String {

        if (context.backend != null) {
            return "Setup a target using " + context.backend.name + " backend on current project.";
        } else {
            return "Setup ceramic on this machine.";
        }

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        checkProjectHaxelibSetup(cwd, args);
        installMissingLibsIfNeeded(cwd, args, project);

        if (context.backend != null) {

            var availableTargets = context.backend.getBuildTargets();
            var targetName = getTargetName(args, availableTargets);

            if (targetName == null) {
                fail('You must specify a target to setup.');
            }
            else if (targetName == 'default') {
                if (context.backend.defaultTarget != null) {
                    targetName = context.backend.defaultTarget;
                } else {
                    print('No default target, no setup.');
                    return;
                }
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

            // Get and run backend's setup task
            context.backend.runSetup(cwd, args, target, context.variant);

            // Update tasks?
            if (extractArgFlag(args, 'vscode')) {

                var task = new Vscode();

                var taskArgs = ['--backend', context.backend.name, '--update-tasks'];

                task.run(cwd, taskArgs);

            }

        }
        /*else {

            // Check global/local haxelib repository
            var globalHaxelibRepo = (''+haxelibGlobal(['config'], { mute: true }).stdout).trim();
            var haxelibRepo = (''+haxelib(['config'], { mute: true }).stdout).trim();

            if (!FileSystem.exists(haxelibRepo)) {
                haxelibRepo = Path.join([untyped Os.homedir(), '.ceramic/haxelib']);
                haxelib(['setup', haxelibRepo]);
                haxelibGlobal(['setup', haxelibRepo]);
                success('Set new haxelib repository: ' + haxelibRepo);
            }
            else {
                if (globalHaxelibRepo != haxelibRepo) {
                    haxelibGlobal(['setup', haxelibRepo]);
                }
                success('Keep existing haxelib repository: ' + haxelibRepo);
            }

            // Install required dependencies
            //haxelib(['install', Path.join([context.ceramicToolsPath, 'build.hxml']), '--always']);
        }*/

    }

}
