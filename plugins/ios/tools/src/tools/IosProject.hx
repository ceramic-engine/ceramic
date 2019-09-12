package tools;

import tools.Helpers.*;
import tools.Project;
import tools.Templates;
import tools.Sync;
import tools.Files;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;

import js.node.ChildProcess;

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
            var pluginPath = context.plugins.get('iOS').path;

            // Create directory if needed
            if (!FileSystem.exists(iosProjectPath)) {
                FileSystem.createDirectory(iosProjectPath);
            }

            // Copy from template project
            print('Copy from Xcode project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project/ios']),
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
        }

    } //createIosProjectIfNeeded

    public static function updateBuildNumber(cwd:String, project:Project) {

        var iosProjectName = project.app.name;
        var iosProjectPath = Path.join([cwd, 'project/ios']);
        var iosProjectInfoPlistFile = Path.join([iosProjectPath, 'project/project-Info.plist']);

        if (!FileSystem.exists(iosProjectInfoPlistFile)) {
            warning('Cannot update build number because info plist file doesn\'t exist at path: $iosProjectInfoPlistFile');
        }
        else {
            // Compute target build number from current time
            var targetBuildNumber = Std.parseInt(DateTools.format(Date.now(), '%Y%m%d%H%M').substr(2));
            // Extract current build number
            var currentBuildNumber = Std.parseInt(('' + ChildProcess.execSync("/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' " + iosProjectInfoPlistFile.quoteUnixArg())).trim());
            // Increment if needed
            if (currentBuildNumber == targetBuildNumber) {
                targetBuildNumber++;
            }
            print('Update build number to $targetBuildNumber');
            // Saved updated build number
            ChildProcess.execSync("/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion " + targetBuildNumber + "' " + iosProjectInfoPlistFile.quoteUnixArg());
        }

    } //updateBuildNumber

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

    } //headerSearchPaths

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

    } //pods

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
