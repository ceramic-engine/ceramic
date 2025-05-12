package tools;

import haxe.SysTools;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;
import tools.Project;
import tools.Templates;

using StringTools;

class IosProject {

    public static function createIosProjectIfNeeded(cwd:String, project:Project):Void {

        var iosProjectName = project.app.name;
        var iosProjectPath = Path.join([cwd, 'project', 'ios']);
        var iosProjectFile = Path.join([iosProjectPath, iosProjectName + '.xcodeproj']);
        var iosProjectAssetsPath = Path.join([iosProjectPath, 'project', 'assets', 'assets']);
        var tmpProjectAssetsPath = Path.join([cwd, 'project', 'ios-tmp-assets']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(iosProjectFile)) {

            // We are expecting assets to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(iosProjectAssetsPath)) {
                if (FileSystem.exists(tmpProjectAssetsPath)) {
                    Files.deleteRecursive(tmpProjectAssetsPath);
                }
                FileSystem.rename(iosProjectAssetsPath, tmpProjectAssetsPath);
            }

            // Plugin path
            var pluginPath = context.plugins.get('ios').path;

            // Create directory if needed
            if (!FileSystem.exists(iosProjectPath)) {
                FileSystem.createDirectory(iosProjectPath);
            }

            // Copy from template project
            var backendName:String = 'clay'; // Default to clay
            if (context.backend != null) {
                // In some cases (when called from bind hook),
                // backend info is not provided, but when it is, use that.
                // TODO: pass-on backend info for every case?
                backendName = context.backend.name;
            }
            else {
                // A bit hacky, but didn't have a better idea for now
                if (FileSystem.exists(Path.join([cwd, 'out/clay']))) {
                    backendName = 'clay';
                }
                else if (FileSystem.exists(Path.join([cwd, 'out/luxe']))) {
                    // Just to keep compatibility with legacy projects
                    backendName = 'luxe';
                }
            }
            var templateName = 'ios-' + backendName;
            print('Copy from Xcode project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project', templateName]),
                iosProjectPath
            );

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = Reflect.field(project.app, 'package');
            replacementsInNames['MyApp'] = project.app.name;
            Templates.replaceInNames(iosProjectPath, replacementsInNames);

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
            Templates.replaceInContents(iosProjectPath, replacementsInContents);

            // Put assets back
            if (FileSystem.exists(tmpProjectAssetsPath)) {
                if (FileSystem.exists(iosProjectAssetsPath)) {
                    Files.deleteRecursive(iosProjectAssetsPath);
                }
                FileSystem.rename(tmpProjectAssetsPath, iosProjectAssetsPath);
            }

            // Remove directories that have become empty after replace
            Files.removeEmptyDirectories(iosProjectPath);

            // Make build-haxe.sh executable
            if (FileSystem.exists(Path.join([iosProjectPath, 'build-haxe.sh']))) {
                command('chmod', ['+x', Path.join([iosProjectPath, 'build-haxe.sh'])]);
            }
        }

    }

    public static function headerSearchPaths(cwd:String, project:Project, debug:Bool):Array<String> {

        // Get header search paths
        //
        var headerSearchPaths = [];

        // Project headers
        //
        var iosProjectPath = Path.join([cwd, 'project/ios']);

        // Classes included in project root's Classes dir
        headerSearchPaths.push(iosProjectPath + '/project/Classes');
        // Headers included in project root dir
        headerSearchPaths.push(iosProjectPath);
        // Headers included in ceramic project root dir as well
        headerSearchPaths.push(cwd);

        return headerSearchPaths;

    }

    static function pods(cwd:String, project:Project):Array<String> {

        var pods = [];

        var podFilePath = Path.join([cwd, 'project/ios/project/Podfile']);
        if (FileSystem.exists(podFilePath)) {

            var content = File.getContent(podFilePath);
            for (line in content.split("\n")) {
                if (line.trim().startsWith('pod ')) {
                    line = line.ltrim().substr(4).ltrim();
                    var quot = line.charAt(0);
                    line = line.substr(1);
                    var podName = '';
                    while (line.charAt(0) != quot) {
                        podName += line.charAt(0);
                        line = line.substr(1);
                    }
                    pods.push(podName);
                }
            }

        }

        return pods;

    }

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

    }

}
