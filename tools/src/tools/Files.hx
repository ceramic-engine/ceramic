package tools;

import sys.FileSystem;
import haxe.io.Path;
import js.node.Fs;

using StringTools;

class Files {

    public static function haveSameLastModified(filePath1:String, filePath2:String):Bool {

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var time1 = Fs.statSync(filePath1).mtime.getTime();
        var time2 = Fs.statSync(filePath2).mtime.getTime();

        return time1 == time2;

    } //haveSameLastModified

    public static function setToSameLastModified(filePath1:String, filePath2:String):Void {

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (!file1Exists || !file2Exists) return;

        var utime = Math.round(Fs.statSync(filePath1).mtime.getTime() / 1000.0);

        Fs.utimesSync(filePath2, cast utime, cast utime);

    } //haveSameLastModified

    public static function getLastModified(filePath:String):Int {

        if (!FileSystem.exists(filePath)) return -1;

        return Math.round(Fs.statSync(filePath).mtime.getTime() / 1000.0);

    } //getLastModified
    
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

    } //getFlatDirectory

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

    } //removeEmptyDirectories

    public static function isEmptyDirectory(dir:String, excludeSystemFiles:Bool = true):Bool {

        for (name in FileSystem.readDirectory(dir)) {

            if (name == '.DS_Store') continue;

            return false;
        }

        return true;

    } //isEmptyDirectory

    public static function deleteRecursive(toDelete:String):Void {

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

    } //deleteRecursive

    public static function getRelativePath(absolutePath:String, relativeTo:String):String {

        var isWindows = Sys.systemName() == 'Windows';

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

    } //getRelativePath

} //Files
