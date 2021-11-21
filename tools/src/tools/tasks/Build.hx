package tools.tasks;

import haxe.crypto.Md5;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

class Build extends tools.Task {

/// Properties

    var kind:String;

    var backendName:String;

/// Lifecycle

    override public function new(kind:String, backendName:String) {

        super();

        this.kind = kind;
        this.backendName = backendName;

    }

    override public function info(cwd:String):String {

        return kind + " project with " + backendName + " backend and given target.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var availableTargets = context.backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);

        if (targetName == null) {
            fail('You must specify a target to build.');
        }

        // Find target from name
        //
        var target = null;
        for (aTarget in availableTargets) {

            if (aTarget.name == targetName) {
                target = aTarget;
                break;
            }

        }

        if (target == null) {
            fail('Unknown target: $targetName');
        }

        // Add target define
        if (!context.defines.exists(target.name)) {
            context.defines.set(target.name, '');
        }

        // Get build config
        //
        var buildConfig = null;
        var configIndex = 0;
        for (conf in target.configs) {
            if (conf.getName() == kind) {
                buildConfig = conf;
                break;
            }
            configIndex++;
        }

        if (buildConfig == null) {
            fail('Invalid configuration ' + kind + ' for target ' + target.name + ' (' + target.displayName + ').');
        }
        else {
            print('Will build with configuration ' + kind + ' for target ' + target.name + (context.debug ? ' debug' : '') + ' (' + target.displayName + ').');
        }

        // Update setup, if needed
        if (extractArgFlag(args, 'setup', true)) {
            checkProjectHaxelibSetup(cwd, args);
            context.backend.runSetup(cwd, ['setup', target.name, '--update-project'], target, context.variant, true);
        }

        // Update assets, if needed
        if (extractArgFlag(args, 'assets', true)) {
            var task = new Assets();
            task.run(cwd, ['assets', target.name, '--variant', context.variant]);
        }

        // Check generated files
        var generatedTplPath = Path.join([context.ceramicToolsPath, 'tpl', 'generated']);
        var generatedFiles = Files.getFlatDirectory(generatedTplPath);
        var projectGenPath = Path.join([context.cwd, 'gen']);
        for (file in generatedFiles) {
            var sourceFile = Path.join([generatedTplPath, file]);
            var destFile = Path.join([projectGenPath, file]);
            if (!FileSystem.exists(destFile)) {
                Files.copyIfNeeded(sourceFile, destFile);
            }
        }

        // Prevent running two things in parallel
        var isRun = false;
        for (i in 0...args.length) {
            if (args[i] == 'run') {
                isRun = true;
                break;
            }
            else if (args[i] == 'clean' || args[i] == 'build') {
                break;
            }
        }
        if (isRun) {
            // Keep a file updated in home directory to let other ceramic scripts detect
            // that a haxe server is running
            var homedir:String = untyped js.Syntax.code("require('os').homedir()");
            var time = '' + Date.now().getTime();
            var hash = Md5.encode(cwd);
            var ceramicRunDir = Path.join([homedir, '.ceramic-run']);
            var ceramicRunFile = Path.join([ceramicRunDir, hash]);
            if (FileSystem.exists(ceramicRunDir)) {
                if (!FileSystem.isDirectory(ceramicRunDir)) {
                    FileSystem.deleteFile(ceramicRunDir);
                }
            }
            else {
                FileSystem.createDirectory(ceramicRunDir);
            }
            File.saveContent(ceramicRunFile, time);
            js.Node.setInterval(function() {
                if (File.getContent(ceramicRunFile) != time) {
                    print('Stop run task (a new one is being run).');
                    Sys.exit(0);
                }
            }, 500);
        }

        // Get and run backend's build task
        context.backend.runBuild(cwd, args, target, context.variant, configIndex);

        // Generate hxml?
        var hxmlOutput = extractArgValue(args, 'hxml-output', true);
        if (hxmlOutput != null) {
            var task = new Hxml();
            task.run(cwd, ['hxml', target.name, '--variant', context.variant, '--output', hxmlOutput]);
        }

        /*// Update vscode settings?
        if (context.vscode) {
            // This will ensure haxe completion server is restarted after a build.
            var task = new Vscode();
            task.run(cwd, ['vscode', target.name, '--variant', context.variant, '--settings-only']);
        }*/

    }

}
