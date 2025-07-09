package tools;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;
import tools.Project;
import tools.Templates;

using StringTools;

class AndroidProject {

    public static function createAndroidProjectIfNeeded(cwd:String, project:Project):Void {

        var androidProjectPath = Path.join([cwd, 'project/android']);
        var androidProjectFile = Path.join([androidProjectPath, 'app/build.gradle']);

        var androidProjectAssetsPath = Path.join([androidProjectPath, 'app', 'src', 'main', 'assets', 'assets']);
        var tmpProjectAssetsPath = Path.join([cwd, 'project', 'android-tmp-assets']);

        var androidProjectResPath = Path.join([androidProjectPath, 'app', 'src', 'main', 'res']);
        var tmpProjectResPath = Path.join([cwd, 'project', 'android-tmp-res']);

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

            // We are also expecting icons to be in destination directory already.
            // Move them to a temporary place, process template files,
            // then put them back where they were.
            if (FileSystem.exists(androidProjectResPath)) {
                if (FileSystem.exists(tmpProjectResPath)) {
                    Files.deleteRecursive(tmpProjectResPath);
                }
                FileSystem.rename(androidProjectResPath, tmpProjectResPath);
            }

            // Plugin path
            var pluginPath = context.plugins.get('android').path;

            // Create directory if needed
            if (!FileSystem.exists(androidProjectPath)) {
                FileSystem.createDirectory(androidProjectPath);
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
            var templateName = 'android-' + backendName;
            print('Copy from Android project template');
            Files.copyDirectory(
                Path.join([pluginPath, 'tpl/project', templateName]),
                androidProjectPath
            );

            var packageName:String = Reflect.field(project.app, 'package');
            packageName = packageName.replace('-', '');

            // Replace in names
            print('Perform replaces in names');
            var replacementsInNames = new Map<String,String>();
            replacementsInNames['mycompany.MyApp'] = packageName;
            replacementsInNames['mycompany.myapp'] = packageName.toLowerCase();
            replacementsInNames['mycompany/myapp'] = packageName.toLowerCase().replace('.','/');
            replacementsInNames['MyApp'] = project.app.name;
            Templates.replaceInNames(androidProjectPath, replacementsInNames);

            // Replace in contents
            print('Perform replaces in contents');
            var replacementsInContents = new Map<String,String>();
            if (project.app.company != null) {
                replacementsInContents['My Company'] = project.app.company;
            }
            else if (project.app.author != null) {
                replacementsInContents['My Company'] = project.app.author;
            }
            replacementsInContents['mycompany.MyApp'] = packageName;
            replacementsInContents['mycompany.myapp'] = packageName.toLowerCase();
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

            // Put icons back
            if (FileSystem.exists(tmpProjectResPath)) {
                for (relPath in Files.getFlatDirectory(tmpProjectResPath)) {
                    final filePath = Path.join([tmpProjectResPath, relPath]);
                    if (!FileSystem.isDirectory(filePath)) {
                        File.copy(
                            filePath,
                            Path.join([androidProjectResPath, relPath])
                        );
                    }
                }
                Files.deleteRecursive(tmpProjectResPath);
            }

            // Remove directories that have become empty after replace
            Files.removeEmptyDirectories(androidProjectPath);
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
            var rawBuildNumber = DateTools.format(Date.now(), '%Y%m%d%H');
            var targetBuildNumber = Std.parseInt(rawBuildNumber);
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

    public static function copyMainBinariesIfNeeded(cwd:String, project:Project, archs:Array<String>) {

        var debug = context.debug;
        var variant = context.variant;
        var libPrefix = context.debug ? 'libMain-debug' : 'libMain';
        var builtOutPath = BuildTargetExtensions.outPathWithName(context.backend.name, 'android', cwd, debug, variant);
        var srcJni = Path.join([builtOutPath, 'cpp']);
        var dstJni = Path.join([context.cwd, 'project/android/app/src/main/jniLibs']);
        var jniLibName = 'lib' + project.app.name + '.so';
        var builtFile:String;
        var targetFile:String;

        if (archs.contains('armv7')) {
            builtFile = Path.join([srcJni, '$libPrefix-v7.so']);
            targetFile = Path.join([dstJni, 'armeabi-v7a/$jniLibName']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

        if (archs.contains('arm64')) {
            builtFile = Path.join([srcJni, '$libPrefix-64.so']);
            targetFile = Path.join([dstJni, 'arm64-v8a/$jniLibName']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

        if (archs.contains('x86')) {
            builtFile = Path.join([srcJni, '$libPrefix-x86.so']);
            targetFile = Path.join([dstJni, 'x86/$jniLibName']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

        if (archs.contains('x86_64')) {
            builtFile = Path.join([srcJni, '$libPrefix-x86_64.so']);
            targetFile = Path.join([dstJni, 'x86_64/$jniLibName']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

    }

    public static function copySharedLibCppBinariesIfNeeded(cwd:String, project:Project, archs:Array<String>) {

        // Copy shared lib c++ binaries if they have changed or weren't copied before

        var builtFile:String;
        var targetFile:String;

        var androidLibsPath = Path.join([context.plugins.get('android').path, 'resources', 'libs']);

        if (archs.contains('armv7')) {
            builtFile = Path.join([androidLibsPath, 'armeabi-v7a/libc++_shared.so']);
            targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/armeabi-v7a/libc++_shared.so']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

        if (archs.contains('arm64')) {
            builtFile = Path.join([androidLibsPath, 'arm64-v8a/libc++_shared.so']);
            targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/arm64-v8a/libc++_shared.so']);
            Files.copyIfNeeded(builtFile, targetFile);
        }

        if (archs.contains('x86')) {
            builtFile = Path.join([androidLibsPath, 'x86/libc++_shared.so']);
            if (FileSystem.exists(builtFile)) {
                targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/x86/libc++_shared.so']);
                Files.copyIfNeeded(builtFile, targetFile);
            }
        }

        if (archs.contains('x86_64')) {
            builtFile = Path.join([androidLibsPath, 'x86_64/libc++_shared.so']);
            if (FileSystem.exists(builtFile)) {
                targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/x86_64/libc++_shared.so']);
                Files.copyIfNeeded(builtFile, targetFile);
            }
        }

    }

    public static function removeSharedLibCppBinariesIfNeeded(cwd:String, project:Project, archs:Array<String>) {

        // Remove shared lib c++ binaries if they were copied before

        var targetFile:String;

        if (archs.contains('armv7')) {
            targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/armeabi-v7a/libc++_shared.so']);
            if (FileSystem.exists(targetFile))
                FileSystem.deleteFile(targetFile);
        }

        if (archs.contains('arm64')) {
            targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/arm64-v8a/libc++_shared.so']);
            if (FileSystem.exists(targetFile))
                FileSystem.deleteFile(targetFile);
        }

        if (archs.contains('x86')) {
            targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/x86/libc++_shared.so']);
            if (FileSystem.exists(targetFile))
                FileSystem.deleteFile(targetFile);
        }

        if (archs.contains('x86_64')) {
            targetFile = Path.join([cwd, 'project/android/app/src/main/jniLibs/x86_64/libc++_shared.so']);
            if (FileSystem.exists(targetFile))
                FileSystem.deleteFile(targetFile);
        }

    }

    static var RE_SHARED_OBJECT = ~/^"([^"]+)",?$/;

    public static function setSharedObjectEnabled(cwd:String, project:Project, lib:String, enabled:Bool):Void {

        var androidProjectPath = Path.join([cwd, 'project/android']);
        var appActivityPath = Path.join([androidProjectPath, 'app/src/main/java', Std.string(Reflect.field(project.app, 'package')).replace('-','').toLowerCase().replace('.','/'), 'AppActivity.java']);

        if (FileSystem.exists(appActivityPath)) {
            var java = File.getContent(appActivityPath);
            var lines = java.split("\n");
            var result = [];
            var inGetLibraries = false;
            var inReturnNewString = false;
            var finishedPatching = false;
            for (line in lines) {
                var trimmedLine = line.trim();
                if (finishedPatching) {
                    result.push(line);
                }
                else if (inReturnNewString && RE_SHARED_OBJECT.match(trimmedLine)) {
                    var lineLib = RE_SHARED_OBJECT.matched(1);
                    if (lineLib != lib)
                        result.push(line);
                }
                else if (inReturnNewString && trimmedLine.indexOf('}') != -1) {
                    finishedPatching = true;
                    result.push(line);
                }
                else if (inReturnNewString) {
                    result.push(line);
                }
                else if (inGetLibraries && trimmedLine == 'return new String[] {') {
                    inReturnNewString = true;
                    result.push(line);
                    if (enabled)
                        result.push('            "$lib",');
                }
                else if (trimmedLine == 'protected String[] getLibraries() {') {
                    inGetLibraries = true;
                    result.push(line);
                }
                else {
                    result.push(line);
                }
            }

            // Did patch?
            if (inReturnNewString) {
                var newJava = result.join("\n");
                if (newJava != java) {
                    if (enabled)
                        print('Update AppActivity.java: add $lib');
                    else
                        print('Update AppActivity.java: remove $lib');
                    File.saveContent(appActivityPath, newJava);
                }
            }
        }

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
        javaSearchPaths.push(androidProjectPath + '/app/src/main/java/' + Std.string(Reflect.field(project.app, 'package')).replace('-','').toLowerCase().replace('.','/'));

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
