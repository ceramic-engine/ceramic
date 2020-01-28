package tools;

import tools.Helpers.*;
import tools.Project;
import tools.Files;
import tools.Templates;
import haxe.io.Path;
import sys.FileSystem;

class MacApp {

    public static function createMacAppIfNeeded(cwd:String, project:Project):Void {
        
        var macProjectPath = Path.join([cwd, 'project/mac']);
        var macAppPath = Path.join([macProjectPath, project.app.name + '.app']);
        var macAppInfoFile = Path.join([macAppPath, 'Contents', 'Info.plist']);
        var macAppAssetsPath = Path.join([macAppPath, 'Contents', 'Resources', 'assets']);
        var tmpAppAssetsPath = Path.join([cwd, 'project', 'mac-tmp-assets']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(macAppInfoFile)) {

            // We are expecting assets to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(macAppAssetsPath)) {
                if (FileSystem.exists(tmpAppAssetsPath)) {
                    Files.deleteRecursive(tmpAppAssetsPath);
                }
                FileSystem.rename(macAppAssetsPath, tmpAppAssetsPath);
            }

            // Cleanup before copying
            Files.deleteRecursive(macAppPath);

            // Plugin path
            var pluginPath = context.plugins.get('Mac').path;

            // Create directory if needed
            if (!FileSystem.exists(macProjectPath)) {
                FileSystem.createDirectory(macProjectPath);
            }

            // Copy from template project
            print('Copy from Mac project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project/mac']),
                macProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInNames['MyApp'] = project.app.name;
            replacementsInNames['myapp'] = (''+project.app.name).toLowerCase();
            Templates.replaceInNames(macProjectPath, replacementsInNames);

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
            Templates.replaceInContents(macProjectPath, replacementsInContents);

            // Put assets back
            if (FileSystem.exists(tmpAppAssetsPath)) {
                if (FileSystem.exists(macAppAssetsPath)) {
                    Files.deleteRecursive(macAppAssetsPath);
                }
                FileSystem.rename(tmpAppAssetsPath, macAppAssetsPath);
            }
        }

    }

}
