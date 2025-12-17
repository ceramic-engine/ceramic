package tools.tasks.linux;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class Compile extends tools.Task {

    override public function info(cwd:String):String {

        return "Compile C++ for Linux platform.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add linux flag
        if (!context.defines.exists('linux')) {
            context.defines.set('linux', '');
        }

        final mainArch = #if linux_arm64 'arm64' #else 'x86_64' #end;

        var archs = extractArgValue(args, 'archs');
        if (archs == null || archs.trim() == '') {
            fail('Missing argument --archs (usage: --archs arm64,x86_64)');
        }
        var debug = context.debug;
        var variant = context.variant;
        var project = ensureCeramicProject(cwd, args, App);
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'linux', cwd, debug, variant);

        final allBinaries = [];
        final baseBinary = context.debug ? 'Main-debug' : 'Main';

        var archList = archs.split(',');
        var archs = [];
        var hostBinaryPath = null;
        for (arch in archList) {
            arch = arch.trim();
            archs.push(arch);
            var hxcppArgs = ['run', 'hxcpp', 'Build.xml', '-Dlinux'];
            if (debug) {
                hxcppArgs.push('-Ddebug');
            }
            if (!context.colors) {
                hxcppArgs.push('-DHXCPP_NO_COLOR');
            }

            hxcppArgs.push('-DHXCPP_CPP17');
            hxcppArgs.push('-DHXCPP_CLANG');
            hxcppArgs.push('-DHXCPP_RPATH_ORIGIN');

            switch (arch) {
                case 'arm64':
                    hxcppArgs.push('-DHXCPP_ARM64');
                case 'x86_64':
                    hxcppArgs.push('-DHXCPP_X86_64');
                    hxcppArgs.push('-DHXCPP_M64');
                default:
                    warning('Unsupported linux arch: $arch');
                    continue;
            }

            print('Compile C++ for arch $arch');

            if (haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) }).status != 0) {
                fail('Failed to compile C++ for arch $arch');
            }
            else {
                if (archList.length > 0) {
                    final archBinaryPath = Path.join([outTargetPath, 'cpp', baseBinary + '-$arch']);
                    if (mainArch == arch) {
                        hostBinaryPath = archBinaryPath;
                    }
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
            if (allBinaries.length == 1 || hostBinaryPath == null) {
                File.copy(allBinaries[0], Path.join([outTargetPath, 'cpp', baseBinary]));
            }
            else {
                File.copy(hostBinaryPath, Path.join([outTargetPath, 'cpp', baseBinary]));
            }
        }

    }

}
