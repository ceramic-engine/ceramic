package tools;

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

}