package tools;

import tools.Helpers.*;
import tools.Project;
import tools.Files;
import tools.Templates;
import haxe.io.Path;
import sys.FileSystem;

class LinuxApp {

    public static function createLinuxAppIfNeeded(cwd:String, project:Project):Void {
        
        var linuxProjectPath = Path.join([cwd, 'project/linux']);
        var linuxAppPath = Path.join([linuxProjectPath, project.app.name]);
        var linuxAppAssetsPath = Path.join([linuxAppPath, 'assets']);
        var tmpAppAssetsPath = Path.join([cwd, 'project', 'linux-tmp-assets']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(linuxAppPath)) {

            // We are expecting assets to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(linuxAppAssetsPath)) {
                if (FileSystem.exists(tmpAppAssetsPath)) {
                    Files.deleteRecursive(tmpAppAssetsPath);
                }
                FileSystem.rename(linuxAppAssetsPath, tmpAppAssetsPath);
            }

            // Cleanup before copying
            Files.deleteRecursive(linuxAppPath);

            // Plugin path
            var pluginPath = context.plugins.get('Linux').path;

            // Create directory if needed
            if (!FileSystem.exists(linuxProjectPath)) {
                FileSystem.createDirectory(linuxProjectPath);
            }

            // Copy from template project
            print('Copy from Linux project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project/linux']),
                linuxProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInNames['MyApp'] = project.app.name;
            replacementsInNames['myapp'] = (''+project.app.name).toLowerCase();
            Templates.replaceInNames(linuxProjectPath, replacementsInNames);

            // Replace in contents
            print('Perform replaces in contents');
            var replacementsInContents = new Map<String,String>();
            if (project.app.company != null) {
                replacementsInContents['My Company'] = project.app.company;
            }
            else if (project.app.author != null) {
                replacementsInContents['My Company'] = project.app.author;
            }
            replacementsInContents['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInContents['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInContents['MyApp'] = project.app.name;
            replacementsInContents['My App'] = project.app.displayName;
            replacementsInContents['myapp'] = (''+project.app.name).toLowerCase();
            Templates.replaceInContents(linuxProjectPath, replacementsInContents);

            // Put assets back
            if (FileSystem.exists(tmpAppAssetsPath)) {
                if (FileSystem.exists(linuxAppAssetsPath)) {
                    Files.deleteRecursive(linuxAppAssetsPath);
                }
                FileSystem.rename(tmpAppAssetsPath, linuxAppAssetsPath);
            }
        }

    }

}
