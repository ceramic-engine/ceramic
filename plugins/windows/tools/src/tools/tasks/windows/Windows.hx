package tools.tasks.windows;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Colors;
import tools.Files;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class Windows extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Windows app to run or debug it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var windowsProjectPath = Path.join([cwd, 'project/windows']);
        var windowsAppExe = Path.join([windowsProjectPath, project.app.name + '.exe']);

        var winArch = 'x64';
        if (context.defines.exists('HXCPP_ARM64')) {
            winArch = 'arm64';
        }

        var windowsAppSdlLib = Path.join([windowsProjectPath, 'SDL3.dll']);
        var ceramicSdlLib = Path.join([context.ceramicRootPath, 'bin/sdl/sdl3-windows-$winArch/bin/SDL3.dll']);

        var appIconPath = Path.join([windowsProjectPath, 'app.ico']);

        var doRun = extractArgFlag(args, 'run');
        var pluginPath = context.plugins.get('windows').path;

        // Create mac app package if needed
        WindowsApp.createWindowsAppIfNeeded(cwd, project);

        // Copy built files and assets
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'windows', cwd, context.debug, context.variant);

        // Copy binary file
        File.copy(Path.join([outTargetPath, 'cpp', context.debug ? 'Main-debug.exe' : 'Main.exe']), windowsAppExe);

        // Copy libSDL3
        if (!Files.haveSameLastModified(ceramicSdlLib, windowsAppSdlLib)) {
            File.copy(ceramicSdlLib, windowsAppSdlLib);
        }

        var windowsAppAngleEGL = Path.join([windowsProjectPath, 'libEGL.dll']);
        var ceramicAngleEGL = Path.join([context.ceramicRootPath, 'bin/angle/angle-windows-$winArch/bin/libEGL.dll']);
        var windowsAppAngleGLESv2 = Path.join([windowsProjectPath, 'libGLESv2.dll']);
        var ceramicAngleGLESv2 = Path.join([context.ceramicRootPath, 'bin/angle/angle-windows-$winArch/bin/libGLESv2.dll']);
        var windowsAppAngleD3DCompiler = Path.join([windowsProjectPath, 'd3dcompiler_47.dll']);
        var ceramicAngleD3DCompiler = Path.join([context.ceramicRootPath, 'bin/angle/angle-windows-$winArch/bin/d3dcompiler_47.dll']);

        if (context.defines.exists('gles_angle')) {

            if (!Files.haveSameLastModified(ceramicAngleEGL, windowsAppAngleEGL)) {
                File.copy(ceramicAngleEGL, windowsAppAngleEGL);
            }

            if (!Files.haveSameLastModified(ceramicAngleGLESv2, windowsAppAngleGLESv2)) {
                File.copy(ceramicAngleGLESv2, windowsAppAngleGLESv2);
            }

            if (!Files.haveSameLastModified(ceramicAngleD3DCompiler, windowsAppAngleD3DCompiler)) {
                File.copy(ceramicAngleD3DCompiler, windowsAppAngleD3DCompiler);
            }
        }
        else {

            if (FileSystem.exists(windowsAppAngleEGL)) {
                FileSystem.deleteFile(windowsAppAngleEGL);
            }

            if (FileSystem.exists(windowsAppAngleGLESv2)) {
                FileSystem.deleteFile(windowsAppAngleGLESv2);
            }
        }

        // Update app icon
        if (FileSystem.exists(appIconPath)) {
            command(Path.join([pluginPath, 'resources', 'rcedit.exe']), [
                Path.withoutDirectory(windowsAppExe), '--set-icon', Path.withoutDirectory(appIconPath)
            ], {
                cwd: windowsProjectPath
            });
            FileSystem.deleteFile(appIconPath);
        }

        if (context.defines.exists('ceramic_use_openal')) {
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
        }
        else {
            // Remove openal32.dll if it was there before
            if (FileSystem.exists(Path.join([windowsProjectPath, 'openal32.dll']))) {
                FileSystem.deleteFile(Path.join([windowsProjectPath, 'openal32.dll']));
            }
        }

        // Stop if not running
        if (!doRun) return;

        // Prevent multiple instances running
        InstanceManager.makeUnique('run ~ ' + context.cwd);

        // Run project
        print('Start app');

        var status = commandWithChecksAndLogs(
            windowsAppExe,
            [],
            { cwd: windowsProjectPath, logCwd: outTargetPath }
        );

        if (status != 0) {
            Sys.exit(status);
        }

    }

} //Windows