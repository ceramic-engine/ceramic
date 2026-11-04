package tools.tasks.mac;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Colors;
import tools.Files;
import tools.Helpers.*;
import tools.Native;
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

        var macAppSdlLib = Path.join([macAppPath, 'Contents', 'MacOS', 'libSDL3.dylib']);
        var ceramicSdlLib = Path.join([context.ceramicRootPath, 'bin/sdl/sdl3-mac-universal/lib/libSDL3.dylib']);

        var doRun = extractArgFlag(args, 'run');

        // Create mac app package if needed
        MacApp.createMacAppIfNeeded(cwd, project);

        // The binary must have the exact name given by CFBundleExecutable
        // (the template lowercases it): a case mismatch still launches on a
        // case insensitive volume, but breaks the code signature of the bundle
        var macAppBinaryName = macAppExecutableName(macAppPath, project);
        var macAppBinaryFile = Path.join([macAppPath, 'Contents', 'MacOS', macAppBinaryName]);

        // Copy built files and assets
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'mac', cwd, context.debug, context.variant);

        // Copy binary file
        if (!FileSystem.exists(Path.directory(macAppBinaryFile))) {
            FileSystem.createDirectory(Path.directory(macAppBinaryFile));
        }
        removeFilesWithOtherCase(Path.directory(macAppBinaryFile), macAppBinaryName);
        copyToNewFile(Path.join([outTargetPath, 'cpp', context.debug ? 'Main-debug' : 'Main']), macAppBinaryFile);

        // Copy libSDL3
        if (!Files.haveSameLastModified(ceramicSdlLib, macAppSdlLib)) {
            copyToNewFile(ceramicSdlLib, macAppSdlLib);
            Files.setToSameLastModified(ceramicSdlLib, macAppSdlLib);
        }

        var macAppAngleEGL = Path.join([macAppPath, 'Contents', 'MacOS', 'libEGL.dylib']);
        var ceramicAngleEGL = Path.join([context.ceramicRootPath, 'bin/angle/angle-mac-universal/lib/libEGL.dylib']);
        var macAppAngleGLESv2 = Path.join([macAppPath, 'Contents', 'MacOS', 'libGLESv2.dylib']);
        var ceramicAngleGLESv2 = Path.join([context.ceramicRootPath, 'bin/angle/angle-mac-universal/lib/libGLESv2.dylib']);

        if (context.defines.exists('gles_angle')) {

            if (!Files.haveSameLastModified(ceramicAngleEGL, macAppAngleEGL)) {
                copyToNewFile(ceramicAngleEGL, macAppAngleEGL);
                Files.setToSameLastModified(ceramicAngleEGL, macAppAngleEGL);
            }

            if (!Files.haveSameLastModified(ceramicAngleGLESv2, macAppAngleGLESv2)) {
                copyToNewFile(ceramicAngleGLESv2, macAppAngleGLESv2);
                Files.setToSameLastModified(ceramicAngleGLESv2, macAppAngleGLESv2);
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

        // Sign the bundle again, as its content changed
        if (!context.defines.exists('ceramic_mac_no_codesign')) {
            codesignMacApp(macAppPath);
        }

        // Stop if not running
        if (!doRun) return;

        // Prevent multiple instances running
        InstanceManager.makeUnique('run ~ ' + context.cwd);

        // Run project
        print('Start app');

        var status = commandWithChecksAndLogs(
            project.app.name + '.app/Contents/MacOS/' + macAppBinaryName,
            [],
            { cwd: macProjectPath, logCwd: outTargetPath, filter: (line:String) -> {
                return line.indexOf('UNSUPPORTED (log once): POSSIBLE ISSUE: unit') != -1 && line.indexOf('GLD_TEXTURE_INDEX_2D is unloadable and bound to sampler type (Float)') != -1;
            } }
        );

        if (status != 0) {
            Sys.exit(status);
        }

    }

    static function macAppExecutableName(macAppPath:String, project:Project):String {

        var infoPlistPath = Path.join([macAppPath, 'Contents', 'Info.plist']);
        if (FileSystem.exists(infoPlistPath)) {
            var re = ~/<key>CFBundleExecutable<\/key>\s*<string>([^<]+)<\/string>/;
            if (re.match(File.getContent(infoPlistPath))) {
                var name = re.matched(1).trim();
                if (name != '') return name;
            }
        }
        return ('' + project.app.name).toLowerCase();

    }

    /**
     * Remove files of `dirPath` named like `fileName` with a different case
     * (renaming over them on a case insensitive volume keeps the old case).
     */
    static function removeFilesWithOtherCase(dirPath:String, fileName:String):Void {

        if (!FileSystem.exists(dirPath)) return;
        var lowerName = fileName.toLowerCase();
        for (name in FileSystem.readDirectory(dirPath)) {
            if (name != fileName && name.toLowerCase() == lowerName) {
                var path = Path.join([dirPath, name]);
                if (!FileSystem.isDirectory(path)) {
                    FileSystem.deleteFile(path);
                }
            }
        }

    }

    /**
     * Copy `srcFile` to `dstFile` through a new file that replaces the destination.
     * macOS caches the code signature of an executable per inode: overwriting a
     * signed binary or dylib in place gets the next launch killed with
     * "Code Signature Invalid", while a renamed new file is checked from scratch.
     */
    static function copyToNewFile(srcFile:String, dstFile:String):Void {

        var tmpFile = dstFile + '.ceramic-tmp';
        if (FileSystem.exists(tmpFile)) {
            FileSystem.deleteFile(tmpFile);
        }
        File.copy(srcFile, tmpFile);
        FileSystem.rename(tmpFile, dstFile);

    }

    /**
     * Sign the app bundle after its binary and dylibs have been updated.
     * Uses the identity in `CERAMIC_MAC_CODESIGN_IDENTITY` when set,
     * otherwise signs ad hoc (`-`), which is enough to run the app locally.
     * Without this, the bundle could keep a stale `_CodeSignature` that does
     * not match the new binary anymore.
     */
    static function codesignMacApp(macAppPath:String):Void {

        var identity = Sys.getEnv('CERAMIC_MAC_CODESIGN_IDENTITY');
        if (identity == null || identity.trim() == '') {
            identity = '-';
        }
        var adHoc = (identity == '-');

        // Remove any previous seal: codesign writes a fresh one
        var codeSignaturePath = Path.join([macAppPath, 'Contents', '_CodeSignature']);
        if (FileSystem.exists(codeSignaturePath)) {
            Files.deleteRecursive(codeSignaturePath);
        }

        // Nested code must be signed before the bundle itself. When signing
        // ad hoc, a dylib that already verifies is kept untouched (the prebuilt
        // universal dylibs only have a linker signature on some slices, so they
        // are signed once after being copied). With an identity, all of them
        // are signed with it.
        for (dir in ['MacOS', 'Frameworks']) {
            var dirPath = Path.join([macAppPath, 'Contents', dir]);
            if (!FileSystem.exists(dirPath) || !FileSystem.isDirectory(dirPath)) continue;
            for (name in FileSystem.readDirectory(dirPath)) {
                if (!name.endsWith('.dylib')) continue;
                var dylibPath = Path.join([dirPath, name]);
                if (adHoc && command('codesign', ['--verify', dylibPath], { mute: true }).status == 0) continue;
                // Keep the modification time aligned with the source dylib,
                // so that it is not copied (and signed) again on every build
                var mtime = FileSystem.stat(dylibPath).mtime.getTime();
                var res = command('codesign', ['--force', '--sign', identity, dylibPath], { mute: true });
                if (res.status != 0) {
                    fail('Failed to codesign $dylibPath: ' + res.stderr);
                }
                Native.fileUTime(dylibPath, mtime);
            }
        }

        var res = command('codesign', ['--force', '--sign', identity, macAppPath], { mute: true });
        if (res.status != 0) {
            fail('Failed to codesign $macAppPath: ' + res.stderr);
        }

    }

} //Mac