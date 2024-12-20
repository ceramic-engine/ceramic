package tools.tasks.unity;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;
import tools.UnityProject;

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

        /*
        print('Copy Main.dll');

        // Copy dll
        var srcDllPath = Path.join([outTargetPath, 'bin', 'bin', 'Main.dll']);
        var dstDllPath = Path.join([unityProjectPath, 'Assets', 'Main.dll']);
        Files.copyIfNeeded(srcDllPath, dstDllPath);
        */
        print('Export script files...');
        UnityCSharp.exportScriptFilesToProject(cwd, project);

        var run = extractArgFlag(args, 'run');

        if (run) {
            var os = Sys.systemName();

            var projectPath = UnityProject.resolveUnityProjectPath(cwd, project);
            var processDir = Path.join([projectPath, 'Temp', 'ProcessJobs']);
            if (FileSystem.exists(processDir)) {

                if (os == 'Mac') {

                    print('Open project with Unity Editor...');

                    command('bash', [
                        Path.join([context.plugins.get('unity').path, 'resources/open-unity-mac.sh']),
                        '-p',
                        unityProjectPath
                    ]);

                }
                else if (os == 'Windows') {

                    // Just trying windows, not sure it works

                    print('Open project with Unity Editor...');

                    var unityEditorPath = UnityEditor.resolveUnityEditorPath(cwd, project);

                    var cmd = Path.join([unityEditorPath, 'Unity.exe']);
                    var ceramicScenePath = Path.join([projectPath, 'Assets/Scenes/CeramicScene.unity']);

                    command(cmd, ['-openfile', ceramicScenePath], { detached: true });

                }

            }
            else {

                if (os == 'Mac') {

                    print('Open project with Unity Editor...');

                    var unityEditorPath = UnityEditor.resolveUnityEditorPath(cwd, project);

                    var cmd = Path.join([unityEditorPath, 'Contents/MacOS/Unity']);
                    var ceramicScenePath = Path.join([projectPath, 'Assets/Scenes/CeramicScene.unity']);

                    command(cmd, ['-openfile', ceramicScenePath], { detached: true });
                }
                else if (os == 'Windows') {

                    // Just trying windows, not sure it works

                    print('Open project with Unity Editor...');

                    var unityEditorPath = UnityEditor.resolveUnityEditorPath(cwd, project);

                    var cmd = Path.join([unityEditorPath, 'Unity.exe']);
                    var ceramicScenePath = Path.join([projectPath, 'Assets/Scenes/CeramicScene.unity']);

                    command(cmd, ['-openfile', ceramicScenePath], { detached: true });

                }
            }

        }

    }

}
