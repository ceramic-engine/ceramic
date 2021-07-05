package ceramic;

#if (cs || sys || node || nodejs || hxnodejs)
import sys.FileSystem;
#end

#if (node || nodejs || hxnodejs)
import js.node.Fs;
import js.node.ChildProcess;
#end

import ceramic.Path;
import ceramic.PlatformSpecific;
import ceramic.Shortcuts.*;

using StringTools;

/** Filesystem-related utilities. Only work on sys targets and/or nodejs depending on the methods */
class Files {

    public static function haveSameContent(filePath1:String, filePath2:String):Bool {

        #if (cs || sys || node || nodejs || hxnodejs)

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var content1 = sys.io.File.getContent(filePath1);
        var content2 = sys.io.File.getContent(filePath2);

        return content1 == content2;

        #else

        log.warning('haveSameContent() is not supported on this target');
        return false;

        #end

    }

    public static function haveSameLastModified(filePath1:String, filePath2:String):Bool {

        #if (node || nodejs || hxnodejs)

        var file1Exists = FileSystem.exists(filePath1);
        var file2Exists = FileSystem.exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var time1 = Fs.statSync(filePath1).mtime.getTime();
        var time2 = Fs.statSync(filePath2).mtime.getTime();

        return time1 == time2;

        #elseif (cs || sys || (web && ceramic_use_electron))

        var file1Exists = exists(filePath1);
        var file2Exists = exists(filePath2);

        if (file1Exists != file2Exists) return false;
        if (!file1Exists && !file2Exists) return false;

        var time1 = getLastModified(filePath1);
        var time2 = getLastModified(filePath2);

        return time1 == time2 && time1 != -1;

        #else

        log.warning('haveSameLastModified() is not supported on this target');
        return false;

        #end

    }

    /** Only works in nodejs for now. */
    public static function setToSameLastModified(srcFilePath:String, dstFilePath:String):Void {

        #if (node || nodejs || hxnodejs)

        var file1Exists = FileSystem.exists(srcFilePath);
        var file2Exists = FileSystem.exists(dstFilePath);

        if (!file1Exists || !file2Exists) return;

        var utime = Math.round(Fs.statSync(srcFilePath).mtime.getTime() / 1000.0);

        Fs.utimesSync(dstFilePath, cast utime, cast utime);

        #else

        log.warning('setToSameLastModified() is not supported on this target');

        #end

    }
    
    #if (cs || sys || node || nodejs)
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
    #elseif (web && ceramic_use_electron)
    public static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true, subCall:Bool = false):Array<String> {

        var fs = PlatformSpecific.nodeRequire('fs');
        var result:Array<String> = [];
        
        if (fs == null) {
            return result;
        }

        var list:Array<String> = fs.readdirSync(dir);
        for (name in list) {

            if (excludeSystemFiles && name == '.DS_Store') continue;

            var path = Path.join([dir, name]);
            var stat:Dynamic = fs.lstatSync(path);
            var isDir:Bool = stat != null && stat.isDirectory();
            if (isDir) {
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
    #else
    public static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true):Array<String> {

        // Not implemented on this platform
        return [];

    }
    #end

    /**
     * Get file last modified time (in seconds) or `-1` if not available
     * @param path 
     * @return Float
     */
    public static function getLastModified(path:String):Float {

        #if (cs || sys || hxnodejs || nodejs || node)
        var stat = FileSystem.stat(path);
        if (stat == null) return -1;
        return stat.mtime.getTime() / 1000.0;
        #elseif (web && ceramic_use_electron)
        var fs = PlatformSpecific.nodeRequire('fs');
        if (fs != null) {
            var stat = fs.statSync(path);
            if (stat == null) return -1;
            return stat.mtime.getTime() / 1000.0;
        }
        else {
            return -1;
        }
        #else
        return -1;
        #end

    }

    public static function removeEmptyDirectories(dir:String, excludeSystemFiles:Bool = true):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

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

        log.warning('removeEmptyDirectories() is not supported on this target');

        #end

    }

    public static function isEmptyDirectory(dir:String, excludeSystemFiles:Bool = true):Bool {

        #if (cs || sys || node || nodejs || hxnodejs)

        for (name in FileSystem.readDirectory(dir)) {

            if (name == '.DS_Store') continue;

            return false;
        }

        return true;

        #else

        log.warning('isEmptyDirectory() is not supported on this target');
        return false;

        #end

    }

    public static function deleteRecursive(toDelete:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)
        
        if (!FileSystem.exists(toDelete)) return;

        // Use shell if available
        #if (node || nodejs || hxnodejs)
        if (Sys.systemName() == 'Mac' || Sys.systemName() == 'Linux') {
            ChildProcess.execSync('rm -rf ' + haxe.SysTools.quoteUnixArg(toDelete));
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

        log.warning('deleteRecursive() is not supported on this target');

        #end

    }

    public static function getRelativePath(absolutePath:String, relativeTo:String):String {

        var isWindows = false;
        #if (cs || sys || node || nodejs || hxnodejs)
        isWindows = Sys.systemName() == 'Windows';
        #end

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

    public static function copyFileWithIntermediateDirs(srcPath:String, dstPath:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        var dstDir = Path.directory(dstPath);
        if (!FileSystem.exists(dstDir)) {
            FileSystem.createDirectory(dstDir);
        }

        sys.io.File.copy(srcPath, dstPath);

        #else

        log.warning('copyFileWithIntermediateDirs() is not supported on this target');

        #end

    }

    public static function copyDirectory(srcDir:String, dstDir:String, removeExisting:Bool = false):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

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

        log.warning('copyDirectory() is not supported on this target');

        #end

    }

    public static function getContent(path:String):Null<String> {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.io.File.getContent(path);

        #elseif (web && ceramic_use_electron)

        var fs = PlatformSpecific.nodeRequire('fs');
        
        if (fs == null) {
            log.warning('getContent() is not supported on this target without fs module');
            return null;
        }
        else {
            return fs.readFileSync(path, 'utf8');
        }

        #else

        log.warning('getContent() is not supported on this target');
        return null;

        #end

    }

    public static function saveContent(path:String, content:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        sys.io.File.saveContent(path, content);

        #elseif (web && ceramic_use_electron)

        var fs = PlatformSpecific.nodeRequire('fs');
        
        if (fs == null) {
            log.warning('saveContent() is not supported on this target without fs module');
        }
        else {
            fs.writeFileSync(path, content);
        }

        #else

        log.warning('saveContent() is not supported on this target');

        #end

    }

    public static function createDirectory(path:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        sys.FileSystem.createDirectory(path);

        #elseif (web && ceramic_use_electron)

        var fs = PlatformSpecific.nodeRequire('fs');
        
        if (fs == null) {
            log.warning('createDirectory() is not supported on this target without fs module');
        }
        else {
            fsCreateDirectory(fs, path);
        }

        #else

        log.warning('createDirectory() is not supported on this target');

        #end

    }

    #if (web && ceramic_use_electron)
    static function fsCreateDirectory(fs:Dynamic, dir:String) {
        try {
            fs.mkdirSync(dir);
        } catch (e:Dynamic) {
            if (e.code == "ENOENT") {
                // parent doesn't exist - create parent and then this dir
                fsCreateDirectory(fs, Path.directory(dir));
                fs.mkdirSync(dir);
            } else {
                // some other error - check if path is a dir, rethrow the error if not
                // (the `(e : Error)` cast is here to avoid HaxeError wrapping, though we need to investigate this in Haxe itself)
                var stat = try fs.statSync(dir) catch (_:Dynamic) throw(e : js.lib.Error);
                if (!stat.isDirectory())
                    throw(e : js.lib.Error);
            }
        }
    }
    #end

    public static function exists(path:String):Bool {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.FileSystem.exists(path);

        #elseif (web && ceramic_use_electron)

        var fs = PlatformSpecific.nodeRequire('fs');
        
        if (fs == null) {
            log.warning('exists() is not supported on this target without fs module');
            return false;
        }
        else {
            try {
                fs.accessSync(path);
                return true;
            }
            catch (e:Dynamic) {
                return false;
            }
        }

        #else

        log.warning('exists() is not supported on this target');
        return false;

        #end

    }

    public static function isDirectory(path:String):Bool {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.FileSystem.isDirectory(path);

        #elseif (web && ceramic_use_electron)

        var fs = PlatformSpecific.nodeRequire('fs');
        
        if (fs == null) {
            log.warning('isDirectory() is not supported on this target without fs module');
            return false;
        }
        else {
            try {
                var stat = fs.statSync(path);
                return stat.isDirectory();
            }
            catch (e:Dynamic) {
                return false;
            }
        }

        #else

        log.warning('isDirectory() is not supported on this target');
        return false;

        #end

    }

}
