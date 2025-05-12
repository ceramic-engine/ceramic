package tools.tasks.mac;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Colors;
import tools.Files;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class Mac extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Mac app to run or debug it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var macProjectPath = Path.join([cwd, 'project/mac']);
        var macAppPath = Path.join([macProjectPath, project.app.name + '.app']);
        var macAppBinaryFile = Path.join([macAppPath, 'Contents', 'MacOS', project.app.name]);

        var macAppSdlLib = Path.join([macAppPath, 'Contents', 'MacOS', 'libSDL3.dylib']);
        var ceramicSdlLib = Path.join([context.ceramicRootPath, 'bin/sdl/sdl3-mac-universal/lib/libSDL3.dylib']);

        var doRun = extractArgFlag(args, 'run');

        // Create mac app package if needed
        MacApp.createMacAppIfNeeded(cwd, project);

        // Copy built files and assets
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'mac', cwd, context.debug, context.variant);

        // Copy binary file
        if (!FileSystem.exists(Path.directory(macAppBinaryFile))) {
            FileSystem.createDirectory(Path.directory(macAppBinaryFile));
        }
        File.copy(Path.join([outTargetPath, 'cpp', context.debug ? 'Main-debug' : 'Main']), macAppBinaryFile);

        // Copy libSDL3
        if (!Files.haveSameLastModified(ceramicSdlLib, macAppSdlLib)) {
            File.copy(ceramicSdlLib, macAppSdlLib);
        }

        var macAppAngleEGL = Path.join([macAppPath, 'Contents', 'MacOS', 'libEGL.dylib']);
        var ceramicAngleEGL = Path.join([context.ceramicRootPath, 'bin/angle/angle-mac-universal/lib/libEGL.dylib']);
        var macAppAngleGLESv2 = Path.join([macAppPath, 'Contents', 'MacOS', 'libGLESv2.dylib']);
        var ceramicAngleGLESv2 = Path.join([context.ceramicRootPath, 'bin/angle/angle-mac-universal/lib/libGLESv2.dylib']);

        if (context.defines.exists('gles_angle')) {

            if (!Files.haveSameLastModified(ceramicAngleEGL, macAppAngleEGL)) {
                File.copy(ceramicAngleEGL, macAppAngleEGL);
            }

            if (!Files.haveSameLastModified(ceramicAngleGLESv2, macAppAngleGLESv2)) {
                File.copy(ceramicAngleGLESv2, macAppAngleGLESv2);
            }
        }
        else {

            if (FileSystem.exists(macAppAngleEGL)) {
                FileSystem.deleteFile(macAppAngleEGL);
            }

            if (FileSystem.exists(macAppAngleGLESv2)) {
                FileSystem.deleteFile(macAppAngleGLESv2);
            }
        }

        // Ensure it's still executable
        command('chmod', ['+x', macAppBinaryFile]);

        // Stop if not running
        if (!doRun) return;

        // Prevent multiple instances running
        InstanceManager.makeUnique('run ~ ' + context.cwd);

        // Run project
        print('Start app');

        var status = commandWithChecksAndLogs(
            project.app.name + '.app/Contents/MacOS/' + project.app.name,
            [],
            { cwd: macProjectPath, logCwd: outTargetPath, filter: (line:String) -> {
                return line.indexOf('UNSUPPORTED (log once): POSSIBLE ISSUE: unit') != -1 && line.indexOf('GLD_TEXTURE_INDEX_2D is unloadable and bound to sampler type (Float)') != -1;
            } }
        );

        if (status != 0) {
            Sys.exit(status);
        }

    }

} //Mac