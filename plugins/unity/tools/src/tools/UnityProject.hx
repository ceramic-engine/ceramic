package tools;

import tools.Helpers.*;
import tools.Project;

import sys.FileSystem;

import haxe.io.Path;

class UnityProject {

    public static function resolveUnityProjectPath(cwd:String, project:Project) {

        var projectName = 'MyApp';

        if (project != null && project.app != null && project.app.name != null) {
            projectName = project.app.name;
        }

        var unityProjectPath = Path.join([cwd, 'project', 'unity', projectName]);

        if (project != null
        && project.app != null
        && project.app.unity != null
        && project.app.unity.project != null) {
            // Allow to point to unity assets directly
            var customUnityProjectPath:String = project.app.unity.project;
            if (!Path.isAbsolute(customUnityProjectPath)) {
                customUnityProjectPath = Path.join([cwd, customUnityProjectPath]);
            }
            unityProjectPath = customUnityProjectPath;
        }

        return unityProjectPath;

    }

    public static function createUnityProjectIfNeeded(cwd:String, project:Project):Void {
        
        var unityProjectName = project.app.name;
        var unityProjectPath = resolveUnityProjectPath(cwd, project);
        var unityProjectScenesPath = Path.join([unityProjectPath, 'Assets', 'Scenes']);
        var unityProjectAssetsPath = Path.join([unityProjectPath, 'Assets', 'Ceramic', 'Resources', 'assets']);
        var tmpProjectAssetsPath = Path.join([cwd, 'project', 'unity-tmp-assets']);

        // Copy template project (only if not existing already)
        // (We assume that project is not there is Scenes directory is not present in assets)
        if (!FileSystem.exists(unityProjectScenesPath)) {

            // We are expecting assets to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(unityProjectAssetsPath)) {
                if (FileSystem.exists(tmpProjectAssetsPath)) {
                    Files.deleteRecursive(tmpProjectAssetsPath);
                }
                FileSystem.rename(unityProjectAssetsPath, tmpProjectAssetsPath);
            }

            // Plugin path
            var pluginPath = context.plugins.get('Unity').path;

            // Create directory if needed
            if (!FileSystem.exists(unityProjectPath)) {
                FileSystem.createDirectory(unityProjectPath);
            }

            // Copy from template project
            print('Copy from Unity project template');
            var projectTemplateName = 'standard';
            if (context.defines.exists('unity_urp')) {
                projectTemplateName = 'urp';
            }
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project/$projectTemplateName']),
                unityProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['MyApp'] = project.app.name;
            Templates.replaceInNames(unityProjectPath, replacementsInNames);

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
            replacementsInContents['MyApp'] = project.app.name;
            replacementsInContents['My App'] = project.app.displayName;
            Templates.replaceInContents(unityProjectPath, replacementsInContents);

            // Put assets back
            if (FileSystem.exists(tmpProjectAssetsPath)) {
                if (FileSystem.exists(unityProjectAssetsPath)) {
                    Files.deleteRecursive(unityProjectAssetsPath);
                }
                FileSystem.rename(tmpProjectAssetsPath, unityProjectAssetsPath);
            }
        }

    }

}
