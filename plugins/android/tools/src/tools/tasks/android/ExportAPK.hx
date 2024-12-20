package tools.tasks.android;

import haxe.io.Path;
import process.Process;
import sys.FileSystem;
import sys.io.File;
import tools.AndroidProject;
import tools.Helpers.*;

using StringTools;

class ExportAPK extends tools.Task {

    override public function info(cwd:String):String {

        return "Export a packaged Android app (APK).";

    }

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

        var doUpdateBuildNumber = extractArgFlag(args, 'update-build-number');
        if (doUpdateBuildNumber) {
            // Update build number
            AndroidProject.updateBuildNumber(cwd, project);
        }

        // Copy java files if needed
        AndroidProject.copyJavaFilesIfNeeded(cwd, project);

        // Reset build path
        var buildPath = Path.join([androidProjectPath, 'app/build']);
        if (FileSystem.exists(buildPath)) {
            Files.deleteRecursive(buildPath);
        }
        FileSystem.createDirectory(buildPath);

        final doRun = extractArgFlag(args, 'run');

        final androidVariant = context.debug ? 'debug' : (doRun ? 'debugNativeRel' : 'release');

        final assembleVariant = 'assemble' + androidVariant.charAt(0).toUpperCase() + androidVariant.substring(1);
        final installVariant = 'install' + androidVariant.charAt(0).toUpperCase() + androidVariant.substring(1);

        var androidAPKPath = Path.join([buildPath, 'outputs/apk/$androidVariant/app-$androidVariant.apk']);

        // Delete previous apk if any
        if (FileSystem.exists(androidAPKPath)) {
            FileSystem.deleteFile(androidAPKPath);
        }

        // Export APK
        var result = command('./gradlew', [
            (doRun ? installVariant : assembleVariant), '--stacktrace'
        ], { cwd: Path.join([cwd, 'project/android']) });
        if (result.status != 0) {
            fail('Gradle build failed with status ' + result.status);
        }

        // Check that APK has been generated
        if (!FileSystem.exists(androidAPKPath)) {
            fail('Expected APK file not found at $androidAPKPath');
        }

        success('Generated APK file at path: $androidAPKPath');

        if (doRun) {
            final os = Sys.systemName();
            final sdkPath = AndroidUtils.sdkPath();
            if (sdkPath == null) {
                fail('Cannot run APK because Android SDK was not found (set ANDROID_HOME environment variable in your system to solve this).');
            }
            else {
                var packageName:String = Reflect.field(project.app, 'package');
                packageName = packageName.replace('-', '');

                final adb = Path.join([sdkPath, 'platform-tools', os == 'Windows' ? 'adb.exe' : 'adb']);

                command(adb, ['shell', 'monkey', '-p', packageName, '-c', 'android.intent.category.LAUNCHER', '1']);

                final pidofResult = command(adb, ['shell', 'pidof', '-s', packageName]);
                if (pidofResult.status == 0) {
                    final pid = pidofResult.stdout.trim();
                    if (pid == '') {
                        fail('The app does not seem to be running...');
                    }

                    Runner.runInBackground(() -> {
                        while (true) {
                            var result = new StringBuf();
                            final proc = new Process(adb, ['shell', 'pidof', '-s', packageName]);
                            proc.read_stdout = data -> {
                                result.add(data);
                            };
                            proc.create();
                            proc.tick_until_exit_status();
                            if (result.toString().trim() != pid) {
                                print('The app has been closed, exiting.');
                                Sys.exit(0);
                            }
                            Sys.sleep(1.0);
                        }
                    });

                    AndroidUtils.commandWithLogcatOutput(adb, ['logcat', '--pid=$pid']);
                }
            }
        }

    }

}
