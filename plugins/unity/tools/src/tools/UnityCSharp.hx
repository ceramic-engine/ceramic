package tools;

import haxe.crypto.Md5;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class UnityCSharp {

    public static function exportScriptFilesToProject(cwd:String, project:Project) {

        var debug = context.debug;
        var variant = context.variant;
        var outTargetPath = BuildTargetExtensions.outPathWithName('unity', 'unity', cwd, debug, variant);
        var unityProjectPath = UnityProject.resolveUnityProjectPath(cwd, project);

        var srcCsPath = Path.join([outTargetPath, 'bin', 'src']);
        var dstCsPath = Path.join([unityProjectPath, 'Assets', 'Ceramic', 'Scripts']);

        var dstResourcesPath = Path.join([unityProjectPath, 'Assets', 'Ceramic', 'Resources']);

        // List source files
        var srcList = Files.getFlatDirectory(srcCsPath);
        var srcNames = new Map<String,Bool>();
        for (name in srcList) {
            srcNames.set(sanitizeName(name), true);
        }

        // List existing destination files
        var dstList = [];
        if (FileSystem.exists(dstCsPath)) {
            dstList = Files.getFlatDirectory(dstCsPath);
        }
        var dstNames = new Map<String,Bool>();
        for (name in dstList) {
            dstNames.set(name, true);
        }

        // Then update or create every file
        for (name in srcList) {

            // Only process C# files
            if (name.endsWith('.cs')) {

                var srcFilePath = Path.join([srcCsPath, name]);
                var srcContent = File.getContent(srcFilePath);
                var processedContent = processScriptContent(srcContent);
                var normalizedPath = Path.normalize(name);
                if (normalizedPath == 'cs/internal/FieldLookup.cs') {
                    processedContent = patchFieldLookup(processedContent, dstResourcesPath);
                }
                else if (normalizedPath == 'cs/internal/Runtime.cs') {
                    processedContent = patchRuntime(processedContent, dstResourcesPath);
                }
                else if (normalizedPath == 'Array.cs') {
                    processedContent = patchGenericCast(processedContent);
                }

                var sanitizedName = sanitizeName(normalizedPath);

                var dstFilePath = Path.join([dstCsPath, sanitizedName]);
                var existingContent = null;

                if (dstNames.exists(sanitizedName)) {
                    existingContent = File.getContent(dstFilePath);
                }

                if (processedContent != existingContent) {
                    // Content is different
                    if (!dstNames.exists(sanitizedName)) {
                        // Check that intermediate directories are created
                        var directory = Path.directory(dstFilePath);
                        if (!FileSystem.exists(directory)) {
                            FileSystem.createDirectory(directory);
                        }
                    }
                    // Copy file content!
                    File.saveContent(dstFilePath, processedContent);
                }
            }
        }

        // Remove outdated files
        for (name in dstList) {

            // Only process C# files
            if (name.endsWith('.cs')) {
                if (!srcNames.exists(name)) {
                    // Found outdated file, remove it
                    var outdatedFilePath = Path.join([dstCsPath, name]);
                    if (FileSystem.exists(outdatedFilePath)) {
                        FileSystem.deleteFile(outdatedFilePath);
                    }
                    // Remove related meta file (if any)
                    var outdatedMeta = outdatedFilePath + '.meta';
                    if (FileSystem.exists(outdatedMeta)) {
                        FileSystem.deleteFile(outdatedMeta);
                    }
                }
            }

        }

    }

    static function sanitizeName(name:String):String {

        var sanitizedNameParts = Path.normalize(name).split('/');
        for (i in 0...sanitizedNameParts.length) {
            var part = sanitizedNameParts[i];
            if (part == 'editor') {
                sanitizedNameParts[i] = '_editor';
            }
        }
        return sanitizedNameParts.join('/');

    }

    static function processScriptContent(content:String):String {

        // Disable stripping
        //content = '[assembly: Preserve] ' + content;

        // content = 'using Unity.IL2CPP.CompilerServices;\n' + content;

        // content = content.replace('\tpublic class ', '\t[Il2CppSetOption(Option.NullChecks, false)]\n\t[Il2CppSetOption(Option.ArrayBoundsChecks, false)]\n\tpublic class ');
        // content = content.replace('\tpublic sealed class ', '\t[Il2CppSetOption(Option.NullChecks, false)]\n\t[Il2CppSetOption(Option.ArrayBoundsChecks, false)]\n\tpublic class ');

        // Somehow, there are cases where System is not marked with global:: and that conflicts with ceramic's System class
        content = content.replace('\tSystem.Type', '\tglobal::System.Type');

        // Disable Timer.getTime() warning
        // TODO: fix the actual code!
        content = content.replace('#pragma warning disable ', '#pragma warning disable 618, ');

        // Mute hidden inherited member
        content = content.replace('#pragma warning disable ', '#pragma warning disable 108, ');

        return content;

    }

    static function patchFieldLookup(content:String, dstResourcesPath:String):String {

        // Extract field ids
        var fieldIdsDecl = 'protected static int[] fieldIds = new int[]{';
        var fieldIdsIndex = content.indexOf(fieldIdsDecl);
        if (fieldIdsIndex != -1) {
            var fieldIdsEndIndex = content.indexOf('};', fieldIdsIndex + fieldIdsDecl.length);
            var fieldIdsData = content.substring(fieldIdsIndex + fieldIdsDecl.length, fieldIdsEndIndex).replace(' ', '').replace(',', "\n").trim();
            var numFieldIds = fieldIdsData.split("\n").length;
            var fieldIdsHash = Md5.encode(fieldIdsData);
            var fieldIdsFilePath = Path.join([dstResourcesPath, 'lookup_i.txt']);

            // Save data as a text asset
            var existingFieldIdsData = null;
            if (FileSystem.exists(fieldIdsFilePath)) {
                existingFieldIdsData = File.getContent(fieldIdsFilePath);
            }
            if (fieldIdsData != existingFieldIdsData) {
                if (!FileSystem.exists(dstResourcesPath)) {
                    FileSystem.createDirectory(dstResourcesPath);
                }
                File.saveContent(fieldIdsFilePath, fieldIdsData);
            }

            // Patch C# script to make it load text asset data instead of embedding array
            var patchedFieldIds = 'protected static int[] fieldIds = global::backend.FieldLookup.loadFieldIds($numFieldIds, "$fieldIdsHash");';
            content = content.substring(0, fieldIdsIndex) + patchedFieldIds + content.substring(fieldIdsEndIndex + 2);
        }
        else {
            warning('Failed to patch field lookup ids');
        }

        // Extract field names
        var fieldNamesDecl = 'protected static string[] fields = new string[]{"';
        var fieldNamesIndex = content.indexOf(fieldNamesDecl);
        if (fieldNamesIndex != -1) {
            var fieldNamesEndIndex = content.indexOf('"};', fieldNamesIndex + fieldNamesDecl.length);
            var fieldNamesData = content.substring(fieldNamesIndex + fieldNamesDecl.length, fieldNamesEndIndex).replace(' ', '').replace('","', "\n").trim();
            var numFieldNames = fieldNamesData.split("\n").length;
            var fieldNamesHash = Md5.encode(fieldNamesData);
            var fieldNamesFilePath = Path.join([dstResourcesPath, 'lookup_s.txt']);

            // Save data as a text asset
            var existingFieldNamesData = null;
            if (FileSystem.exists(fieldNamesFilePath)) {
                existingFieldNamesData = File.getContent(fieldNamesFilePath);
            }
            if (fieldNamesData != existingFieldNamesData) {
                if (!FileSystem.exists(dstResourcesPath)) {
                    FileSystem.createDirectory(dstResourcesPath);
                }
                File.saveContent(fieldNamesFilePath, fieldNamesData);
            }

            // Patch C# script to make it load text asset data instead of embedding array
            var patchedFieldNames = 'protected static string[] fields = global::backend.FieldLookup.loadFieldNames($numFieldNames, "$fieldNamesHash");';
            content = content.substring(0, fieldNamesIndex) + patchedFieldNames + content.substring(fieldNamesEndIndex + 3);
        }
        else {
            warning('Failed to patch field lookup names');
        }

        return content;

    }

    static function patchGenericCast(content:String):String {

        content = content.replace('global::haxe.lang.Runtime.genericCast<T>(this.__a[', '(this.__a[');
        content = content.replace('global::haxe.lang.Runtime.genericCast<T>(x', '(x');

        return content;

    }

    static function patchRuntime(content:String, dstResourcesPath:String):String {

        var indexOfConstructor = content.indexOf('public Runtime() {');

        if (indexOfConstructor != -1) {

            var overloads = [];

            overloads.push('public static int toInt(int val) { return val; }');
            overloads.push('public static int toInt(float val) { return (int)val; }');
            overloads.push('public static int toInt(double val) { return (int)val; }');

            overloads.push('public static double toDouble(int val) { return (double)val; }');
            overloads.push('public static double toDouble(float val) { return (double)val; }');
            overloads.push('public static double toDouble(double val) { return val; }');

            content = content.substring(0, indexOfConstructor) + overloads.join('\n') + '\n' + content.substring(indexOfConstructor);

        }

        return content;

    }

}