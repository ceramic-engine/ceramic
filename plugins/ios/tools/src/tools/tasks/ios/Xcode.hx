package tools.tasks.ios;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.IosProject;

using StringTools;

class Xcode extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or open iOS/Xcode project to build or run it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var project = ensureCeramicProject(cwd, args, App);

        var iosProjectName = project.app.name;
        var iosProjectPath = Path.join([cwd, 'project/ios']);
        var iosProjectFile = Path.join([iosProjectPath, iosProjectName + '.xcodeproj']);
        var iosWorkspaceFile = Path.join([iosProjectPath, iosProjectName + '.xcworkspace']);
        var podfilePath = Path.join([iosProjectPath, 'Podfile']);

        var fileToOpen = null;

        // Create ios project if needed
        IosProject.createIosProjectIfNeeded(cwd, project);

        // Open? Build or Run?
        var doBuild = extractArgFlag(args, 'build');
        var doRun = extractArgFlag(args, 'run');
        var doOpen = doBuild || doRun || extractArgFlag(args, 'open');

        if (FileSystem.exists(iosWorkspaceFile)) {
            // Open Xcode workspace
            if (doOpen) print('Open Xcode workspace');
            fileToOpen = iosWorkspaceFile;
        }
        else if (FileSystem.exists(iosProjectFile)) {
            // Open Xcode project
            if (doOpen) print('Open Xcode project');
            fileToOpen = iosProjectFile;
        }
        else {
            // Nothing worked :'(
            fail('Failed to generate or load Xcode project');
        }

        var appleScriptProjectPath = fileToOpen.substr(1).replace('/', ':');

        // Pods
        if (FileSystem.exists(podfilePath)) {
            // Plug local pods dependencies
            var podfile = File.getContent(podfilePath);
            var prevPodfile = podfile;

            if (project.app.podspecs != null) {
                var podspecs:Array<String> = project.app.podspecs;
                var lines = podfile.split("\n");
                var newLines = [];
                var inLocalCeramicPods = false;
                var indent = 0;
                for (line in lines) {
                    if (inLocalCeramicPods) {
                        if (line.trim() == '# END CERAMIC PODS') {
                            newLines.push(line);
                            inLocalCeramicPods = false;
                        }
                    }
                    else {
                        if (line.trim() == '# BEGIN CERAMIC PODS') {
                            newLines.push(line);
                            indent = line.length - line.ltrim().length;
                            inLocalCeramicPods = true;
                            for (podspec in podspecs) {
                                var podLine = '';
                                for (i in 0...indent) {
                                    podLine += ' ';
                                }
                                var podName = Path.withoutDirectory(podspec);
                                if (podName.endsWith('.podspec')) podName = podName.substring(0, podName.length - '.podspec'.length);
                                podLine += 'pod ' + Json.stringify(podName) + ', :path => ' + Json.stringify(podspec);
                                newLines.push(podLine);
                            }
                        }
                        else {
                            newLines.push(line);
                        }
                    }
                }
                podfile = newLines.join("\n");
                if (podfile != prevPodfile) {
                    print('Update Podfile');
                    File.saveContent(podfilePath, podfile);
                }
            }

            // Check pods
            var podsDir = Path.join([cwd, 'project/ios/Pods']);
            if (!FileSystem.exists(podsDir) || podfile != prevPodfile || extractArgFlag(args, 'pods')) {
                // Initial pod install
                var task = context.task('ios pod install');
                if (task == null) {
                    warning('Cannot install pods because `ceramic pod install` command doesn\'t exist.');
                    warning('Did you enable ceramic\'s ios plugin?');
                }
                else {
                    var taskArgs = ['ios', 'pod', 'install', '--repo-update', '--variant', context.variant];
                    if (context.debug) taskArgs.push('--debug');
                    task.run(cwd, taskArgs);
                }
            }
        }
        else {
            warning("Podfile doesn't exist at path: " + podfilePath);
        }

        if (!doOpen) {
            // We can stop here
            return;
        }

        command('bash', [
            Path.join([context.plugins.get('ios').path, 'resources/open-xcode.sh']),
            '-p',
            appleScriptProjectPath,
            '-a',
            doRun ? 'run' : 'build'
        ]);

    }

}
