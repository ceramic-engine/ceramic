package backend.tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;

using StringTools;

class UnityBuild extends tools.Task {

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

    }

    override function run(cwd:String, args:Array<String>):Void {

        var hxmlProjectPath = target.outPath('unity', cwd, context.debug, variant);

        // Load project file
        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        // Ensure hxml project exist
        if (!FileSystem.exists(hxmlProjectPath)) {
            fail('Missing hxml/unity project file. Did you setup this target?');
        }

        var action = null;

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
            var targetAssetsPath = Path.join([hxmlProjectPath, 'assets']);
            if (FileSystem.exists(targetAssetsPath)) {
                print('Remove generated assets.');
                tools.Files.deleteRecursive(targetAssetsPath);
            }
        }
        else if (action == 'build' || action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'begin build');
        }

        // Build
        //
        var cmdArgs = ['build.hxml'];
        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('-debug');

        // Only generate C# files. No DLL compilation
        cmdArgs.push('-D');
        cmdArgs.push('no-compilation');

        // Detect if a haxe compilation server is running
        var haxeServerPort = runningHaxeServerPort();
        if (haxeServerPort != -1) {
            cmdArgs.push('--connect');
            cmdArgs.push('' + haxeServerPort);
            cmdArgs.push('-D');
            cmdArgs.push('haxe_server=$haxeServerPort');
        }

        if (haxeServerPort != -1) {
            print('Run haxe compiler (server on port $haxeServerPort)');
        }
        else {
            print('Run haxe compiler');
        }

        var status = 0;

        status = haxeWithChecksAndLogs(cmdArgs, {cwd: hxmlProjectPath});

        if (status != 0) {
            fail('Error when running unity $action.');
        }
        else {
            if (action == 'run' || action == 'build') {
                runHooks(cwd, args, project.app.hooks, 'end build');
            }
            else if (action == 'clean') {
                runHooks(cwd, args, project.app.hooks, 'end clean');
            }
        }

        if (action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'begin run');
        }

        // Update unity project
        runTask('unity project', action == 'run' ? ['--run'] : []);

    }

}
