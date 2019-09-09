package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Sync;
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

#if no_flow
    override function run(cwd:String, args:Array<String>):Void {

        //

    } //run
#else
    override function run(cwd:String, args:Array<String>):Void {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);

        // Load project file
        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        // Ensure flow project exist
        if (!FileSystem.exists(flowProjectPath)) {
            fail('Missing flow/luxe project file. Did you setup this target?');
        }

        var backendName = 'luxe';
        var ceramicPath = context.ceramicToolsPath;

        var outPath = Path.join([cwd, 'out']);
        var action = null;

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
            runHooks(cwd, args, project.app.hooks, 'begin clean');

            // Remove generated assets on this target if cleaning
            //
            var targetAssetsPath = Path.join([flowProjectPath, 'assets']);
            if (FileSystem.exists(targetAssetsPath)) {
                print('Remove generated assets.');
                tools.Files.deleteRecursive(targetAssetsPath);
            }
        }
        else if (action == 'build' || action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'begin build');
        }

        // iOS/Android case
        var cmdAction = action;
        if ((action == 'run' || action == 'build') && (target.name == 'ios' || target.name == 'android' || target.name == 'web')) {
            if (target.name == 'web') {
                cmdAction = 'files';
            }
            else if (archs == null || archs.trim() == '') {
                cmdAction = 'compile';
            }
            else {
                cmdAction = 'build';
            }

            // Android OpenAL built separately (because of LGPL license, we want to build
            // it separately and link it dynamically at runtime)
            // TODO move this into android plugin?
            if (target.name == 'android') {
                haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_ARMV7'], { cwd: Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android']) });
                haxelib(['run', 'hxcpp', 'library.xml', '-Dandroid', '-DHXCPP_X86'], { cwd: Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android']) });
                for (arch in ['armeabi-v7a', 'x86']) {
                    if (!FileSystem.exists(Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/$arch']))) {
                        FileSystem.createDirectory(Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/$arch']));
                    }
                }
                File.copy(
                    Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/libopenal-v7.so']),
                    Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/armeabi-v7a/libopenal.so'])
                );
                File.copy(
                    Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/libopenal-x86.so']),
                    Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/x86/libopenal.so'])
                );
            }
        }
        
        // Hook
        if (action == 'run' && (target.name == 'ios' || target.name == 'android' || target.name == 'web')) {
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

        var cmdArgs = ['project.hxml'];

        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('-debug');

        var status = 0;
        var hasErrorLog = false;

        print('Run haxe compiler...');

        Sync.run(function(done) {

            var haxe = Sys.systemName() == 'Windows' ? 'haxe.cmd' : 'haxe';

            var proc = ChildProcess.spawn(
                Path.join([context.ceramicToolsPath, haxe]),
                cmdArgs,
                { cwd: flowProjectPath }
            );

            var out = StreamSplitter.splitter("\n");
            proc.stdout.pipe(untyped out);
            proc.on('close', function(code:Int) {
                status = code;
            });
            out.encoding = 'utf8';
            out.on('token', function(token:String) {
                if (isErrorOutput(token)) {
                    hasErrorLog = true;
                }
                token = formatLineOutput(flowProjectPath, token);
                stdoutWrite(token + "\n");
            });
            out.on('done', function() {
                done();
            });
            out.on('error', function(err) {
                warning(''+err);
            });

            var err = StreamSplitter.splitter("\n");
            proc.stderr.pipe(untyped err);
            err.encoding = 'utf8';
            err.on('token', function(token:String) {
                if (isErrorOutput(token)) {
                    hasErrorLog = true;
                }
                token = formatLineOutput(flowProjectPath, token);
                stderrWrite(token + "\n");
            });
            err.on('error', function(err) {
                warning(''+err);
            });

        });

        if (status == 0 && hasErrorLog) {
            status = 1;
        }

        function buildWeb() {
            var rawHxml = context.backend.getHxml(cwd, args, target, context.variant);
            var hxmlData = tools.Hxml.parse(rawHxml);
            var hxmlTargetCwd = Path.join([cwd, 'project/web']);
            var hxmlOriginalCwd = context.backend.getHxmlCwd(cwd, args, target, context.variant);
            var finalHxml = tools.Hxml.formatAndChangeRelativeDir(hxmlData, hxmlOriginalCwd, hxmlTargetCwd).join(" ").replace(" \n ", "\n").trim();

            if (!FileSystem.exists(hxmlTargetCwd)) {
                FileSystem.createDirectory(hxmlTargetCwd);
            }

            File.saveContent(Path.join([cwd, 'project/web/build.hxml']), finalHxml.rtrim() + "\n");

            return haxe([/*'--connect', '127.0.0.1:1451',*/ 'build.hxml'], { cwd: hxmlTargetCwd });
        }
        
        if (status != 0) {
            if (!hasErrorLog) fail('Error when running luxe $action.');
            else js.Node.process.exit(status);
        }
        else {

            // Take shortcut when building for web
            if ((action == 'run' || action == 'build') && target.name == 'web') {
                var result = buildWeb();
                if (result.status != 0) {
                    fail('Failed to build, exited with status ' + result.status);
                }
            }

            if (action == 'run' || action == 'build') {
                runHooks(cwd, args, project.app.hooks, 'end build');
            }
            else if (action == 'clean') {
                runHooks(cwd, args, project.app.hooks, 'end clean');
            }
        
            if (action == 'run' && (target.name != 'ios' && target.name != 'web')) {
                runHooks(cwd, args, project.app.hooks, 'end run');
            }
        }

        if (action == 'run' && target.name == 'ios') {
            // Needs iOS plugin
            var task = context.tasks.get('ios xcode');
            if (task == null) {
                warning('Cannot run iOS project because `ceramic ios xcode` command doesn\'t exist.');
                warning('Did you enable ceramic\'s ios plugin?');
            }
            else {
                var taskArgs = ['ios', 'xcode', '--open', '--variant', context.variant];
                if (debug) taskArgs.push('--debug');
                task.run(cwd, taskArgs);
            }
        
            runHooks(cwd, args, project.app.hooks, 'end run');
        }
        else if (action == 'run' && target.name == 'android') {
            // Needs Android plugin
            var task = context.tasks.get('android studio');
            if (task == null) {
                warning('Cannot run Android project because `ceramic android studio` command doesn\'t exist.');
                warning('Did you enable ceramic\'s android plugin?');
            }
            else {
                var taskArgs = ['android', 'studio', '--open', '--variant', context.variant];
                if (debug) taskArgs.push('--debug');
                task.run(cwd, taskArgs);
            }
        
            runHooks(cwd, args, project.app.hooks, 'end run');
        }
        else if ((action == 'run' || action == 'build') && target.name == 'web') {
            // Needs Web plugin
            var task = context.tasks.get('web project');
            if (task == null) {
                warning('Cannot run Web project because `ceramic web project` command doesn\'t exist.');
                warning('Did you enable ceramic\'s web plugin?');
            }
            else {
                // Watch?
                var watch = extractArgFlag(args, 'watch') && action == 'run';
                if (watch) {
                    Fiber.fiber(function() {

                        var watcher = Chokidar.watch('**/*.hx', { cwd: Path.join([cwd, 'src']) });
                        var lastFileUpdate:Float = -1;
                        var dirty = false;
                        var building = false;

                        function rebuild() {
                            building = true;
                            Fiber.fiber(function() {
                                // Rebuild
                                /*var task = context.tasks.get('luxe build');
                                var taskArgs = ['luxe', 'build', 'web', '--variant', context.variant];
                                if (debug) taskArgs.push('--debug');
                                task.run(cwd, taskArgs);*/
                                var result = buildWeb();
                                if (result.status != 0) {
                                    fail('Failed to rebuild, exited with status ' + result.status);
                                }
                                // Refresh electron runner
                                var taskArgs = ['web', 'project', '--variant', context.variant];
                                if (debug) taskArgs.push('--debug');
                                task.run(cwd, taskArgs);
                                building = false;
                            }).run();
                        }

                        js.Node.setInterval(function() {
                            if (dirty && !building) {
                                var time:Float = untyped __js__('new Date().getTime()');
                                if (time - lastFileUpdate > 250) {
                                    dirty = false;
                                    rebuild();
                                }
                            }
                        }, 100);

                        function handleFileChange(path:String) {
                            lastFileUpdate = untyped __js__('new Date().getTime()');
                            dirty = true;
                            print(('Changed: ' + path).magenta());
                        }

                        watcher.on('change', handleFileChange);

                    }).run();
                }

                // Run with electron runner
                var taskArgs = ['web', 'project', '--variant', context.variant];
                if (action == 'run') taskArgs.push('--run');
                if (debug) taskArgs.push('--debug');
                if (watch) taskArgs.push('--watch');
                task.run(cwd, taskArgs);
            }
        
            if (action == 'run') runHooks(cwd, args, project.app.hooks, 'end run');
        }

    } //run
#end

} //Setup
