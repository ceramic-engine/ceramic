package tools.tasks.android;

import tools.Helpers.*;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class Compile extends tools.Task {

    override public function info(cwd:String):String {

        return "Compile C++ for Android platform.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
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
        var outTargetPath = Path.join([cwd, 'out', 'luxe', 'android' + (variant != 'standard' ? '-' + variant : '')]);

        var archList = archs.split(',');
        for (arch in archList) {
            arch = arch.trim();
            var hxcppArgs = ['run', 'hxcpp', 'Build.xml', '-Dandroid'];
            if (debug) {
                hxcppArgs.push('-Ddebug');
            }
            if (!context.colors) {
                hxcppArgs.push('-DHXCPP_NO_COLOR');
            }

			// Android OpenAL built separately (because of LGPL license, we want to build
			// it separately and link it dynamically at runtime)
            var openALAndroidPath = Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android']);
            switch (arch) {
                case 'armv7':
                    haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_ARMV7'],
                        {cwd: openALAndroidPath});
                    Files.copyIfNeeded(
                        Path.join([openALAndroidPath, 'lib/Android/libopenal-v7.so']),
                        Path.join([openALAndroidPath, 'lib/Android/armeabi-v7a/libopenal.so'])
                    );
                case 'arm64':
                    haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_ARM64'],
                        {cwd: openALAndroidPath});
                    Files.copyIfNeeded(
                        Path.join([openALAndroidPath, 'lib/Android/libopenal-64.so']),
                        Path.join([openALAndroidPath, 'lib/Android/arm64-v8a/libopenal.so'])
                    );
                case 'x86' | 'i386':
                    haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_X86'],
                        {cwd: openALAndroidPath});
                    Files.copyIfNeeded(
                        Path.join([openALAndroidPath, 'lib/Android/libopenal-x86.so']),
                        Path.join([openALAndroidPath, 'lib/Android/x86/libopenal.so'])
                    );
                case 'x86_64':
                    haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_X86_64'],
                        {cwd: openALAndroidPath});
                    // TODO copy
                default:
            }

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

            haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) });
        }

        // Create android project if needed
        AndroidProject.createAndroidProjectIfNeeded(cwd, project);

        // Copy OpenAL binaries if needed
        AndroidProject.copyOpenALBinariesIfNeeded(cwd, project);

        // Copy main binaries if needed
        AndroidProject.copyMainBinariesIfNeeded(cwd, project);

    } //run

} //Compile
