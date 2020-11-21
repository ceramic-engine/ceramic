package tools.tasks.unity;

import tools.Files;
import tools.Helpers.*;
import tools.UnityProject;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Project extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Unity project to build or run it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add unity flag
        if (!context.defines.exists('unity')) {
            context.defines.set('unity', '');
        }

        var debug = context.debug;
        var variant = context.variant;
        var project = ensureCeramicProject(cwd, args, App);
        var outTargetPath = BuildTargetExtensions.outPathWithName('unity', 'unity', cwd, debug, variant);
        var unityProjectPath = UnityProject.resolveUnityProjectPath(cwd, project);

        // Create unity project if needed
        UnityProject.createUnityProjectIfNeeded(cwd, project);

        print('Copy Main.dll');

        // Copy dll
        var srcDllPath = Path.join([outTargetPath, 'bin', 'bin', 'Main.dll']);
        var dstDllPath = Path.join([unityProjectPath, 'Assets', 'Main.dll']);
        Files.copyIfNeeded(srcDllPath, dstDllPath);

    }

}
