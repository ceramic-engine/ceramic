package tools;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class Templates {

    public static function replaceInContents(path:String, replacements:Map<String,String>):Void {

        var projectPath = path;

        // Perform content replaces
        //
        for (filePathItem in Files.getFlatDirectory(projectPath)) {
            var filePath = Path.join([projectPath, filePathItem]);

            // Check if file is a text file
            var isTextFile = false;

            // If file is not a directory
            var textExts = 'strings m h json xcworkspacedata pbxproj pch plist yml yaml xml iml'.split(' ');
            var binaryExts = 'png jpg jpeg data zip a'.split(' ');
            if (FileSystem.exists(filePath) && !FileSystem.isDirectory(filePath)) {

                // Check extension
                var fileExt = filePath.indexOf('.') == -1 ? null : filePath.substr(filePath.indexOf('.') + 1);
                if (fileExt == null || fileExt.trim() == '') {
                    isTextFile = IsTextOrBinary.isText(filePath, File.getBytes(filePath));
                }
                else if (textExts.indexOf(fileExt) != -1) {
                    isTextFile = true;
                }
                else if (binaryExts.indexOf(fileExt) != -1) {
                    isTextFile = false;
                }
                else {
                    isTextFile = IsTextOrBinary.isText(filePath, File.getBytes(filePath));
                }

                // If it is a text file, perform replace
                if (isTextFile) {
                    var str = sys.io.File.getContent(filePath);
                    var prevStr = str;
                    for (key in replacements.keys()) {
                        str = str.replace(key, replacements[key]);
                    }
                    if (prevStr != str) sys.io.File.saveContent(filePath, str);
                }
            }

        }

    }

    public static function replaceInNames(path:String, replacements:Map<String,String>):Void {

        var projectPath = path;

        // Perform file/directory renames
        //
        for (key in replacements.keys()) {
            var value = replacements[key];

            while (true) {

                var didRenameAFile = false;

                for (filePathItem in Files.getFlatDirectory(projectPath)) {
                    var filePath = Path.join([projectPath, filePathItem]);
                    if (FileSystem.exists(filePath) && filePath.indexOf(key) != -1) {
                        var fileReplacement = filePath.substr(projectPath.length);
                        var lastKeyIndex = fileReplacement.lastIndexOf(key);
                        fileReplacement = fileReplacement.substring(0, lastKeyIndex) + value + fileReplacement.substring(lastKeyIndex + key.length);
                        var newFilePath = projectPath + fileReplacement;
                        if (newFilePath != filePath) {
                            var prevDir = Path.directory(filePath);
                            var newDir = Path.directory(newFilePath);
                            if (!FileSystem.exists(newDir)) {
                                FileSystem.createDirectory(newDir);
                            }
                            FileSystem.rename(filePath, newFilePath);
                            didRenameAFile = true;
                            break;
                        }
                    }
                }

                if (!didRenameAFile) break;
            }
        }

    }

}
