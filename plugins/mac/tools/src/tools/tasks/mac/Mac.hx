package tools.tasks.mac;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Colors;
import tools.Files;
import tools.Helpers.*;
import tools.Project;

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
        var outTargetPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'mac', cwd, context.debug, context.variant);

        // Copy binary file
        if (!FileSystem.exists(Path.directory(macAppBinaryFile))) {
            FileSystem.createDirectory(Path.directory(macAppBinaryFile));
        }
        File.copy(Path.join([outTargetPath, 'cpp', context.debug ? 'Main-debug' : 'Main']), macAppBinaryFile);

        // Ensure it's still executable
        command('chmod', ['+x', macAppBinaryFile]);

        // Stop if not running
        if (!doRun) return;

        // Run project
        print('Start app');

        var status = commandWithChecksAndLogs(
            project.app.name + '.app/Contents/MacOS/' + project.app.name,
            [],
            { cwd: macProjectPath, logCwd: outTargetPath, filter: (line:String) -> {
                return line.indexOf('UNSUPPORTED (log once): POSSIBLE ISSUE: unit') != -1 && line.indexOf('GLD_TEXTURE_INDEX_2D is unloadable and bound to sampler type (Float)') != -1;
            } }
        );

        if (status != 0) {
            Sys.exit(status);
        }

    }

} //Mac