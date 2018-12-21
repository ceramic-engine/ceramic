package tools.tasks;

import tools.Helpers.*;
import sys.FileSystem;
import haxe.io.Path;
import js.node.Os;

using StringTools;

class Setup extends tools.Task {

    override public function info(cwd:String):String {

        if (context.backend != null) {
            return "Setup a target using " + context.backend.name + " backend on current project.";
        } else {
            return "Setup ceramic on this machine.";
        }

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        if (context.backend != null) {

            ensureCeramicProject(cwd, args, App);

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

        }
        else {

            // Check haxelib repository
            var haxelibRepo = (''+haxelib(['config'], { mute: true }).stdout).trim();
            if (!FileSystem.exists(haxelibRepo)) {
                haxelibRepo = Path.join([untyped Os.homedir(), '.ceramic/haxelib']);
                haxelib(['setup', haxelibRepo]);
                success('Set new haxelib repository: ' + haxelibRepo);
            }
            else {
                success('Keep existing haxelib repository: ' + haxelibRepo);
            }

            // Install required dependencies
            haxelib(['install', 'hxcpp', '--always']);
            haxelib(['install', 'bind', '--always']);
            haxelib(['install', 'unifill', '0.4.1', '--always']);
            haxelib(['install', Path.join([context.ceramicToolsPath, 'build.hxml']), '--always']);
        }

    } //run

} //Setup
