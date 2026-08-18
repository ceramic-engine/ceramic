package tools.tasks.ios;

import haxe.io.Path;
import sys.FileSystem;
import tools.Files;
import tools.Helpers.*;

using StringTools;

class Compile extends tools.Task {

    override public function info(cwd:String):String {

        return "Compile C++ for iOS platform.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var simulator = extractArgFlag(args, 'simulator');
        var archs = extractArgValue(args, 'archs');
        if (archs == null || archs.trim() == '') {
            fail('Missing argument --archs (usage: --archs arm64 or --archs arm64,x86_64)');
        }
        var debug = context.debug;
        var variant = context.variant;
        var project = ensureCeramicProject(cwd, args, App);
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'ios', cwd, debug, variant);

        // When defines changed, the combined per-platform libs are stale
        // too: drop them so they can't be reused in the repackaged
        // xcframework
        if (cleanCppObjectsIfDefinesChanged(Path.join([outTargetPath, 'cpp']))) {
            for (sdkDirName in ['lib-iphoneos', 'lib-iphonesimulator']) {
                var libDir = Path.join([outTargetPath, 'cpp', sdkDirName]);
                if (FileSystem.exists(libDir)) {
                    Files.deleteRecursive(libDir);
                }
            }
        }

        // Compile one static library per architecture
        //
        var builtBinaries = [];
        var archList = archs.split(',');
        for (arch in archList) {
            arch = arch.trim();
            var hxcppArgs = ['run', 'hxcpp', 'Build.xml', '-Dios', '-DHXCPP_CPP17', '-DHXCPP_CLANG'];
            if (debug) {
                hxcppArgs.push('-Ddebug');
            }
            if (!context.colors) {
                hxcppArgs.push('-DHXCPP_NO_COLOR');
            }
            if (simulator) {
                hxcppArgs.push('-Dsimulator');
            }
            var libExtra = null;
            switch (arch) {
                case 'arm64':
                    hxcppArgs.push('-DHXCPP_ARM64');
                    libExtra = simulator ? '.iphonesim-arm64' : '.iphoneos-64';
                case 'x86_64':
                    if (!simulator) {
                        fail('The x86_64 arch only exists for the simulator');
                    }
                    hxcppArgs.push('-DHXCPP_M64');
                    libExtra = '.iphonesim-64';
                default:
                    fail('Unsupported ios arch: $arch (supported: arm64, x86_64)');
            }

            print('Compile C++ for arch $arch' + (simulator ? ' (simulator)' : ''));

            if (haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) }).status != 0) {
                fail('Failed to compile C++ for arch $arch');
            }

            builtBinaries.push('libMain' + (debug ? '-debug' : '') + libExtra + '.a');
        }

        // Combine the requested architectures into one static library per
        // platform (device or simulator) — never across platforms: an arm64
        // device slice and an arm64 simulator slice cannot coexist in a fat
        // binary, that distinction belongs to the xcframework
        //
        var sdkName = simulator ? 'iphonesimulator' : 'iphoneos';
        var platformLibDir = Path.join([outTargetPath, 'cpp', 'lib-' + sdkName]);
        if (!FileSystem.exists(platformLibDir)) {
            FileSystem.createDirectory(platformLibDir);
        }
        var platformLib = Path.join([platformLibDir, 'lib' + project.app.name + '.a']);

        if (builtBinaries.length > 1) {
            print('Combine binaries');
            var lipoArgs = ['--sdk', sdkName, 'lipo', '-output', platformLib, '-create'];
            for (binary in builtBinaries) {
                lipoArgs.push(Path.join([outTargetPath, 'cpp', binary]));
            }
            if (command('xcrun', lipoArgs, { cwd: Path.join([outTargetPath, 'cpp']) }).status != 0) {
                fail('Failed to combine binaries');
            }
        }
        else {
            Files.copyIfNeeded(
                Path.join([outTargetPath, 'cpp', builtBinaries[0]]),
                platformLib
            );
        }

        // Package as an xcframework: both platforms live in the same bundle,
        // Xcode picks the slice matching the destination, and the project
        // links a single stable reference with no per-target configuration.
        // Only the platform that was just compiled is refreshed with real
        // code; the other platform's slice is kept as is (or filled with a
        // placeholder if it was never compiled) — it is not the one being
        // linked in this build anyway, and it will be refreshed before
        // getting linked when building for that platform.
        //
        var otherSimulator = !simulator;
        var otherLib = IosProject.compiledLibPath(project, outTargetPath, otherSimulator);
        if (otherLib == null) {
            otherLib = IosProject.appXcframeworkSliceLib(cwd, project, otherSimulator);
        }
        if (otherLib == null) {
            var otherSdkName = otherSimulator ? 'iphonesimulator' : 'iphoneos';
            otherLib = IosProject.createPlaceholderLib(cwd, project, otherSimulator, Path.join([outTargetPath, 'cpp', 'lib-' + otherSdkName + '-placeholder']));
        }

        IosProject.packageAppXcframework(
            cwd, project,
            simulator ? otherLib : platformLib,
            simulator ? platformLib : otherLib
        );

    }

}
