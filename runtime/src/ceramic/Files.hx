package ceramic;

#if (sys || node || nodejs || hxnodejs)
import sys.FileSystem;
#end

#if (node || nodejs || hxnodejs)
import js.node.Fs;
import js.node.ChildProcess;
#end

import haxe.io.Path;
import ceramic.Shortcuts.*;

using StringTools;

/** Filesystem-related utilities. Only work on sys targets and/or nodejs depending on the methods */
class Files {

    public static function haveSameContent(filePath1:String, filePath2:String):Bool {

        #if (sys || node || nodejs || hxnodejs)

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var content1 = sys.io.File.getContent(filePath1);
        var content2 = sys.io.File.getContent(filePath2);

        return content1 == content2;

        #else

        warning('haveSameContent() is not supported on this target');
        return false;

        #end

    } //haveSameContent

    /** Only works in nodejs for now. */
    public static function haveSameLastModified(filePath1:String, filePath2:String):Bool {

        #if (node || nodejs || hxnodejs)

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var time1 = Fs.statSync(filePath1).mtime.getTime();
        var time2 = Fs.statSync(filePath2).mtime.getTime();

        return time1 == time2;

        #else

        warning('haveSameLastModified() is not supported on this target');
        return false;

        #end

    } //haveSameLastModified

    /** Only works in nodejs for now. */
    public static function setToSameLastModified(srcFilePath:String, dstFilePath:String):Void {

        #if (node || nodejs || hxnodejs)

        var file1Exists = FileSystem.exists(srcFilePath);
        var file2Exists = FileSystem.exists(dstFilePath);

        if (!file1Exists || !file2Exists) return;

        var utime = Math.round(Fs.statSync(srcFilePath).mtime.getTime() / 1000.0);

        Fs.utimesSync(dstFilePath, cast utime, cast utime);

        #else

        warning('setToSameLastModified() is not supported on this target');

        #end

    } //haveSameLastModified

    /** Return file mtime in seconds. Only works in nodejs for now. */
    public static function getLastModified(filePath:String):Int {

        #if (node || nodejs || hxnodejs)

        if (!FileSystem.exists(filePath)) return -1;

        return Math.round(Fs.statSync(filePath).mtime.getTime() / 1000.0);

        #else

        warning('getLastModified() is not supported on this target');
        return -1;

        #end

    } //getLastModified
    
    public static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true, subCall:Bool = false):Array<String> {

        #if (sys || node || nodejs || hxnodejs)

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

        #else

        warning('getFlatDirectory() is not supported on this target');
        return [];

        #end

    } //getFlatDirectory

    public static function removeEmptyDirectories(dir:String, excludeSystemFiles:Bool = true):Void {

        #if (sys || node || nodejs || hxnodejs)

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

        #else

        warning('removeEmptyDirectories() is not supported on this target');

        #end

    } //removeEmptyDirectories

    public static function isEmptyDirectory(dir:String, excludeSystemFiles:Bool = true):Bool {

        #if (sys || node || nodejs || hxnodejs)

        for (name in FileSystem.readDirectory(dir)) {

            if (name == '.DS_Store') continue;

            return false;
        }

        return true;

        #else

        warning('isEmptyDirectory() is not supported on this target');
        return false;

        #end

    } //isEmptyDirectory

    public static function deleteRecursive(toDelete:String):Void {

        #if (sys || node || nodejs || hxnodejs)
        
        if (!FileSystem.exists(toDelete)) return;

        // Use shell if available
        #if (node || nodejs || hxnodejs)
        if (Sys.systemName() == 'Mac' || Sys.systemName() == 'Linux') {
            ChildProcess.execSync('rm -rf ' + toDelete.quoteUnixArg());
            return;
        }
        #end

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

        #else

        warning('deleteRecursive() is not supported on this target');

        #end

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

    public static function copyFileWithIntermediateDirs(srcPath:String, dstPath:String):Void {

        #if (sys || node || nodejs || hxnodejs)

        var dstDir = Path.directory(dstPath);
        if (!FileSystem.exists(dstDir)) {
            FileSystem.createDirectory(dstDir);
        }

        sys.io.File.copy(srcPath, dstPath);

        #else

        warning('copyFileWithIntermediateDirs() is not supported on this target');

        #end

    } //copyFileWithIntermediateDirs

    public static function copyDirectory(srcDir:String, dstDir:String, removeExisting:Bool = false):Void {

        #if (sys || node || nodejs || hxnodejs)

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

        #else

        warning('copyDirectory() is not supported on this target');

        #end

    } //copyDirectory

} //Files
