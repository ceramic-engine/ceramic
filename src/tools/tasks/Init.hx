package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;

using StringTools;

class Init extends tools.Task {

    override public function info(cwd:String):String {

        return "Initialize a new ceramic project.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var projectPath = cwd;

        // Extract project name
        //
        var index = args.indexOf('--name');
        if (index == -1) {
            fail('Project name (--name MyProject) is required.');
        }
        if (index + 1 >= args.length) {
            fail('A value is required after --name argument.');
        }
        var projectName = args[args.indexOf('--name') + 1];
        projectPath = Path.join([projectPath, projectName]);

        // Extract project path
        //
        index = args.indexOf('--path');
        var newProjectPath = projectPath;
        if (index != -1) {
            if (index + 1 >= args.length) {
                fail('A value is required after --path argument.');
            }
            newProjectPath = args[args.indexOf('--path') + 1];
        }
        if (!Path.isAbsolute(newProjectPath)) {
            newProjectPath = Path.normalize(Path.join([cwd, newProjectPath]));
        }
        projectPath = newProjectPath;

        // Ensure target directory (not necessarily current) is not a project
        if (FileSystem.exists(Path.join([projectPath, 'ceramic.yml']))) {
            fail('A project already exist at target path: ' + projectPath);
        }

        if (!FileSystem.exists(projectPath)) {
            try {
                FileSystem.createDirectory(projectPath);
            } catch (e:Dynamic) {
                fail('Error when creating project directory: ' + e);
            }
        }
        if (!FileSystem.isDirectory(projectPath)) {
            fail('Project path is not a directory at: $projectPath');
        }
        
        // Save content
        //
        var content = '
app:
    package: mycompany.$projectName
    name: $projectName
    displayName: $projectName
    author: My Company
    version: \'1.0\'

    libs: []
'.ltrim();

        File.saveContent(Path.join([projectPath, 'ceramic.yml']), content);

        success('Project created at path: ' + projectPath);

    } //run

} //Init
