package tools.tasks.windows;

import tools.Helpers.*;
import tools.Project;
import tools.Colors;
import tools.Files;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

import js.node.Os;
import js.node.ChildProcess;
import npm.StreamSplitter;

using StringTools;

class Windows extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Windows app to run or debug it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var windowsProjectPath = Path.join([cwd, 'project/windows']);
        var windowsAppExe = Path.join([windowsProjectPath, project.app.name + '.exe']);

        var appIconPath = Path.join([windowsProjectPath, 'app.ico']);

        var doRun = extractArgFlag(args, 'run');
        var pluginPath = context.plugins.get('Windows').path;

        // Create mac app package if needed
        WindowsApp.createWindowsAppIfNeeded(cwd, project);

        // Copy built files and assets
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'windows', cwd, context.debug, context.variant);

        // Copy binary file
        File.copy(Path.join([outTargetPath, 'cpp', context.debug ? 'Main-debug.exe' : 'Main.exe']), windowsAppExe);

        // Update app icon
        if (FileSystem.exists(appIconPath)) {
            command(Path.join([pluginPath, 'resources', 'rcedit.exe']), [
                windowsAppExe, '--set-icon', appIconPath
            ], {
                cwd: windowsProjectPath
            });
            FileSystem.deleteFile(appIconPath);
        }

        // Copy openal32.dll for correct architecture
        if (context.defines.exists('HXCPP_M32')) {
            Files.copyIfNeeded(
                Path.join([pluginPath, 'resources', 'libs', 'x86', 'openal32.dll']),
                Path.join([windowsProjectPath, 'openal32.dll'])
            );
        }
        else {
            Files.copyIfNeeded(
                Path.join([pluginPath, 'resources', 'libs', 'x86_64', 'openal32.dll']),
                Path.join([windowsProjectPath, 'openal32.dll'])
            );
        }

        // Stop if not running
        if (!doRun) return;

        // Run project
        print('Start app');

        var status = commandWithChecksAndLogs(
            windowsAppExe,
            [],
            { cwd: windowsProjectPath, logCwd: outTargetPath }
        );

        if (status != 0) {
            js.Node.process.exit(status);
        }

    }

} //Windows