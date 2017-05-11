package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import tools.Tools.*;

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
        
        var cmdArgs = ['run', 'flow', action, target.name];
        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('--debug');
        
        var res = command('haxelib', cmdArgs, { mute: false, cwd: flowProjectPath });
        
        if (res.status != 0) {
            fail('Error when running luxe build. Did you setup this target?');
        }

    } //run

} //Setup
