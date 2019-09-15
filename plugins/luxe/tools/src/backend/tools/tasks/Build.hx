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
		var project = ensureCeramicProject(cwd, args, App);

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

		// Check if we could skip haxe compilation
		var skipHaxeCompilation = false;
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
					skipHaxeCompilation = true;
				}
			}

			if (!skipHaxeCompilation) {
				saveLastModifiedListCallback = function() {
					// Save new last modified list
					File.saveContent(lastModifiedListFile, Json.stringify(lastModifiedListAfter));
				};
			} else {
				print('Skip haxe compilation');
			}
		}

		// Build haxe
		var status = 0;
		if (!skipHaxeCompilation && (action == 'build' || action == 'run')) {
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
            
			// Disable c++ compilation from haxe compiler when targetting ios or android,
			// because we will do it with hxcpp directly
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
		if (target.name == 'android') {
			if (archs != null && archs.trim() != '') {
				runTask('android compile', ['--archs', archs.trim()]);
            }
		}

		// Hook
		if (action == 'run') {
			runHooks(cwd, args, project.app.hooks, 'begin run');
		}

		var projectDir = Path.join([cwd, 'project', target.name]);

		// Run for mac
		if ((action == 'run' || action == 'build') && target.name == 'mac') {
			runTask('mac app', action == 'run' ? ['--run'] : []);
			if (action == 'run') {
				runHooks(cwd, args, project.app.hooks, 'end run');
			}
		}
		// Run for iOS
		else if (action == 'run' && target.name == 'ios') {
			runTask('ios xcode', ['--open']);
			runHooks(cwd, args, project.app.hooks, 'end run');
		}
		// Run for Android
		else if (action == 'run' && target.name == 'android') {
			runTask('android studio', ['--open']);
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
