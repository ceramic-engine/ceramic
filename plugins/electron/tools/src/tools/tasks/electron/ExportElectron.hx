package tools.tasks.electron;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class ExportElectron extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate an electron app from the previously exported web project";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var pluginPath = context.plugins.get('electron').path;

        var electronProjectPath = Path.join([cwd, 'project/electron']);
        var electronProjectFilePath = Path.join([electronProjectPath, 'app.js']);
        var electronProjectWebFilesPath = Path.join([electronProjectPath, 'html']);
        var electronProjectPackageJsonPath = Path.join([electronProjectPath, 'package.json']);

        var webProjectFilesPath = Path.join([cwd, 'project/web']);
        var webProjectIndexPath = Path.join([webProjectFilesPath, 'index.html']);

        // Copy electron files if needed
        if (!FileSystem.exists(electronProjectFilePath)) {
            print('Copy electron project files...');
            if (Sys.systemName() == "Linux" || Sys.systemName() == "Mac") {
                if (FileSystem.exists(electronProjectPath))
                    Files.deleteRecursive(electronProjectPath);
                command('cp', ['-Rf', context.ceramicRunnerPath, electronProjectPath], {
                    cwd: cwd
                });
            }
            else {
                Files.copyDirectory(context.ceramicRunnerPath, electronProjectPath, true);
            }

            print('Patch app.js');
            var appJs = File.getContent(electronProjectFilePath);
            appJs = appJs.replace(
                "var argv = process.argv.slice();",
                "var argv = ['--app-files', path.join(__dirname, 'html')];"
            );
            File.saveContent(electronProjectFilePath, appJs);

            print('Configure package.json');
            var packageJson = Json.parse(File.getContent(electronProjectPackageJsonPath));
            Reflect.setField(packageJson, 'build', {
                "appId": project.app.name,
                "productName": project.app.displayName != null ? project.app.displayName : project.app.name,
                "asar": false
            });
            File.saveContent(electronProjectPackageJsonPath, Json.stringify(packageJson, null, '  '));
        }

        if (!FileSystem.exists(webProjectIndexPath)) {
            fail('Web project not found! Did you forget to export your project to web? (e.g. `ceramic clay build web --setup --assets`)');
        }

        // Copy web project files
        if (FileSystem.exists(electronProjectWebFilesPath))
            Files.deleteRecursive(electronProjectWebFilesPath);

        print('Copy web project files...');
        Files.copyDirectory(webProjectFilesPath, electronProjectWebFilesPath);

    }

}
