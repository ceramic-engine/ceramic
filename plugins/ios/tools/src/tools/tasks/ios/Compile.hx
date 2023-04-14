package tools.tasks.ios;

import haxe.io.Path;
import sys.FileSystem;
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

        var archs = extractArgValue(args, 'archs');
        if (archs == null || archs.trim() == '') {
            fail('Missing argument --archs (usage: --archs armv7,arm64)');
        }
        var debug = context.debug;
        var variant = context.variant;
        var project = ensureCeramicProject(cwd, args, App);
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'ios', cwd, debug, variant);

        var archList = archs.split(',');
        for (arch in archList) {
            arch = arch.trim();
            var hxcppArgs = ['run', 'hxcpp', 'Build.xml', '-Dios', '-DHXCPP_CPP11', '-DHXCPP_CLANG'];
            if (debug) {
                hxcppArgs.push('-Ddebug');
            }
            if (!context.colors) {
                hxcppArgs.push('-DHXCPP_NO_COLOR');
            }
            if (simulator) {
                hxcppArgs.push('-Dsimulator');
            }
            switch (arch) {
                case 'armv7':
                    hxcppArgs.push('-DHXCPP_ARMV7');
                case 'arm64':
                    hxcppArgs.push('-DHXCPP_ARM64');
                case 'x86' | 'i386':
                case 'x86_64':
                    hxcppArgs.push('-DHXCPP_M64');
                default:
                    warning('Unsupported ios arch: $arch');
                    continue;
            }

            print('Compile C++ for arch $arch');

            if (haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) }).status != 0) {
                fail('Failed to compile C++ for arch $arch');
            }
        }

        // Combine binaries
        //
        var allBinaries = [];
        if (debug) {
            if (simulator) {
                allBinaries.push('libMain-debug.iphonesim.a');
                allBinaries.push('libMain-debug.iphonesim-64.a');
                allBinaries.push('libMain-debug.iphonesim-arm64.a');
            }
            else {
                allBinaries.push('libMain-debug.iphoneos-v7.a');
                allBinaries.push('libMain-debug.iphoneos-64.a');
            }
        }
        else {
            if (simulator) {
                allBinaries.push('libMain.iphonesim.a');
                allBinaries.push('libMain.iphonesim-64.a');
                allBinaries.push('libMain.iphonesim-arm64.a');
            }
            else {
                allBinaries.push('libMain.iphoneos-v7.a');
                allBinaries.push('libMain.iphoneos-64.a');
            }
        }

        // Combine
        var lipoArgs = [
            '-sdk','iphoneos', 'lipo',
            '-output', Path.join([outTargetPath, 'cpp', 'lib' + project.app.name + '.a']),
            '-create'
        ];
        for (binary in allBinaries) {
            var binaryPath = Path.join([outTargetPath, 'cpp', binary]);
            if (FileSystem.exists(binaryPath)) {
                lipoArgs.push(binaryPath);
            }
        }
        print('Combine binaries');
        command('xcrun', lipoArgs, { cwd: Path.join([outTargetPath, 'cpp']) });

    }

}
