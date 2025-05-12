package tools.tasks.android;

import haxe.SysTools;
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

        // Update SDL files if needed
        if (!context.defines.exists('ceramic_android_no_sdl_java_update')) {
            final tplSDLJavaFilesPath = Path.join([context.plugins.get('android').path, 'tpl/project/android-clay/app/src/main/java/org/libsdl/app']);
            final projectSDLJavaFilesPath = Path.join([androidProjectPath, 'app/src/main/java/org/libsdl/app']);
            Files.copyDirectory(
                tplSDLJavaFilesPath,
                projectSDLJavaFilesPath
            );
        }

        #if (mac || linux)
        // Make build-haxe.sh executable
        if (FileSystem.exists(Path.join([androidProjectPath, 'build-haxe.sh']))) {
            command('chmod', ['+x', Path.join([androidProjectPath, 'build-haxe.sh'])]);
        }

        // Make gradlew executable
        if (FileSystem.exists(Path.join([androidProjectPath, 'gradlew']))) {
            command('chmod', ['+x', Path.join([androidProjectPath, 'gradlew'])]);
        }
        #end

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
        // Note:
        //   linc_process didn't work correctly for this gradlew command,
        //   so, falling back to haxe's command API. TODO: investigate?
        var prevCwd = Sys.getCwd();
        Sys.setCwd(Path.join([cwd, 'project/android']));
        var status = Sys.command('./gradlew', [
            (doRun ? installVariant : assembleVariant) //, '--stacktrace'
        ]);
        if (status != 0) {
            fail('Gradle build failed with status ' + status);
        }
        Sys.setCwd(prevCwd);

        // Check that APK has been generated
        if (!FileSystem.exists(androidAPKPath)) {
            fail('Expected APK file not found at $androidAPKPath');
        }

        success('Generated APK file at path: $androidAPKPath');

        if (doRun) {
            // Prevent multiple instances running
            InstanceManager.makeUnique('run ~ ' + context.cwd);

            final os = Sys.systemName();
            final sdkPath = AndroidUtils.sdkPath();
            if (sdkPath == null) {
                fail('Cannot run APK because Android SDK was not found (set ANDROID_HOME environment variable in your system to solve this).');
            }
            else {

                final runApkCmd = #if windows 'run-apk.bat' #else 'run-apk.sh' #end;

                print(Path.join([context.plugins.get('android').path, 'resources', runApkCmd]) + ' ' + androidAPKPath + ' ' + sdkPath);
                AndroidUtils.commandWithLogcatOutput(
                    Path.join([context.plugins.get('android').path, 'resources', runApkCmd]),
                    [
                        androidAPKPath,
                        sdkPath
                    ],
                    {
                        debug: context.debug
                    }
                );

                // var packageName:String = Reflect.field(project.app, 'package');
                // packageName = packageName.replace('-', '');

                // final adb = Path.join([sdkPath, 'platform-tools', os == 'Windows' ? 'adb.exe' : 'adb']);

                // final getPidProc = new sys.io.Process(
                //     SysTools.quoteUnixArg(adb),

                // )
                // command(adb, ['shell', 'monkey', '-p', packageName, '-c', 'android.intent.category.LAUNCHER', '1']);

                // final pidofResult = command(adb, ['shell', 'pidof', '-s', packageName]);
                // if (pidofResult.status == 0) {
                //     final pid = pidofResult.stdout.trim();
                //     if (pid == '') {
                //         fail('The app does not seem to be running...');
                //     }
                //     else {
                //         print('PID = ' + pid);
                //     }

                //     /*
                //     Runner.runInBackground(() -> {
                //         while (true) {
                //             var result = new StringBuf();
                //             final proc = new Process(adb, ['shell', 'pidof', '-s', packageName]);
                //             proc.read_stdout = data -> {
                //                 result.add(data);
                //             };
                //             proc.create();
                //             proc.tick_until_exit_status();
                //             if (result.toString().trim() != pid) {
                //                 print('The app has been closed, exiting.');
                //                 Sys.exit(0);
                //             }
                //             Sys.sleep(1.0);
                //         }
                //     });
                //     */

                //     AndroidUtils.commandWithLogcatOutput(adb, ['logcat', '--pid=$pid']);
                // }
            }
        }

    }

}
