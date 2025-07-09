package tools.tasks.android;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;

using StringTools;

class Compile extends tools.Task {

    override public function info(cwd:String):String {

        return "Compile C++ for Android platform.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        var archs = extractArgValue(args, 'archs');
        if (archs == null || archs.trim() == '') {
            fail('Missing argument --archs (usage: --archs armv7,arm64)');
        }
        var debug = context.debug;
        var variant = context.variant;
        var project = ensureCeramicProject(cwd, args, App);
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'android', cwd, debug, variant);

        var archList = archs.split(',');
        var archs = [];
        for (arch in archList) {
            arch = arch.trim();
            archs.push(arch);
            var hxcppArgs = ['run', 'hxcpp', 'Build.xml', '-Dandroid'];
            if (debug) {
                hxcppArgs.push('-Ddebug');
            }
            if (!context.colors) {
                hxcppArgs.push('-DHXCPP_NO_COLOR');
            }

            // We can statically link with libc++
            hxcppArgs.push('-DHXCPP_LIBCPP_STATIC');

            switch (arch) {
                case 'armv7':
                    hxcppArgs.push('-DHXCPP_ARMV7');
                case 'arm64':
                    hxcppArgs.push('-DHXCPP_ARM64');
                case 'x86' | 'i386':
                    hxcppArgs.push('-DHXCPP_X86');
                case 'x86_64':
                    hxcppArgs.push('-DHXCPP_X86_64');
                default:
                    warning('Unsupported android arch: $arch');
                    continue;
            }

            print('Compile C++ for arch $arch');

            if (haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) }).status != 0) {
                fail('Failed to compile C++ for arch $arch');
            }
        }

        // Create android project if needed
        AndroidProject.createAndroidProjectIfNeeded(cwd, project);

        // Remove Shared libc++ binaries if needed
        AndroidProject.removeSharedLibCppBinariesIfNeeded(cwd, project, archs);
        AndroidProject.setSharedObjectEnabled(cwd, project, 'c++_shared', false);

        // Copy main binaries if needed
        AndroidProject.copyMainBinariesIfNeeded(cwd, project, archs);

    }

}
