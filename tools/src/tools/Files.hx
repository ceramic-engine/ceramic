package tools;

import sys.FileSystem;
import haxe.io.Path;
import haxe.DynamicAccess;
import js.node.Fs;
import js.node.ChildProcess;

using StringTools;

class Files {

    public static function haveSameLastModified(filePath1:String, filePath2:String):Bool {

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var time1 = Fs.statSync(filePath1).mtime.getTime();
        var time2 = Fs.statSync(filePath2).mtime.getTime();

        return Math.abs(time1 - time2) < 1000; // 1 second tolerance

    }

    public static function setToSameLastModified(srcFilePath:String, dstFilePath:String):Void {

        var file1Exists = FileSystem.exists(srcFilePath);
        var file2Exists = FileSystem.exists(dstFilePath);

        if (!file1Exists || !file2Exists) return;

        var utime = Math.round(Fs.statSync(srcFilePath).mtime.getTime() / 1000.0);

        Fs.utimesSync(dstFilePath, cast utime, cast utime);

    }

    public static function getLastModified(filePath:String):Int {

        if (!FileSystem.exists(filePath)) return -1;

        return Math.round(Fs.statSync(filePath).mtime.getTime() / 1000.0);

    }

    public static function touch(filePath:String):Void {

        if (!FileSystem.exists(filePath)) {
            if (!FileSystem.exists(Path.directory(filePath))) {
                FileSystem.createDirectory(Path.directory(filePath));
            }
            sys.io.File.saveContent(filePath, '');
        }
        var utime = Date.now().getTime() / 1000.0;
        Fs.utimesSync(filePath, cast utime, cast utime);

    }
    
    public static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true, subCall:Bool = false):Array<String> {

        var result:Array<String> = [];

        for (name in FileSystem.readDirectory(dir)) {

            if (excludeSystemFiles && name == '.DS_Store') continue;

            var path = Path.join([dir, name]);
            if (FileSystem.isDirectory(path)) {
                result = result.concat(getFlatDirectory(path, excludeSystemFiles, true));
            } else {
                result.push(path);
            }
        }

        if (!subCall) {
            var prevResult = result;
            result = [];
            var prefix = Path.normalize(dir);
            if (!prefix.endsWith('/')) prefix += '/';
            for (item in prevResult) {
                result.push(item.substr(prefix.length));
            }
        }

        return result;

    }

    public static function removeEmptyDirectories(dir:String, excludeSystemFiles:Bool = true):Void {

        for (name in FileSystem.readDirectory(dir)) {

            if (name == '.DS_Store') continue;

            var path = Path.join([dir, name]);
            if (FileSystem.isDirectory(path)) {
                removeEmptyDirectories(path, excludeSystemFiles);
                if (isEmptyDirectory(path, excludeSystemFiles)) {
                    deleteRecursive(path);
                }
            }
        }

    }

    public static function isEmptyDirectory(dir:String, excludeSystemFiles:Bool = true):Bool {

        for (name in FileSystem.readDirectory(dir)) {

            if (name == '.DS_Store') continue;

            return false;
        }

        return true;

    }

    public static function deleteAnyFileNamed(toDeleteName:String, inDirectory:String):Void {

        if (FileSystem.isDirectory(inDirectory)) {

            for (name in FileSystem.readDirectory(inDirectory)) {

                var path = Path.join([inDirectory, name]);
                if (name == toDeleteName) {
                    if (FileSystem.isDirectory(path)) {
                        deleteRecursive(path);
                    } else {
                        FileSystem.deleteFile(path);
                    }
                }
                else if (FileSystem.isDirectory(path)) {
                    deleteAnyFileNamed(toDeleteName, path);
                }
            }

        }
        else {
            throw '$inDirectory is not a directory!';
        }

    }

    public static function zipDirectory(srcDirectory:String, dstZip:String):Void {

        var os = Sys.systemName();
        if (os == 'Mac' || os == 'Linux') {
            tools.Helpers.command('zip', ['-9', '-r', '-q', '-y', dstZip, Path.withoutDirectory(srcDirectory)], { cwd: Path.directory(srcDirectory) });
        }
        else {
            throw 'Zip not supported on $os';
        }

    }

    public static function deleteRecursive(toDelete:String):Void {
        
        if (!FileSystem.exists(toDelete)) return;

        // Use shell if available
        var os = Sys.systemName();
        if (os == 'Mac' || os == 'Linux') {
            tools.Helpers.command('rm', ['-rf', toDelete]);
            return;
        }

        if (FileSystem.isDirectory(toDelete)) {

            for (name in FileSystem.readDirectory(toDelete)) {

                var path = Path.join([toDelete, name]);
                if (FileSystem.isDirectory(path)) {
                    deleteRecursive(path);
                } else {
                    FileSystem.deleteFile(path);
                }
            }

            FileSystem.deleteDirectory(toDelete);

        }
        else {

            FileSystem.deleteFile(toDelete);

        }

    }

    public static function getRelativePath(absolutePath:String, relativeTo:String):String {

        var isWindows = Sys.systemName() == 'Windows';

        if (isWindows) {
            var driveA = Path.normalize(absolutePath).substr(0, 2).toLowerCase();
            var driveB = Path.normalize(relativeTo).substr(0, 2).toLowerCase();
            if (driveA.charAt(1) == ':' && driveB.charAt(1) == ':' && driveA != driveB) {
                // Path located on different drives, can't be relative
                return absolutePath;
            }
        }

        var fromParts = Path.normalize(relativeTo).substr(isWindows ? 3 : 1).split('/');
        var toParts = Path.normalize(absolutePath).substr(isWindows ? 3 : 1).split('/');

        var length:Int = cast Math.min(fromParts.length, toParts.length);
        var samePartsLength = length;
        for (i in 0...length) {
            if (fromParts[i] != toParts[i]) {
                samePartsLength = i;
                break;
            }
        }

        var outputParts = [];
        for (i in samePartsLength...fromParts.length) {
            outputParts.push('..');
        }

        outputParts = outputParts.concat(toParts.slice(samePartsLength));

        var result = outputParts.join('/');
        if (absolutePath.endsWith('/') && !result.endsWith('/')) {
            result += '/';
        }

        if (!result.startsWith('.')) result = './' + result;

        return result;

    }

    /** Copy a file from `srcFile` to `dstPath`, only if target is different than source.
        After copy, sets target to the same last modified time than source. */
    public static function copyIfNeeded(srcFile:String, dstFile:String, createDirectory:Bool = true):Void {

        if (createDirectory && !FileSystem.exists(Path.directory(dstFile))) {
            FileSystem.createDirectory(Path.directory(dstFile));
        }
        if (FileSystem.exists(srcFile) && !Files.haveSameLastModified(srcFile, dstFile)) {
            sys.io.File.copy(
                srcFile,
                dstFile
            );
            Files.setToSameLastModified(srcFile, dstFile);
        }

    }

    public static function copyDirectory(srcDir:String, dstDir:String, removeExisting:Bool = false):Void {

        if (FileSystem.exists(dstDir) && (removeExisting || !FileSystem.isDirectory(dstDir))) {
            deleteRecursive(dstDir);
        }
        if (!FileSystem.exists(dstDir)) {
            FileSystem.createDirectory(dstDir);
        }

        for (name in FileSystem.readDirectory(srcDir)) {

            if (name == '.DS_Store') continue;
            var srcPath = Path.join([srcDir, name]);
            var dstPath = Path.join([dstDir, name]);

            if (FileSystem.isDirectory(srcPath)) {
                copyDirectory(srcPath, dstPath, removeExisting);
            }
            else {
                sys.io.File.copy(srcPath, dstPath);
            }
            
        }

    }

    /** Scan a directory and return a mapping of file paths and their last modified time. */
    public static function getDirectoryLastModifiedList(dir:String, fileSuffix:String, ?output:DynamicAccess<Float>):DynamicAccess<Float> {

        if (output == null) {
            output = {};
        }

        if (!FileSystem.exists(dir)) {
            return output;
        }

        for (name in FileSystem.readDirectory(dir)) {

            var filePath = Path.join([dir, name]);

            if (FileSystem.isDirectory(filePath)) {
                getDirectoryLastModifiedList(filePath, fileSuffix, output);
            }
            else if (fileSuffix == null || filePath.endsWith(fileSuffix)) {
                output.set(filePath, getLastModified(filePath));
            }
            
        }

        return output;

    }

    public static function hasDirectoryChanged(lastModifiedListBefore:DynamicAccess<Float>, lastModifiedListAfter:DynamicAccess<Float>):Bool {

        // Check if any previous file has changed
        for (key in lastModifiedListBefore.keys()) {
            if (!lastModifiedListAfter.exists(key)) {
                // File was removed
                return true;
            }
            if (Math.abs(lastModifiedListAfter.get(key) - lastModifiedListBefore.get(key)) >= 1.0) {
                // File has changed
                return true;
            }
        }

        // Check if any new file was added
        for (key in lastModifiedListAfter.keys()) {
            if (!lastModifiedListAfter.exists(key)) {
                // This is a new file
                return true;
            }
        }

        // Nothing changed
        return false;

    }

}
