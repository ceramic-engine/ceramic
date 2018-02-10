package tools;

import tools.Helpers.*;
import tools.Project;
import tools.Files;
import tools.Templates;
import tools.Sync;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;

using StringTools;

class AndroidProject {

    public static function createAndroidProjectIfNeeded(cwd:String, project:Project):Void {
        
        var androidProjectPath = Path.join([cwd, 'project/android']);
        var androidProjectFile = Path.join([androidProjectPath, 'app/build.gradle']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(androidProjectFile)) {

            // Plugin path
            var pluginPath = context.plugins.get('Android').path;

            // Create directory if needed
            if (!FileSystem.exists(androidProjectPath)) {
                FileSystem.createDirectory(androidProjectPath);
            }

            // Copy from template project
            print('Copy from Android project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project/android']),
                androidProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['mycompany.myapp'] = Reflect.field(project.app, 'package').toLowerCase();
            replacementsInNames['mycompany/myapp'] = Reflect.field(project.app, 'package').toLowerCase().replace('.','/');
            replacementsInNames['MyApp'] = project.app.name;
            Templates.replaceInNames(androidProjectPath, replacementsInNames);

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
            Templates.replaceInContents(androidProjectPath, replacementsInContents);
        }

    } //createAndroidProjectIfNeeded

    public static function javaSearchPaths(cwd:String, project:Project, debug:Bool):Array<String> {

        // Get header search paths
        //
        var javaSearchPaths = [];

        var androidProjectPath = Path.join([cwd, 'project/android']);

        // Classes included in project root's java dir
        javaSearchPaths.push(androidProjectPath + '/app/src/main/java');
        // Classes included in project main java package dir
        javaSearchPaths.push(androidProjectPath + '/app/src/main/java/' + Reflect.field(project.app, 'package').toLowerCase().replace('.','/'));

        return javaSearchPaths;

    } //javaSearchPaths

/// Internal

    static function parseXcConfigValue(value:String):Array<String> {

        var result = [];
        var i = 0;
        var len = value.length;
        var inDoubleQuotes = false;
        var word = '';
        var c;

        while (i < len) {

            c = value.charAt(i);

            if (c.trim() == '') {
                if (inDoubleQuotes) {
                    word += c;
                } else if (word.length > 0) {
                    result.push(word);
                    word = '';
                }
            }
            else if (c == '{') {
                word += '(';
            }
            else if (c == '}') {
                word += ')';
            }
            else if (c == '"') {
                inDoubleQuotes = !inDoubleQuotes;
            }
            else {
                word += c;
            }

            i++;
        }

        if (word.length > 0) {
            result.push(word);
        }

        return result;

    } //parseXcConfigValue

} //IosProject
