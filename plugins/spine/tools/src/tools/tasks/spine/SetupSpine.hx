package tools.tasks.spine;

import tools.Helpers.*;
import tools.Project;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class SetupSpine extends tools.Task {

    override public function info(cwd:String):String {

        return "Setup project to work with spine";

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);
        
        // Check generated files
        var generatedTplPath = Path.join([context.plugins.get('Spine').path, 'generated']);
        var generatedFiles = Files.getFlatDirectory(generatedTplPath);
        var projectGenPath = Path.join([context.cwd, 'gen']);
        for (file in generatedFiles) {
            var sourceFile = Path.join([generatedTplPath, file]);
            var destFile = Path.join([projectGenPath, file]);
            if (!FileSystem.exists(destFile)) {
                Files.copyIfNeeded(sourceFile, destFile);
            }
        }

    }

}
