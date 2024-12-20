package tools.tasks.android;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Colors;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class AndroidStudio extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or open Android Studio project to build or run it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        var project = ensureCeramicProject(cwd, args, App);

        var androidProjectPath = Path.join([cwd, 'project/android']);
        var androidProjectFile = Path.join([androidProjectPath, 'app/build.gradle']);

        // Create android project if needed
        AndroidProject.createAndroidProjectIfNeeded(cwd, project);

        // Copy java files if needed
        AndroidProject.copyJavaFilesIfNeeded(cwd, project);

        var os = Sys.systemName();

        final openProject = extractArgFlag(args, 'open-project');
        final runApk = extractArgFlag(args, 'run-apk');
        final buildApk = runApk || extractArgFlag(args, 'build-apk');

        if (openProject) {

            if (os == 'Mac' && FileSystem.exists(androidProjectFile)) {

                // Open project

                print('Open Android Studio project');

                command('bash', [
                    Path.join([context.plugins.get('android').path, 'resources/open-android-studio-mac.sh'])
                ]);

            }
            else if (os == 'Windows' && FileSystem.exists(androidProjectFile)) {

                // Open project

                var homedir:String = homedir();
                var androidStudioExePath:String = null;

                for (drive in getWindowsDrives()) {
                    var tryPath = '$drive:/Program Files/Android/Android Studio/bin/studio64.exe';
                    if (FileSystem.exists(tryPath)) {
                        androidStudioExePath = tryPath;
                        break;
                    }
                }

                if (androidStudioExePath == null) {
                    fail('Android Studio does\'t seem to be installed.\nInstall it from: https://developer.android.com/studio');
                }

                success('Project is ready at path: ' + androidProjectPath);
                print('Open it from Android Studio to run/build it.');
                command(androidStudioExePath, [], { detached: true });

            }
        }

        if (buildApk) {

            runTask('android export apk', runApk ? ['--run'] : []);

        }

    }

}
