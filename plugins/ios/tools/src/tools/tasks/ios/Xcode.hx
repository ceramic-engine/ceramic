package tools.tasks.ios;

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

        if (FileSystem.exists(iosProjectFile)) {
            // Open Xcode project
            if (doOpen) print('Open Xcode project');
            fileToOpen = iosProjectFile;
        }
        else {
            // Nothing worked :'(
            fail('Failed to generate or load Xcode project');
        }

        if (!doOpen) {
            // We can stop here
            return;
        }

        command('open', [fileToOpen]);

    }

}
