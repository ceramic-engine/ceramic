package tools.tasks.ios;

import tools.Helpers.*;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class Compile extends tools.Task {

    override public function info(cwd:String):String {

        return "Compile C++ for iOS platform.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var archs = extractArgValue(args, 'archs');
        var debug = context.debug;
        var variant = context.variant;
        var project = context.project;
        var outTargetPath = Path.join([cwd, 'out', 'luxe', 'ios' + (variant != 'standard' ? '-' + variant : '')]);

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
            switch (arch) {
                case 'armv7':
                    hxcppArgs.push('-DHXCPP_ARMV7');
                case 'arm64':
                    hxcppArgs.push('-DHXCPP_ARM64');
                case 'x86' | 'i386':
                    hxcppArgs.push('-Dsimulator');
                case 'x86_64':
                    hxcppArgs.push('-Dsimulator');
                    hxcppArgs.push('-DHXCPP_M64');
                default:
                    warning('Unsupported ios arch: $arch');
                    continue;
            }

            print('Compile C++ for arch $arch cwd=${Path.join([outTargetPath, 'cpp'])}');

            haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) });
        }

        // Combine binaries
        //
        var allBinaries = debug ? [
            'libMain-debug.iphoneos-v7.a',
            'libMain-debug.iphoneos-64.a',
            'libMain-debug.iphonesim.a',
            'libMain-debug.iphonesim-64.a'
        ] : [
            'libMain.iphoneos-v7.a',
            'libMain.iphoneos-64.a',
            'libMain.iphonesim.a',
            'libMain.iphonesim-64.a'
        ];

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

    } //run

} //Compile
