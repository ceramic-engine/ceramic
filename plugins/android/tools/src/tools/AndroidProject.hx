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
        var androidProjectAssetsPath = Path.join([androidProjectPath, 'app', 'src', 'main', 'assets', 'assets']);
        var tmpProjectAssetsPath = Path.join([cwd, 'project', 'android-tmp-assets']);

        // Copy template project (only if not existing already)
        if (!FileSystem.exists(androidProjectFile)) {

            // We are expecting assets to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(androidProjectAssetsPath)) {
                if (FileSystem.exists(tmpProjectAssetsPath)) {
                    Files.deleteRecursive(tmpProjectAssetsPath);
                }
                FileSystem.rename(androidProjectAssetsPath, tmpProjectAssetsPath);
            }

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

            // Put assets back
            if (FileSystem.exists(tmpProjectAssetsPath)) {
                if (FileSystem.exists(androidProjectAssetsPath)) {
                    Files.deleteRecursive(androidProjectAssetsPath);
                }
                FileSystem.rename(tmpProjectAssetsPath, androidProjectAssetsPath);
            }
        }

    }

    public static function updateBuildNumber(cwd:String, project:Project) {

        var androidProjectName = project.app.name;
        var androidProjectPath = Path.join([cwd, 'project/android']);
        var androidManifestFile = Path.join([androidProjectPath, 'app/src/main/AndroidManifest.xml']);

        if (!FileSystem.exists(androidManifestFile)) {
            warning('Cannot update build number because app\'s AndroidManifest file doesn\'t exist at path: $androidManifestFile');
        }
        else {
            // Compute target build number from current time
            var targetBuildNumber = Std.parseInt(DateTools.format(Date.now(), '%Y%m%d%H%M').substr(2));
            // Extract current build number
            var manifestContent = File.getContent(androidManifestFile);
            var re = ~/android:versionCode="([^"]+)"/;
            if (!re.match(manifestContent)) {
                fail('Failed to extract current build number from AndroidManifest.xml');
            }
            var currentBuildNumber = Std.parseInt(re.matched(1).trim());
            // Increment if needed
            if (currentBuildNumber == targetBuildNumber) {
                targetBuildNumber++;
            }
            print('Update build number to $targetBuildNumber');
            // Saved updated build number
            manifestContent = manifestContent.replace(re.matched(0), 'android:versionCode="$targetBuildNumber"');
            File.saveContent(androidManifestFile, manifestContent);
        }

    }

    public static function copyMainBinariesIfNeeded(cwd:String, project:Project) {

        var srcJni = Path.join([context.cwd, 'out/luxe/android/cpp']);
        var dstJni = Path.join([context.cwd, 'project/android/app/src/main/jniLibs']);
        var jniLibName = 'lib' + project.app.name + '.so';
        var libPrefix = context.debug ? 'libMain-debug' : 'libMain';
        var builtFile:String;
        var targetFile:String;

        builtFile = Path.join([srcJni, '$libPrefix-v7.so']);
        targetFile = Path.join([dstJni, 'armeabi-v7a/$jniLibName']);
        Files.copyIfNeeded(builtFile, targetFile);

        builtFile = Path.join([srcJni, '$libPrefix-64.so']);
        targetFile = Path.join([dstJni, 'arm64-v8a/$jniLibName']);
        Files.copyIfNeeded(builtFile, targetFile);

        builtFile = Path.join([srcJni, '$libPrefix-x86.so']);
        if (FileSystem.exists(builtFile)) {
            targetFile = Path.join([dstJni, 'x86/$jniLibName']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

        // TODO x86_64

    }

    public static function copyOpenALBinariesIfNeeded(cwd:String, project:Project) {

        // Copy OpenAL binaries if they have changed or weren't copied before

        var builtFile:String;
        var targetFile:String;

        builtFile = Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/libopenal-v7.so']);
        targetFile = Path.join([context.cwd, 'project/android/app/src/main/jniLibs/armeabi-v7a/libopenal.so']);
        Files.copyIfNeeded(builtFile, targetFile);

        builtFile = Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/libopenal-64.so']);
        targetFile = Path.join([context.cwd, 'project/android/app/src/main/jniLibs/arm64-v8a/libopenal.so']);
        Files.copyIfNeeded(builtFile, targetFile);

        builtFile = Path.join([context.ceramicGitDepsPath, 'linc_openal/lib/openal-android/lib/Android/libopenal-x86.so']);
        if (FileSystem.exists(builtFile)) {
            targetFile = Path.join([context.cwd, 'project/android/app/src/main/jniLibs/x86/libopenal.so']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

        // TODO x86_64

    }

    public static function copyJavaFilesIfNeeded(cwd:String, project:Project):Void {

        var androidProjectPath = Path.join([cwd, 'project/android']);

        if (project.app.java != null) {
            var javaFiles:Array<String> = project.app.java;
            for (javaFile in javaFiles) {
                var java = File.getContent(javaFile);
                var pack = findJavaPackage(java);
                if (pack == null) {
                    warning('Failed to retrieve package of java file: ' + javaFile);
                }
                else {
                    var targetDir = Path.join([androidProjectPath, 'app/src/bind/java', pack.replace('.', '/')]);
                    var targetFile = Path.join([targetDir, Path.withoutDirectory(javaFile)]);
                    if (!FileSystem.exists(targetDir)) {
                        FileSystem.createDirectory(targetDir);
                    }
                    print('Copy ' + Path.join([pack.replace('.', '/'), Path.withoutDirectory(javaFile)]));
                    File.saveContent(targetFile, java);
                }
            }
        }

    }

    public static function findJavaPackage(java:String):String {

        java = getCodeWithEmptyCommentsAndStrings(java);

        var i = 0;
        while (i < java.length) {
            var sub = java.substring(i);
            if (sub.startsWith('package')) {
                sub = sub.substring('package'.length);
                var pack = '';
                var j = 0;
                while (sub.charAt(j) != ';') {
                    pack += sub.charAt(j);
                    j++;
                }
                return pack.replace(' ', '').trim();
            }
            i++;
        }

        return null;

    }

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

    }

    static function getCodeWithEmptyCommentsAndStrings(input:String):String {

        var i = 0;
        var output = '';
        var len = input.length;
        var inSingleLineComment = false;
        var inMultilineComment = false;
        var c, cc;

        while (i < len) {

            c = input.charAt(i);
            cc = input.substr(i, 2);

            if (inSingleLineComment) {
                if (c == "\n") {
                    inSingleLineComment = false;
                    output += "\n";
                }
                else {
                    output += ' ';
                }
                i++;
            }
            else if (inMultilineComment) {
                if (cc == '*/') {
                    inMultilineComment = false;
                    output += '  ';
                    i += 2;
                }
                else {
                    if (c == "\n") {
                        output += "\n";
                    }
                    else {
                        output += ' ';
                    }
                    i++;
                }
            }
            else if (cc == '//') {
                inSingleLineComment = true;
                output += '  ';
                i += 2;
            }
            else if (cc == '/*') {
                inMultilineComment = true;
                output += '  ';
                i += 2;
            }
            else if ((c == '"' || c == '\'') && RE_STRING.match(input.substring(i))) {
                var len = RE_STRING.matched(0).length - 2;
                output += c;
                while (len-- > 0) {
                    output += ' ';
                }
                output += c;
                i += RE_STRING.matched(0).length;
            }
            else {
                output += c;
                i++;
            }
        }

        return output;

    }

    static var RE_STRING = ~/^(?:"(?:[^"\\]*(?:\\.[^"\\]*)*)"|'(?:[^'\\]*(?:\\.[^'\\]*)*)')/;

}
