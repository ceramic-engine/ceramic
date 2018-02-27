package tools;

import tools.Helpers.*;
import tools.Project;
import tools.Files;
import tools.Templates;
import haxe.io.Path;
import sys.FileSystem;

class WebProject {

    public static function createWebProjectIfNeeded(cwd:String, project:Project):Void {
        
        var webProjectPath = Path.join([cwd, 'project/web']);
        var webProjectFile = Path.join([webProjectPath, 'index.html']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(webProjectFile)) {

            // Plugin path
            var pluginPath = context.plugins.get('Web').path;

            // Create directory if needed
            if (!FileSystem.exists(webProjectPath)) {
                FileSystem.createDirectory(webProjectPath);
            }

            // Copy from template project
            print('Copy from Web project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project/web']),
                webProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInNames['MyApp'] = project.app.name;
            replacementsInNames['myapp'] = (''+project.app.name).toLowerCase();
            Templates.replaceInNames(webProjectPath, replacementsInNames);

            // Replace in contents
            print('Perform replaces in contents');
            var replacementsInContents = new Map<String,String>();
            if (project.app.company != null) {
                replacementsInContents['My Company'] = project.app.company;
            }
            replacementsInContents['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInContents['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInContents['MyApp'] = project.app.name;
            replacementsInContents['My App'] = project.app.displayName;
            replacementsInContents['myapp'] = (''+project.app.name).toLowerCase();
            Templates.replaceInContents(webProjectPath, replacementsInContents);
        }

    } //createWebProjectIfNeeded

} //WebProject
