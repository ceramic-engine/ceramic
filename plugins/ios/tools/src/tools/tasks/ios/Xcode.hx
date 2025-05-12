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

        // Copy frameworks if needed
        var iosPojectSdlFramework = Path.join([iosProjectPath, 'Frameworks', 'SDL3.xcframework']);
        var ceramicSdlFramework = Path.join([context.ceramicRootPath, 'bin/sdl/sdl3-ios-universal/SDL3.xcframework']);
        var iosPojectSdlLib = Path.join([iosPojectSdlFramework, 'ios-arm64/SDL3.framework/SDL3']);
        var ceramicSdlLib = Path.join([ceramicSdlFramework, 'ios-arm64/SDL3.framework/SDL3']);
        if (FileSystem.exists(ceramicSdlFramework) && !Files.haveSameLastModified(ceramicSdlLib, iosPojectSdlLib)) {
            Files.copyDirectory(ceramicSdlFramework, iosPojectSdlFramework, true);
        }

        var iosProjectEGLFramework = Path.join([iosProjectPath, 'Frameworks', 'libEGL.xcframework']);
        var ceramicAngleEGLFramework = Path.join([context.ceramicRootPath, 'bin/angle/angle-ios-universal/libEGL.xcframework']);
        var iosProjectEGLLib = Path.join([iosProjectEGLFramework, 'ios-arm64/libEGL.framework/libEGL']);
        var ceramicAngleEGLLib = Path.join([iosProjectEGLFramework, 'ios-arm64/libEGL.framework/libEGL']);

        var iosProjectGLESv2Framework = Path.join([iosProjectPath, 'Frameworks', 'libGLESv2.xcframework']);
        var ceramicAngleGLESv2Framework = Path.join([context.ceramicRootPath, 'bin/angle/angle-ios-universal/libGLESv2.xcframework']);
        var iosProjectGLESv2Lib = Path.join([iosProjectGLESv2Framework, 'ios-arm64/libGLESv2.framework/libGLESv2']);
        var ceramicAngleGLESv2Lib = Path.join([iosProjectGLESv2Framework, 'ios-arm64/libGLESv2.framework/libGLESv2']);

        if (context.defines.exists('gles_angle')) {

            if (FileSystem.exists(ceramicAngleEGLFramework) && !Files.haveSameLastModified(ceramicAngleEGLLib, iosProjectEGLLib)) {
                Files.copyDirectory(ceramicAngleEGLFramework, iosProjectEGLFramework, true);
            }

            if (FileSystem.exists(ceramicAngleGLESv2Framework) && !Files.haveSameLastModified(ceramicAngleGLESv2Lib, iosProjectGLESv2Lib)) {
                Files.copyDirectory(ceramicAngleGLESv2Framework, iosProjectGLESv2Framework, true);
            }

        }
        else {

            if (FileSystem.exists(iosProjectEGLFramework)) {
                Files.deleteRecursive(iosProjectEGLFramework);
            }

            if (FileSystem.exists(iosProjectGLESv2Framework)) {
                Files.deleteRecursive(iosProjectGLESv2Framework);
            }
        }

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

        if (!doOpen) {
            // We can stop here
            return;
        }

        command('open', [fileToOpen]);

    }

}
