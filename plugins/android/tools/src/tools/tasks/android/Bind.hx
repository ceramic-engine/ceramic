package tools.tasks.android;

import tools.Helpers.*;
import tools.Project;
import tools.AndroidProject;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Bind extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate Haxe interface from Java/Android code.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        ensureCeramicProject(cwd, args, App);

        // Get project info
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        var project = new tools.Project();
        project.loadAppFile(projectPath);

        // Create android project if needed
        AndroidProject.createAndroidProjectIfNeeded(cwd, project);

        // Get search paths
        var searchPaths = AndroidProject.javaSearchPaths(cwd, project, context.defines.exists('debug'));

        if (project.app.bind != null) {
            var toBind:Array<String> = project.app.bind;
            for (java in toBind) {
                var javaFound = false;
                for (aPath in searchPaths) {
                    var isAbsolute = Path.isAbsolute(java);
                    var javaPath = isAbsolute ? java : Path.join([aPath, java]);
                    if (javaPath.endsWith('.java') && FileSystem.exists(javaPath) && !FileSystem.isDirectory(javaPath)) {
                        
                        // Run bind library
                        var result = haxelib([
                            'run', 'bind', 'java', '--json', '--pretty',
                            javaPath,
                            '--namespace', 'ceramic::android',
                            '--package', 'android'
                        ], {
                            cwd: cwd,
                            mute: true
                        });

                        // Did it work?
                        if (result.status != 0) {
                            fail(((result.stderr + '').trim() != '' ? result.stderr : result.stdout).trim());
                        }

                        // Yes! Save files.
                        //
                        var projectGenPath = Path.join([cwd, 'gen']);
                        var allInfo:Array<{path:String,content:String}> = [];

                        try {
                            allInfo = Json.parse(''+result.stdout);
                        } catch (e:Dynamic) {
                            fail('Failed to parse bind output: ' + e);
                        }

                        for (fileInfo in allInfo) {

                            var filePath = Path.join([projectGenPath, fileInfo.path]);
                            if (fileInfo.path.startsWith('java/')) {
                                filePath = Path.join([cwd, 'project/android/app/src/bind', fileInfo.path]);
                            }

                            success('export $filePath');

                            if (FileSystem.exists(filePath)) {
                                // Only save if content is different
                                var previous = File.getContent(filePath);
                                if (fileInfo.content != previous) {
                                    File.saveContent(filePath, fileInfo.content);
                                }
                            } else {
                                // Create intermediate directories if needed
                                var dirPath = Path.directory(filePath);
                                if (!FileSystem.exists(dirPath)) {
                                    FileSystem.createDirectory(dirPath);
                                }
                                
                                File.saveContent(filePath, fileInfo.content);
                            }

                        }

                        javaFound = true;
                        break;
                    }

                    if (isAbsolute) break;
                }

                if (!javaFound) {
                    warning('Failed to resolve java file: ' + java);
                }
            }
        }

    }

}
