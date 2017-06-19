package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import tools.Tools.*;
import tools.Sync;
import js.node.ChildProcess;
import npm.StreamSplitter;

using StringTools;

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

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);

        // Ensure flow project exist
        if (!FileSystem.exists(flowProjectPath)) {
            fail('Missing flow/luxe project file. Did you setup this target?');
        }

        var backendName = 'luxe';
        var ceramicPath = settings.ceramicPath;

        var outPath = Path.join([cwd, 'out']);
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
            // Remove generated assets on this target if cleaning
            //
            var targetAssetsPath = Path.join([flowProjectPath, 'assets']);
            if (FileSystem.exists(targetAssetsPath)) {
                print('Remove generated assets.');
                tools.Files.deleteRecursive(targetAssetsPath);
            }
        }

        // iOS case
        var cmdAction = action;
        if (cmdAction == 'run' && target.name == 'ios') {
            cmdAction = 'build';
        }
        
        // Clean with flow command
        //
        var cmdArgs = ['run', 'flow', cmdAction, target.name];
        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('--debug');

        var status = 0;

        Sync.run(function(done) {

            var proc = ChildProcess.spawn('haxelib', cmdArgs, { cwd: flowProjectPath });

            var out = StreamSplitter.splitter("\n");
            proc.stdout.pipe(untyped out);
            out.encoding = 'utf8';
            out.on('token', function(token) {
                token = formatLineOutput(flowProjectPath, token);
                js.Node.process.stdout.write(token + "\n");
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
                token = formatLineOutput(flowProjectPath, token);
                js.Node.process.stderr.write(token + "\n");
            });
            err.on('error', function(err) {
                warning(''+err);
            });

        });
        
        if (status != 0) {
            fail('Error when running luxe $action.');
        }

    } //run

} //Setup
