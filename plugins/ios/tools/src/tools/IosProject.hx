package tools;

import haxe.SysTools;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;
import tools.Project;
import tools.Templates;

using StringTools;

class IosProject {

    public static function createIosProjectIfNeeded(cwd:String, project:Project):Void {

        var iosProjectName = project.app.name;
        var iosProjectPath = Path.join([cwd, 'project', 'ios']);
        var iosProjectFile = Path.join([iosProjectPath, iosProjectName + '.xcodeproj']);
        var iosProjectAssetsPath = Path.join([iosProjectPath, 'project', 'assets', 'assets']);
        var tmpProjectAssetsPath = Path.join([cwd, 'project', 'ios-tmp-assets']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(iosProjectFile)) {

            // We are expecting assets to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(iosProjectAssetsPath)) {
                if (FileSystem.exists(tmpProjectAssetsPath)) {
                    Files.deleteRecursive(tmpProjectAssetsPath);
                }
                FileSystem.rename(iosProjectAssetsPath, tmpProjectAssetsPath);
            }

            // Plugin path
            var pluginPath = context.plugins.get('ios').path;

            // Create directory if needed
            if (!FileSystem.exists(iosProjectPath)) {
                FileSystem.createDirectory(iosProjectPath);
            }

            // Copy from template project
            var backendName:String = 'clay'; // Default to clay
            if (context.backend != null) {
                // In some cases (when called from bind hook),
                // backend info is not provided, but when it is, use that.
                // TODO: pass-on backend info for every case?
                backendName = context.backend.name;
            }
            else {
                // A bit hacky, but didn't have a better idea for now
                if (FileSystem.exists(Path.join([cwd, 'out/clay']))) {
                    backendName = 'clay';
                }
                else if (FileSystem.exists(Path.join([cwd, 'out/luxe']))) {
                    // Just to keep compatibility with legacy projects
                    backendName = 'luxe';
                }
            }
            var templateName = 'ios-' + backendName;
            print('Copy from Xcode project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project', templateName]),
                iosProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['MyApp'] = project.app.name;
            Templates.replaceInNames(iosProjectPath, replacementsInNames);

            // Replace in contents
            print('Perform replaces in contents');
            var replacementsInContents = new Map<String,String>();
            if (project.app.company != null) {
                replacementsInContents['My Company'] = project.app.company;
            }
            else if (project.app.author != null) {
                replacementsInContents['My Company'] = project.app.author;
            }
            replacementsInContents['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInContents['MyApp'] = project.app.name;
            replacementsInContents['My App'] = project.app.displayName;
            Templates.replaceInContents(iosProjectPath, replacementsInContents);

            // Put assets back
            if (FileSystem.exists(tmpProjectAssetsPath)) {
                if (FileSystem.exists(iosProjectAssetsPath)) {
                    Files.deleteRecursive(iosProjectAssetsPath);
                }
                FileSystem.rename(tmpProjectAssetsPath, iosProjectAssetsPath);
            }

            // Remove directories that have become empty after replace
            Files.removeEmptyDirectories(iosProjectPath);

            // Make build-haxe.sh executable
            if (FileSystem.exists(Path.join([iosProjectPath, 'build-haxe.sh']))) {
                command('chmod', ['+x', Path.join([iosProjectPath, 'build-haxe.sh'])]);
            }
        }

    }

    public static function appXcframeworkPath(cwd:String, project:Project):String {

        return Path.join([cwd, 'project/ios/Frameworks', project.app.name + '.xcframework']);

    }

    /**
     * Returns the path of the app static library inside the given
     * xcframework for the requested platform, or null if the bundle
     * doesn't contain a slice for that platform.
     */
    public static function appXcframeworkSliceLib(cwd:String, project:Project, simulator:Bool):String {

        var xcframeworkPath = appXcframeworkPath(cwd, project);
        if (!FileSystem.exists(xcframeworkPath))
            return null;

        for (entry in FileSystem.readDirectory(xcframeworkPath)) {
            if (!entry.startsWith('ios-'))
                continue;
            if (entry.endsWith('-simulator') != simulator)
                continue;
            var libPath = Path.join([xcframeworkPath, entry, 'lib' + project.app.name + '.a']);
            if (FileSystem.exists(libPath))
                return libPath;
        }

        return null;

    }

    /**
     * Creates a minimal static library marking the given platform
     * (device or simulator), to be used as a placeholder xcframework
     * slice: xcodebuild validates that the xcframework covers the
     * platform being built at build planning time, before the build
     * phase that compiles the actual code has run, so the bundle must
     * always contain both a device and a simulator slice. Placeholder
     * slices are replaced with the real code by `ios compile`.
     */
    public static function createPlaceholderLib(cwd:String, project:Project, simulator:Bool, destDir:String):String {

        var minVersion = context.defines.exists('HXCPP_IOS_MIN_VERSION') ? context.defines.get('HXCPP_IOS_MIN_VERSION') : '16.0';
        var sdkName = simulator ? 'iphonesimulator' : 'iphoneos';
        var targets = simulator ? ['arm64-apple-ios$minVersion-simulator', 'x86_64-apple-ios$minVersion-simulator'] : ['arm64-apple-ios$minVersion'];

        if (!FileSystem.exists(destDir)) {
            FileSystem.createDirectory(destDir);
        }

        var sourcePath = Path.join([destDir, 'placeholder.c']);
        File.saveContent(sourcePath, '');

        var objectPaths = [];
        for (target in targets) {
            var objectPath = Path.join([destDir, 'placeholder-' + target.split('-')[0] + '.o']);
            if (command('xcrun', ['--sdk', sdkName, 'clang', '-target', target, '-c', sourcePath, '-o', objectPath]).status != 0) {
                fail('Failed to compile placeholder object for target $target');
            }
            objectPaths.push(objectPath);
        }

        var libPath = Path.join([destDir, 'lib' + project.app.name + '.a']);
        var libtoolArgs = ['--sdk', sdkName, 'libtool', '-static', '-no_warning_for_no_symbols', '-o', libPath];
        if (command('xcrun', libtoolArgs.concat(objectPaths)).status != 0) {
            fail('Failed to create placeholder library for $sdkName');
        }

        return libPath;

    }

    /**
     * Packages the app device + simulator static libraries as a single
     * xcframework, referenced by the Xcode project. Both platforms live
     * in the same bundle, Xcode picks the slice matching the build
     * destination, and the project links a single stable reference with
     * no per-target configuration.
     */
    public static function packageAppXcframework(cwd:String, project:Project, deviceLib:String, simulatorLib:String):Void {

        var xcframeworkPath = appXcframeworkPath(cwd, project);

        // Skip repackaging when both slices already match: it keeps the
        // bundle untouched so Xcode can skip re-copying and re-linking it
        var existingDeviceLib = appXcframeworkSliceLib(cwd, project, false);
        var existingSimulatorLib = appXcframeworkSliceLib(cwd, project, true);
        if (existingDeviceLib != null && existingSimulatorLib != null
            && command('cmp', ['-s', deviceLib, existingDeviceLib], { mute: true }).status == 0
            && command('cmp', ['-s', simulatorLib, existingSimulatorLib], { mute: true }).status == 0) {
            return;
        }

        var frameworksDir = Path.directory(xcframeworkPath);
        if (!FileSystem.exists(frameworksDir)) {
            FileSystem.createDirectory(frameworksDir);
        }

        // A source library can be a slice of the existing bundle (when
        // only refreshing the other platform): move it out before the
        // bundle gets deleted. The file name is kept because
        // -create-xcframework uses it as the library name in the slice.
        var tmpDirs = [];
        if (deviceLib.startsWith(xcframeworkPath)) {
            var tmpDir = Path.join([frameworksDir, '.repackage-iphoneos']);
            var tmpLib = Path.join([tmpDir, Path.withoutDirectory(deviceLib)]);
            if (!FileSystem.exists(tmpDir)) {
                FileSystem.createDirectory(tmpDir);
            }
            File.copy(deviceLib, tmpLib);
            deviceLib = tmpLib;
            tmpDirs.push(tmpDir);
        }
        if (simulatorLib.startsWith(xcframeworkPath)) {
            var tmpDir = Path.join([frameworksDir, '.repackage-iphonesimulator']);
            var tmpLib = Path.join([tmpDir, Path.withoutDirectory(simulatorLib)]);
            if (!FileSystem.exists(tmpDir)) {
                FileSystem.createDirectory(tmpDir);
            }
            File.copy(simulatorLib, tmpLib);
            simulatorLib = tmpLib;
            tmpDirs.push(tmpDir);
        }

        // xcodebuild -create-xcframework refuses to overwrite
        if (FileSystem.exists(xcframeworkPath)) {
            Files.deleteRecursive(xcframeworkPath);
        }

        print('Package ' + project.app.name + '.xcframework');
        var status = command('xcodebuild', [
            '-create-xcframework',
            '-library', deviceLib,
            '-library', simulatorLib,
            '-output', xcframeworkPath
        ]).status;

        for (tmpDir in tmpDirs) {
            Files.deleteRecursive(tmpDir);
        }

        if (status != 0) {
            fail('Failed to package xcframework');
        }

    }

    /**
     * Makes sure the app xcframework exists with both a device and a
     * simulator slice, creating placeholder slices when no compiled
     * library is available yet for a platform.
     */
    public static function ensureAppXcframework(cwd:String, project:Project, outTargetPath:String):Void {

        var deviceLib = compiledLibPath(project, outTargetPath, false);
        var simulatorLib = compiledLibPath(project, outTargetPath, true);
        if (deviceLib == null)
            deviceLib = appXcframeworkSliceLib(cwd, project, false);
        if (simulatorLib == null)
            simulatorLib = appXcframeworkSliceLib(cwd, project, true);

        if (deviceLib == null) {
            deviceLib = createPlaceholderLib(cwd, project, false, Path.join([outTargetPath, 'cpp', 'lib-iphoneos-placeholder']));
        }
        if (simulatorLib == null) {
            simulatorLib = createPlaceholderLib(cwd, project, true, Path.join([outTargetPath, 'cpp', 'lib-iphonesimulator-placeholder']));
        }

        packageAppXcframework(cwd, project, deviceLib, simulatorLib);

    }

    /**
     * Returns the path of the compiled per-platform app library
     * (produced by `ios compile`), or null if it doesn't exist yet.
     */
    public static function compiledLibPath(project:Project, outTargetPath:String, simulator:Bool):String {

        var sdkName = simulator ? 'iphonesimulator' : 'iphoneos';
        var libPath = Path.join([outTargetPath, 'cpp', 'lib-' + sdkName, 'lib' + project.app.name + '.a']);
        return FileSystem.exists(libPath) ? libPath : null;

    }

    public static function headerSearchPaths(cwd:String, project:Project, debug:Bool):Array<String> {

        // Get header search paths
        //
        var headerSearchPaths = [];

        // Project headers
        //
        var iosProjectPath = Path.join([cwd, 'project/ios']);

        // Classes included in project root's Classes dir
        headerSearchPaths.push(iosProjectPath + '/project/Classes');
        // Headers included in project root dir
        headerSearchPaths.push(iosProjectPath);
        // Headers included in ceramic project root dir as well
        headerSearchPaths.push(cwd);

        return headerSearchPaths;

    }

}
