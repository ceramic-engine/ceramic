package tools.tasks.ios;

import tools.Helpers.*;
import tools.Project;
import tools.IosProject;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Bind extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate Haxe interface from native Objective-C code.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        ensureCeramicProject(cwd, args, App);

        // Get project info
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        var project = new tools.Project();
        project.loadAppFile(projectPath);

        // Create ios project if needed
        IosProject.createIosProjectIfNeeded(cwd, project);

        // Get search paths
        var searchPaths = IosProject.headerSearchPaths(cwd, project, context.defines.exists('debug'));

        if (project.app.bind != null) {
            var toBind:Array<String> = project.app.bind;
            for (header in toBind) {
                for (aPath in searchPaths) {
                    var headerPath = Path.join([aPath, header]);
                    if (headerPath.endsWith('.h') && FileSystem.exists(headerPath) && !FileSystem.isDirectory(headerPath)) {
                        
                        // Run bind library
                        var result = haxelib([
                            'run', 'bind', 'objc', '--json', '--pretty',
                            headerPath,
                            '--namespace', 'ceramic::ios',
                            '--package', 'ios'
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
                        var projectSrcPath = Path.join([cwd, 'src']);
                        var allInfo:Array<{path:String,content:String}> = [];

                        try {
                            allInfo = Json.parse(''+result.stdout);
                        } catch (e:Dynamic) {
                            fail('Failed to parse bind output: ' + e);
                        }

                        for (fileInfo in allInfo) {

                            var filePath = Path.join([projectSrcPath, fileInfo.path]);

                            success('export $filePath');

                            if (!FileSystem.exists(Path.directory(filePath))) {
                                FileSystem.createDirectory(Path.directory(filePath));
                            }

                            File.saveContent(filePath, fileInfo.content);

                        }

                        break;
                    }
                }
            }
        }

    } //run

} //Bind
