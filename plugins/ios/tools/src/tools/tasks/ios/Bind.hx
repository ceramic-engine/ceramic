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

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var projectKind = getProjectKind(cwd, args);
        var isAppProject = (projectKind == App);
        ensureCeramicProject(cwd, args, projectKind);

        // Get project info
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        var project = new tools.Project();
        if (isAppProject) {
            project.loadAppFile(projectPath);
        } else {
            project.loadPluginFile(projectPath);
        }

        // Create ios project if needed
        if (isAppProject) {
            IosProject.createIosProjectIfNeeded(cwd, project);
        }

        // Get search paths
        var searchPaths = IosProject.headerSearchPaths(cwd, project, context.defines.exists('debug'));

        if ((isAppProject && project.app.bind != null) || (!isAppProject && project.plugin.bind != null)) {
            var toBind:Array<String> = isAppProject ? project.app.bind : project.plugin.bind;
            for (header in toBind) {
                var headerFound = false;
                for (aPath in searchPaths) {
                    var isAbsolute = Path.isAbsolute(header);
                    var headerPath = isAbsolute ? header : Path.join([aPath, header]);
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
                        var projectSrcPath = isAppProject ? Path.join([cwd, 'src']) : Path.join([cwd, 'runtime/src']);
                        var allInfo:Array<{path:String,content:String}> = [];

                        try {
                            allInfo = Json.parse(''+result.stdout);
                        } catch (e:Dynamic) {
                            if (result != null) warning('Invalid JSON for header $headerPath: ' + result.stdout);
                            warning('Failed to parse bind output: ' + e);
                            allInfo = [];
                        }

                        for (fileInfo in allInfo) {

                            var filePath = Path.join([projectSrcPath, fileInfo.path]);

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

                        headerFound = true;
                        break;
                    }

                    if (isAbsolute) break;
                }

                if (!headerFound) {
                    warning('Failed to resolve header: ' + header);
                }
            }
        }

    }

}
