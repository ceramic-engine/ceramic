package tools.tasks.ios;

import npm.AppleScript;
import tools.Helpers.*;
import tools.Project;
import tools.Colors;
import tools.IosProject;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

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

        // Run one script to open the project. Don't run it yet as it make take
        // some time if Xcode, or the project were not opened.
        Sync.run(function(done) {

            var script = '
                activate application "Xcode"
                tell application "Xcode"
                    open "$appleScriptProjectPath"
                end tell
            ';

            AppleScript.execString(script, function(err, rtn) {
                if (err != null) {
                    fail(''+err);
                }
                done();
            });
        });

        // Build or Run?
        var doBuild = extractArgFlag(args, 'build');
        var doRun = extractArgFlag(args, 'run');

        if (doBuild || doRun) {
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

            print('Tell Xcode to ' + (doRun ? 'run' : 'build') + ' application');

            // Now that the first script has finished to run, ask again Xcode to open
            // the _already opened_ project so that we ensure it is the focused one
            // (in case multiple projects are opened)
            // Then, run/build it by triggering CMD + R/B
            Sync.run(function(done) {

                var script = '
                    activate application "Xcode"
                    tell application "Xcode"
                        open "$appleScriptProjectPath"
                    end tell
                    tell application "System Events"
                        tell process "Xcode"
                            keystroke "' + (doRun ? 'r' : 'b' ) + '" using command down
                        end tell
                    end tell
                ';

                AppleScript.execString(script, function(err, rtn) {
                    if (err != null) {
                        fail(''+err);
                    }
                    done();
                });
            });
        }

    } //run

    function generateXcodeProject(cwd:String, args:Array<String>, project:Project):Void {

        var iosPluginPath = context.plugins.get('ios').path;
        trace('IOS PLUGIN PATH: $iosPluginPath');
        var projectTplPath = Path.join([context.ceramicToolsPath, 'tpl/ios/project']);

    } //generateXcodeProject

} //Xcode
