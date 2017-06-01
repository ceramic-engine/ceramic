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
        var force = extractArgFlag(args, 'force');

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
        if (!force && FileSystem.exists(Path.join([projectPath, 'ceramic.yml']))) {
            fail('A project already exist at target path: ' + projectPath + '. Use --force to replace files.');
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
        
        // Save ceramic.yml content
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

        // Save Project.hx content
        //
        content = '
package;

import ceramic.Entity;
import ceramic.Color;
import ceramic.Quad;
import ceramic.Settings;
import ceramic.Assets;

class Project extends Entity {

    function new(settings:InitSettings) {

        settings.antialiasing = true;
        settings.background = Color.GRAY;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FILL;

        app.onceReady(ready);

    } //new

    function ready() {

        // Hello World?
        //

        var quad1 = new Quad();
        quad1.color = Color.RED;
        quad1.depth = 2;
        quad1.size(50, 50);
        quad1.anchor(0.5, 0.5);
        quad1.pos(640 * 0.5, 480 * 0.5);
        quad1.rotation = 30;
        quad1.scale(2.0, 0.5);

        var quad2 = new Quad();
        quad2.depth = 1;
        quad2.color = Color.YELLOW;
        quad2.size(50, 50);
        quad2.anchor(0.5, 0.5);
        quad2.pos(640 * 0.5, 480 * 0.5 + 20);
        quad2.rotation = 30;
        quad2.scale(2.0, 0.5);

        app.onUpdate(this, function(delta) {

            quad1.rotation = (quad1.rotation + delta * 100) % 360;
            quad2.rotation = (quad2.rotation + delta * 100) % 360;

        });

    } //ready

}
'.ltrim();

        var srcPath = Path.join([projectPath, 'src']);
        if (!FileSystem.exists(srcPath)) {
            FileSystem.createDirectory(srcPath);
        }

        File.saveContent(Path.join([srcPath, 'Project.hx']), content);

        success('Project created at path: ' + projectPath);

        // Init backend?
        for (backendName in ['luxe']) {

            if (extractArgFlag(args, backendName)) {

                runCeramic(projectPath, [backendName, 'setup'].concat(force ? ['--force'] : []));

                break;

            }
        }

        // Generate vscode files?
        if (extractArgFlag(args, 'vscode')) {

            var task = new Vscode();
            task.run(projectPath, [args[0], args[1]].concat(force ? ['--force'] : []));

        }

    } //run

} //Init
