package tools.tasks.ios;

import npm.AppleScript;
import tools.Helpers.*;
import tools.IosProject;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class Xcode extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or open iOS/Xcode project to build or run it";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var iosProjectName = project.app.name;
        var iosProjectPath = Path.join([cwd, 'project/ios']);
        var iosProjectFile = Path.join([iosProjectPath, iosProjectName + '.xcodeproj']);
        var iosWorkspaceFile = Path.join([iosProjectPath, iosProjectName + '.xcworkspace']);

        var fileToOpen = null;

        // Create ios project if needed
        IosProject.createIosProjectIfNeeded(cwd, project);

        if (FileSystem.exists(iosWorkspaceFile)) {
            // Open Xcode workspace
            print('Open Xcode workspace');
            fileToOpen = iosWorkspaceFile;
        }
        else if (FileSystem.exists(iosProjectFile)) {
            // Open Xcode project
            print('Open Xcode project');
            fileToOpen = iosProjectFile;
        }
        else {
            // Nothing worked :'(
            fail('Failed to generate or load Xcode project');
        }

        var appleScriptProjectPath = fileToOpen.substr(1).replace('/', ':');

        // Check pods
        var podsDir = Path.join([cwd, 'project/ios/Pods']);
        if (!FileSystem.exists(podsDir)) {
            // Initial pod install
            var task = context.tasks.get('ios pod install');
            if (task == null) {
                warning('Cannot install pods because `ceramic pod install` command doesn\'t exist.');
                warning('Did you enable ceramic\'s ios plugin?');
            }
            else {
                var taskArgs = ['ios', 'pod', 'install', '--variant', context.variant];
                if (context.debug) taskArgs.push('--debug');
                task.run(cwd, taskArgs);
            }
        }

        // Build or Run?
        var doBuild = extractArgFlag(args, 'build');
        var doRun = extractArgFlag(args, 'run');

        // Run one script to open the project. Don't run it yet as it make take
        // some time if Xcode, or the project were not opened.
        Sync.run(function(done) {

            var script = '
                activate application "Xcode"
                tell application "Xcode"
                    open "$appleScriptProjectPath"
                end tell
';

            if (doBuild || doRun) {
                print('Tell Xcode to ' + (doRun ? 'run' : 'build') + ' application');
                script += '
                tell application "System Events"
                    tell process "Xcode"
                        keystroke "' + (doRun ? 'r' : 'b' ) + '" using command down
                    end tell
                end tell
';
            }

            AppleScript.execString(script, function(err, rtn) {
                if (err != null) {
                    fail(''+err);
                }
                done();
            });
        });

    } //run

} //Xcode
