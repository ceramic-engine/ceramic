package tools.tasks.android;

import tools.Helpers.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.AndroidProject;

import js.node.ChildProcess;

using StringTools;

class ExportAPK extends tools.Task {

    override public function info(cwd:String):String {

        return "Export a packaged Android app (APK).";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        var project = ensureCeramicProject(cwd, args, App);

        var androidProjectName = project.app.name;
        var androidProjectPath = Path.join([cwd, 'project/android']);

        // Create android project if needed
        AndroidProject.createAndroidProjectIfNeeded(cwd, project);

        // Copy OpenAL binaries if needed
        AndroidProject.copyOpenALBinariesIfNeeded(cwd, project);

        // Update build number
        AndroidProject.updateBuildNumber(cwd, project);

        // Reset build path
        var buildPath = Path.join([androidProjectPath, 'app/build']);
        if (FileSystem.exists(buildPath)) {
            Files.deleteRecursive(buildPath);
        }
        FileSystem.createDirectory(buildPath);

        // Depending on the build tools, apk may not be at the same place. Yea...
        var androidAPKPath = Path.join([buildPath, 'outputs/apk/app-release.apk']);
        var androidAPKPath2 = Path.join([buildPath, 'outputs/apk/release/app-release.apk']);

        // Delete previous apk if any
        if (FileSystem.exists(androidAPKPath)) {
            FileSystem.deleteFile(androidAPKPath);
        }
        if (FileSystem.exists(androidAPKPath2)) {
            FileSystem.deleteFile(androidAPKPath2);
        }

        // Export APK
        var result = command('./gradlew', [
            'assembleRelease', '--stacktrace'
        ], { cwd: Path.join([cwd, 'project/android']) });
        if (result.status != 0) {
            fail('Gradle build failed with status ' + result.status);
        }

        // Check that APK has been generated
        if (!FileSystem.exists(androidAPKPath)) {
            if (!FileSystem.exists(androidAPKPath2)) {
                fail('Expected APK file not found at $androidAPKPath or $androidAPKPath2');
            } else {
                // Always export to the same path for consistency sake
                FileSystem.rename(androidAPKPath2, androidAPKPath);
            }
        }

        success('Generated APK file at path: $androidAPKPath');

    } //run

} //ExportAPK
