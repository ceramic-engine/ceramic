package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
import haxe.DynamicAccess;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Sync;
import tools.Files;
import js.node.ChildProcess;
import npm.StreamSplitter;
import npm.Chokidar;
import npm.Fiber;

using StringTools;
using tools.Colors;

class Build extends tools.Task {

	/// Properties

	var target:tools.BuildTarget;

	var variant:String;

	var config:tools.BuildTarget.BuildConfig;

	/// Lifecycle

	public function new(target:tools.BuildTarget, variant:String, configIndex:Int) {
		super();

		this.target = target;
		this.variant = variant;
		this.config = target.configs[configIndex];

	} //new

	override function run(cwd:String, args:Array<String>):Void {
		var outTargetPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);

		// Get project file
		var project = context.project;

		// Ensure flow project exist
		if (!FileSystem.exists(outTargetPath)) {
			fail('Missing flow/luxe project file. Did you setup this target?');
		}

		var backendName = 'luxe';
		var ceramicPath = context.ceramicToolsPath;

		var outPath = Path.join([cwd, 'out']);
		var action = null;
		var debug = context.debug;
		var noSkip = extractArgFlag(args, 'no-skip');
		var archs = extractArgValue(args, 'archs');

		switch (config) {
			case Build(displayName):
				action = 'build';
			case Run(displayName):
				action = 'run';
			case Clean(displayName):
				action = 'clean';
		}

		if (action == 'clean') {
			// Simply remove all generated file if cleaning
			runHooks(cwd, args, project.app.hooks, 'begin clean');
			tools.Files.deleteRecursive(outTargetPath);
			runHooks(cwd, args, project.app.hooks, 'end clean');
		}

		// Save last modified list callback
		var saveLastModifiedListCallback:Void->Void = null;

		// Check if we could skip build
		var skipBuild = false;
		if (action == 'run' || action == 'build') {
			var lastModifiedListFile = Path.join([outTargetPath, (debug ? 'lastModifiedList-debug.json' : 'lastModifiedList.json')]);
			var lastModifiedListBefore:DynamicAccess<Float> = null;

			var pathsToScan = [Path.join([cwd, 'src'])];
			var projectPaths:Array<String> = context.project.app.paths;
			for (aPath in projectPaths) {
				if (Path.isAbsolute(aPath) && pathsToScan.indexOf(aPath) == -1) {
					pathsToScan.push(aPath);
				} else {
					aPath = Path.join([cwd, aPath]);
					if (pathsToScan.indexOf(aPath) == -1) {
						pathsToScan.push(aPath);
					}
				}
			}
			var lastModifiedListAfter:DynamicAccess<Float> = {};
			for (toScan in pathsToScan) {
				Files.getDirectoryLastModifiedList(toScan, '.hx', lastModifiedListAfter);
			}

			// Read previous file
			if (FileSystem.exists(lastModifiedListFile)) {
				lastModifiedListBefore = Json.parse(File.getContent(lastModifiedListFile));
			}

			if (!noSkip && lastModifiedListBefore != null) {
				if (!Files.hasDirectoryChanged(lastModifiedListBefore, lastModifiedListAfter)) {
					skipBuild = true;
				}
			}

			if (!skipBuild) {
				saveLastModifiedListCallback = function() {
					// Save new last modified list
					File.saveContent(lastModifiedListFile, Json.stringify(lastModifiedListAfter));
				};
			} else {
				print('Skip build');
			}
		}

		// Build
		var status = 0;
		if (!skipBuild && (action == 'build' || action == 'run')) {
			runHooks(cwd, args, project.app.hooks, 'begin build');

			// // Web case
			// else if (target.name == 'web') {

			//     function buildWeb() {
			//         var rawHxml = context.backend.getHxml(cwd, args, target, context.variant);
			//         var hxmlData = tools.Hxml.parse(rawHxml);
			//         var hxmlTargetCwd = Path.join([cwd, 'project/web']);
			//         var hxmlOriginalCwd = context.backend.getHxmlCwd(cwd, args, target, context.variant);
			//         var finalHxml = tools.Hxml.formatAndChangeRelativeDir(hxmlData, hxmlOriginalCwd, hxmlTargetCwd).join(" ").replace(" \n ", "\n").trim();

			//         if (!FileSystem.exists(hxmlTargetCwd)) {
			//             FileSystem.createDirectory(hxmlTargetCwd);
			//         }

			//         File.saveContent(Path.join([cwd, 'project/web/build.hxml']), finalHxml.rtrim() + "\n");

			//         return haxe([/*'--connect', '127.0.0.1:1451',*/ 'build.hxml'], { cwd: hxmlTargetCwd });
			//     }

			//     // Build for web
			//     var result = buildWeb();
			//     if (result.status != 0) {
			//         fail('Failed to build, exited with status ' + result.status);
			//     }

			//     // TODO haxe compilation server handling?

			// }

			// General target build with haxe
			//
			var cmdArgs = ['project.hxml'];

			if (debug) {
				cmdArgs.push('-debug');
			}
            
            if (target.name == 'ios' || target.name == 'android') {
				cmdArgs.push('-D');
                cmdArgs.push('no-compilation');
            }

			print('Run haxe compiler');

			status = haxeWithChecksAndLogs(cmdArgs, {cwd: outTargetPath});

			if (status == 0) {
				// We can now save last modified list, as build seems ok
				if (saveLastModifiedListCallback != null) {
					saveLastModifiedListCallback();
					saveLastModifiedListCallback = null;
				}
			} else {
				// Build failed
				error('Error when running luxe $action with target ${target.name}. (status = $status)');
				js.Node.process.exit(status);
			}

			runHooks(cwd, args, project.app.hooks, 'end build');
		}

        // Compile c++ for iOS on requested architectures
        if (target.name == 'ios') {
			if (archs != null && archs.trim() != '') {
				runTask('ios compile', ['--archs', archs.trim()]);
            }
        }

        // Compile c++ for Android on requested architectures
		// We might want to move this into Android plugin later
		if (target.name == 'android') {

			// Android OpenAL built separately (because of LGPL license, we want to build
			// it separately and link it dynamically at runtime)
			// TODO move this into android plugin?
			haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_ARMV7'],
				{cwd: Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android'])});
			haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_X86'],
				{cwd: Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android'])});
			haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_ARM64'],
				{cwd: Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android'])});
			/*for (arch in ['armeabi-v7a', 'x86', 'arm64-v8a']) {
				if (!FileSystem.exists(Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/$arch']))) {
					FileSystem.createDirectory(Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/$arch']));
				}
			}
			File.copy(Path.join([
				context.ceramicGitDepsPath,
				'linc_openal/lib/openal-android/lib/Android/libopenal-v7.so'
			]), Path.join([
					context.ceramicGitDepsPath,
					'linc_openal/lib/openal-android/lib/Android/armeabi-v7a/libopenal.so'
				]));
				
			File.copy(Path.join([
				context.ceramicGitDepsPath,
				'linc_openal/lib/openal-android/lib/Android/libopenal-x86.so'
			]), Path.join([
					context.ceramicGitDepsPath,
					'linc_openal/lib/openal-android/lib/Android/x86/libopenal.so'
				]));
				
			File.copy(Path.join([
				context.ceramicGitDepsPath,
				'linc_openal/lib/openal-android/lib/Android/libopenal-64.so'
			]), Path.join([
					context.ceramicGitDepsPath,
					'linc_openal/lib/openal-android/lib/Android/arm64-v8a/libopenal.so'
				]));*/

			if (archs != null && archs.trim() != '') {
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
            }
		}

		// Hook
		if (action == 'run') {
			runHooks(cwd, args, project.app.hooks, 'begin run');
		}

		// Use flow command
		/*var cmdArgs = ['run', 'flow', cmdAction, target.name];
			var debug = extractArgFlag(args, 'debug');
			if (debug) cmdArgs.push('--debug');
			if (archs != null && archs.trim() != '') {
				cmdArgs.push('--archs');
				cmdArgs.push(archs);
		}*/

		var projectDir = Path.join([cwd, 'project', target.name]);

		// Run for mac
		if ((action == 'run' || action == 'build') && target.name == 'mac') {
			// Needs Mac plugin
			var task = context.tasks.get('mac app');
			if (task == null) {
				warning('Cannot create mac app because `ceramic mac app` command doesn\'t exist.');
				warning('Did you enable ceramic\'s mac plugin?');
			} else {
				// Copy binary and optionally run mac app
				var taskArgs = ['mac', 'app', '--variant', context.variant];
				if (action == 'run')
					taskArgs.push('--run');
				if (debug)
					taskArgs.push('--debug');
				task.run(cwd, taskArgs);

				if (action == 'run') {
					runHooks(cwd, args, project.app.hooks, 'end run');
				}
			}
		}
		// Run for iOS
		else if (action == 'run' && target.name == 'ios') {
			runTask('ios xcode', ['--open']);
			runHooks(cwd, args, project.app.hooks, 'end run');
		}
		// Run for Android
		else if (action == 'run' && target.name == 'android') {
			// Needs Android plugin
			var task = context.tasks.get('android studio');
			if (task == null) {
				warning('Cannot run Android project because `ceramic android studio` command doesn\'t exist.');
				warning('Did you enable ceramic\'s android plugin?');
			} else {
				var taskArgs = ['android', 'studio', '--open', '--variant', context.variant];
				if (debug)
					taskArgs.push('--debug');
				task.run(cwd, taskArgs);
			}

			runHooks(cwd, args, project.app.hooks, 'end run');
		}
		// Run for web
		else if ((action == 'run' || action == 'build') && target.name == 'web') {
			// Needs Web plugin
			var task = context.tasks.get('web project');
			if (task == null) {
				warning('Cannot run Web project because `ceramic web project` command doesn\'t exist.');
				warning('Did you enable ceramic\'s web plugin?');
			} else {
				// // Watch?
				// var watch = extractArgFlag(args, 'watch') && action == 'run';
				// if (watch) {
				//     Fiber.fiber(function() {

				//         var watcher = Chokidar.watch('**/*.hx', { cwd: Path.join([cwd, 'src']) });
				//         var lastFileUpdate:Float = -1;
				//         var dirty = false;
				//         var building = false;

				//         function rebuild() {
				//             building = true;
				//             Fiber.fiber(function() {
				//                 // Rebuild
				//                 /*var task = context.tasks.get('luxe build');
				//                 var taskArgs = ['luxe', 'build', 'web', '--variant', context.variant];
				//                 if (debug) taskArgs.push('--debug');
				//                 task.run(cwd, taskArgs);*/
				//                 var result = buildWeb();
				//                 if (result.status != 0) {
				//                     fail('Failed to rebuild, exited with status ' + result.status);
				//                 }
				//                 // Refresh electron runner
				//                 var taskArgs = ['web', 'project', '--variant', context.variant];
				//                 if (debug) taskArgs.push('--debug');
				//                 task.run(cwd, taskArgs);
				//                 building = false;
				//             }).run();
				//         }

				//         js.Node.setInterval(function() {
				//             if (dirty && !building) {
				//                 var time:Float = untyped __js__('new Date().getTime()');
				//                 if (time - lastFileUpdate > 250) {
				//                     dirty = false;
				//                     rebuild();
				//                 }
				//             }
				//         }, 100);

				//         function handleFileChange(path:String) {
				//             lastFileUpdate = untyped __js__('new Date().getTime()');
				//             dirty = true;
				//             print(('Changed: ' + path).magenta());
				//         }

				//         watcher.on('change', handleFileChange);

				//     }).run();
				// }

				// Run with electron runner
				var taskArgs = ['web', 'project', '--variant', context.variant];
				if (action == 'run')
					taskArgs.push('--run');
				if (debug)
					taskArgs.push('--debug');
				// if (watch) taskArgs.push('--watch');
				task.run(cwd, taskArgs);
			}

			if (action == 'run')
				runHooks(cwd, args, project.app.hooks, 'end run');
		} else if (action == 'run') {
			runHooks(cwd, args, project.app.hooks, 'end run');
		}
	} //run

} // Setup
