package tools;

import haxe.crypto.Md5;
import sys.io.File;
import tools.Helpers.*;
import tools.Project;

import sys.FileSystem;

import haxe.io.Path;

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
            srcNames.set(name, true);
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
                if (Path.normalize(name) == 'cs/internal/FieldLookup.cs') {
                    processedContent = patchFieldLookup(processedContent, dstResourcesPath);
                }
                var dstFilePath = Path.join([dstCsPath, name]);
                var existingContent = null;

                if (dstNames.exists(name)) {
                    existingContent = File.getContent(dstFilePath);
                }

                if (processedContent != existingContent) {
                    // Content is different
                    if (!dstNames.exists(name)) {
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

    static function processScriptContent(content:String):String {

        // Disable stripping
        //content = '[assembly: Preserve] ' + content;

        // Disable Timer.getTime() warning
        // TODO: fix the actual code!
        content = content.replace('#pragma warning disable ', '#pragma warning disable 618, ');

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

}