package backend.tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;
import tools.Sync;
import js.node.ChildProcess;
import npm.StreamSplitter;

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

        var hxmlProjectPath = Path.join([cwd, 'out', 'headless', target.name + (variant != 'standard' ? '-' + variant : '')]);

        // Load project file
        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        // Ensure hxml project exist
        if (!FileSystem.exists(hxmlProjectPath)) {
            fail('Missing hxml/headless project file. Did you setup this target?');
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

        var status = 0;

        Sync.run(function(done) {

            var proc = ChildProcess.spawn(
                'haxe',
                cmdArgs,
                { cwd: hxmlProjectPath }
            );
            proc.on('close', function(code:Int) {
                status = code;
            });

            var out = StreamSplitter.splitter("\n");
            proc.stdout.pipe(untyped out);
            out.encoding = 'utf8';
            out.on('token', function(token) {
                token = formatLineOutput(hxmlProjectPath, token);
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
            err.on('token', function(token) {
                token = formatLineOutput(hxmlProjectPath, token);
                stderrWrite(token + "\n");
            });
            err.on('error', function(err) {
                warning(''+err);
            });

        });
        
        if (status != 0) {
            fail('Error when running headless $action.');
        }
        else {
            if (action == 'run' || action == 'build') {
                runHooks(cwd, args, project.app.hooks, 'end build');
            }
            else if (action == 'clean') {
                runHooks(cwd, args, project.app.hooks, 'end clean');
            }
        }

    } //run

} //Setup
