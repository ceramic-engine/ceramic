package tools.tasks.mac;

import tools.Helpers.*;
import tools.Project;
import tools.Colors;
import tools.Files;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

import js.node.Os;
import js.node.ChildProcess;
import npm.StreamSplitter;

using StringTools;

class Mac extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Mac app to run or debug it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var macProjectPath = Path.join([cwd, 'project/mac']);
        var macAppPath = Path.join([macProjectPath, project.app.name + '.app']);
        var macAppBinaryFile = Path.join([macAppPath, 'Contents', 'MacOS', project.app.name]);

        var doRun = extractArgFlag(args, 'run');

        // Create mac app package if needed
        MacApp.createMacAppIfNeeded(cwd, project);

        // Copy built files and assets
        var outTargetPath = BuildTargetExtensions.outPathWithName('luxe', 'mac', cwd, context.debug, context.variant);

        // Copy binary file
        if (!FileSystem.exists(Path.directory(macAppBinaryFile))) {
            FileSystem.createDirectory(Path.directory(macAppBinaryFile));
        }
        File.copy(Path.join([outTargetPath, 'cpp', context.debug ? 'Main-debug' : 'Main']), macAppBinaryFile);

        // Stop if not running
        if (!doRun) return;

        // Run project through electron/ceramic-runner
        print('Start app');

        var status = commandWithChecksAndLogs(
            project.app.name + '.app/Contents/MacOS/' + project.app.name,
            [],
            { cwd: macProjectPath, logCwd: outTargetPath }
        );

        if (status != 0) {
            js.Node.process.exit(status);
        }

    }

} //Mac