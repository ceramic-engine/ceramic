package tools.tasks.mac;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;

using StringTools;

class Compile extends tools.Task {

    override public function info(cwd:String):String {

        return "Compile C++ for Mac platform.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add mac flag
        if (!context.defines.exists('mac')) {
            context.defines.set('mac', '');
        }

        var archs = extractArgValue(args, 'archs');
        if (archs == null || archs.trim() == '') {
            fail('Missing argument --archs (usage: --archs arm64,x86_64)');
        }
        var debug = context.debug;
        var variant = context.variant;
        var project = ensureCeramicProject(cwd, args, App);
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'mac', cwd, debug, variant);

        final allBinaries = [];
        final baseBinary = context.debug ? 'Main-debug' : 'Main';

        var archList = archs.split(',');
        var archs = [];
        for (arch in archList) {
            arch = arch.trim();
            archs.push(arch);
            var hxcppArgs = ['run', 'hxcpp', 'Build.xml', '-Dmac'];
            if (debug) {
                hxcppArgs.push('-Ddebug');
            }
            if (!context.colors) {
                hxcppArgs.push('-DHXCPP_NO_COLOR');
            }

            hxcppArgs.push('-DHXCPP_CPP11');
            hxcppArgs.push('-DHXCPP_CLANG');

            switch (arch) {
                case 'arm64':
                    hxcppArgs.push('-DHXCPP_ARM64');
                case 'x86_64':
                    hxcppArgs.push('-DHXCPP_X86_64');
                    hxcppArgs.push('-DHXCPP_M64');
                default:
                    warning('Unsupported mac arch: $arch');
                    continue;
            }

            print('Compile C++ for arch $arch');

            if (haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) }).status != 0) {
                fail('Failed to compile C++ for arch $arch');
            }
            else {
                if (archList.length > 0) {
                    final archBinaryPath = Path.join([outTargetPath, 'cpp', baseBinary + '-$arch']);
                    allBinaries.push(archBinaryPath);
                    if (FileSystem.exists(archBinaryPath) && !FileSystem.isDirectory(archBinaryPath)) {
                        FileSystem.deleteFile(archBinaryPath);
                    }
                    FileSystem.rename(
                        Path.join([outTargetPath, 'cpp', baseBinary]),
                        archBinaryPath
                    );
                }
            }
        }

        if (allBinaries.length > 0) {
            // Need to merge archs with lipo
            print('Create universal binary');
            command('lipo', [
                '-create'].concat(allBinaries).concat([
                '-output', Path.join([outTargetPath, 'cpp', baseBinary])
            ]));
        }

    }

}
