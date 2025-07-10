package tools.tasks.linux;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Colors;
import tools.Files;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class Linux extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Linux app to run or debug it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var linuxProjectPath = Path.join([cwd, 'project/linux']);
        var linuxAppBinaryFile = Path.join([linuxProjectPath, project.app.name]);

        var linuxAppSdlLib = Path.join([linuxProjectPath, 'libSDL3.so']);
        var linuxAppSdl0Lib = Path.join([linuxProjectPath, 'libSDL3.so.0']);
        var linuxAppSdl030Lib = Path.join([linuxProjectPath, 'libSDL3.so.0.3.0']);

        var sdlArch = #if linux_arm64 'arm64' #else 'x64' #end;
        var ceramicSdlLib = Path.join([context.ceramicRootPath, 'bin/sdl/sdl3-linux-$sdlArch/lib/libSDL3.so']);
        var ceramicSdl0Lib = Path.join([context.ceramicRootPath, 'bin/sdl/sdl3-linux-$sdlArch/lib/libSDL3.so.0']);
        var ceramicSdl030Lib = Path.join([context.ceramicRootPath, 'bin/sdl/sdl3-linux-$sdlArch/lib/libSDL3.so.0.3.0']);

        var doRun = extractArgFlag(args, 'run');

        // Create linux app package if needed
        LinuxApp.createLinuxAppIfNeeded(cwd, project);

        // Copy built files and assets
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'linux', cwd, context.debug, context.variant);

        // Copy binary file
        if (!FileSystem.exists(Path.directory(linuxAppBinaryFile))) {
            FileSystem.createDirectory(Path.directory(linuxAppBinaryFile));
        }
        File.copy(Path.join([outTargetPath, 'cpp', context.debug ? 'Main-debug' : 'Main']), linuxAppBinaryFile);
        command('chmod', ['+x', linuxAppBinaryFile]);

        // Copy SDL3 if needed
        if (!Files.haveSameLastModified(ceramicSdlLib, linuxAppSdlLib)) {
            command('cp', ['-Pf', ceramicSdlLib, linuxAppSdlLib]);
            command('cp', ['-Pf', ceramicSdl0Lib, linuxAppSdl0Lib]);
            command('cp', ['-Pf', ceramicSdl030Lib, linuxAppSdl030Lib]);
        }

        // Stop if not running
        if (!doRun) return;

        // Prevent multiple instances running
        InstanceManager.makeUnique('run ~ ' + context.cwd);

        // Run project
        print('Start app ' + project.app.name);

        var status = commandWithChecksAndLogs(
            linuxAppBinaryFile,
            [],
            { cwd: linuxProjectPath, logCwd: outTargetPath }
        );

        if (status != 0) {
            Sys.exit(status);
        }

    }

} //Linux