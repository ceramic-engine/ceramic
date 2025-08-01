package ceramic;

import ceramic.Path;
import ceramic.Platform;
import ceramic.Shortcuts.*;
import haxe.io.Bytes;

using StringTools;
#if (cs || sys || node || nodejs || hxnodejs)
import sys.FileSystem;
#end

#if (node || nodejs || hxnodejs)
import js.node.ChildProcess;
import js.node.Fs;
#end


/**
 * Cross-platform filesystem utilities for Ceramic.
 * 
 * This class provides a uniform API for file system operations across different targets
 * including native (sys), Node.js, and Electron. Methods automatically detect the runtime
 * environment and use the appropriate implementation.
 * 
 * Most methods will log a warning if called on unsupported platforms rather than throwing
 * exceptions, allowing code to be written once and deployed across platforms.
 * 
 * Supported platforms vary by method:
 * - Native (sys): Full support for all operations
 * - Node.js: Full support when running in Node environment
 * - Web + Electron: Support through Electron's Node.js integration
 * - Other web targets: No filesystem access (methods return defaults)
 * 
 * @see ceramic.Path
 * @see ceramic.Platform
 */
class Files {

    /**
     * Compares the content of two files for equality.
     * 
     * @param filePath1 Path to the first file
     * @param filePath2 Path to the second file
     * @return True if both files exist and have identical content, false otherwise
     */
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

    /**
     * Checks if two files have the same last modified timestamp.
     * 
     * Useful for synchronization and caching operations where timestamp
     * comparison is more efficient than content comparison.
     * 
     * @param filePath1 Path to the first file
     * @param filePath2 Path to the second file
     * @return True if both files exist and have the same modification time
     */
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

    /**
     * Copies the last modified timestamp from source file to destination file.
     * 
     * This is useful for maintaining timestamp consistency when copying files
     * or for cache validation purposes.
     * 
     * @param srcFilePath Source file to read timestamp from
     * @param dstFilePath Destination file to apply timestamp to
     * @note Currently only supported in Node.js environments
     */
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

    #if (cs || sys || node || nodejs || hxnodejs)
    /**
     * Recursively lists all files in a directory tree.
     * 
     * Returns a flat array of file paths relative to the input directory.
     * Directories themselves are not included in the result, only files.
     * 
     * Example:
     * ```haxe
     * var files = Files.getFlatDirectory("assets/images");
     * // Returns: ["icon.png", "sprites/player.png", "sprites/enemy.png"]
     * ```
     * 
     * @param dir Root directory to scan
     * @param excludeSystemFiles Whether to exclude system files like .DS_Store (default: true)
     * @param subCall Internal parameter for recursion (do not use)
     * @param recursive Whether to scan subdirectories (default: true)
     * @return Array of relative file paths
     */
    public static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true, subCall:Bool = false, recursive:Bool = true):Array<String> {

        var result:Array<String> = [];

        for (name in FileSystem.readDirectory(dir)) {

            if (excludeSystemFiles && name == '.DS_Store') continue;

            var path = Path.join([dir, name]);
            if (FileSystem.isDirectory(path)) {
                if (recursive)
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
    public static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true, subCall:Bool = false, recursive:Bool = true):Array<String> {

        var fs = Platform.nodeRequire('fs');
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
                if (recursive)
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
    public static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true, subCall:Bool = false, recursive:Bool = true):Array<String> {

        // Not implemented on this platform
        return [];

    }
    #end

    /**
     * Gets the last modified time of a file.
     * 
     * @param path Path to the file
     * @return Last modified time in seconds since Unix epoch, or -1 if unavailable
     */
    public static function getLastModified(path:String):Float {

        #if (cs || sys || hxnodejs || nodejs || node)
        var stat = FileSystem.stat(path);
        if (stat == null) return -1;
        return stat.mtime.getTime() / 1000.0;
        #elseif (web && ceramic_use_electron)
        var fs = Platform.nodeRequire('fs');
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

    /**
     * Recursively removes all empty directories within a directory tree.
     * 
     * This method traverses the directory tree depth-first and removes any
     * directories that contain no files (optionally ignoring system files).
     * 
     * @param dir Root directory to clean
     * @param excludeSystemFiles Whether to ignore .DS_Store when checking if empty
     */
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

    /**
     * Checks if a directory is empty.
     * 
     * @param dir Directory path to check
     * @param excludeSystemFiles Whether to ignore .DS_Store files
     * @return True if the directory contains no files or subdirectories
     */
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

    /**
     * Recursively deletes a file or directory and all its contents.
     * 
     * This is equivalent to `rm -rf` on Unix systems. Use with caution as
     * deleted files cannot be recovered.
     * 
     * @param toDelete Path to file or directory to delete
     */
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

    /**
     * Calculates the relative path from one location to another.
     * 
     * Example:
     * ```haxe
     * var rel = Files.getRelativePath("/home/user/project/src/Main.hx", "/home/user/project");
     * // Returns: "./src/Main.hx"
     * ```
     * 
     * @param absolutePath The target absolute path
     * @param relativeTo The base path to calculate relative from
     * @return The relative path from relativeTo to absolutePath
     */
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

    /**
     * Copies a file, creating any necessary parent directories.
     * 
     * If the destination directory doesn't exist, it will be created
     * automatically before copying the file.
     * 
     * @param srcPath Source file path
     * @param dstPath Destination file path
     */
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

    /**
     * Recursively copies a directory and all its contents.
     * 
     * @param srcDir Source directory to copy from
     * @param dstDir Destination directory to copy to
     * @param removeExisting If true, removes existing destination before copying
     */
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

    /**
     * Deletes a single file.
     * 
     * @param path Path to the file to delete
     * @throws If the file doesn't exist or cannot be deleted
     */
    public static function deleteFile(path:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.FileSystem.deleteFile(path);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

        if (fs == null) {
            log.warning('deleteFile() is not supported on this target without fs module');
            return;
        }
        else {
            fs.unlinkSync(path);
        }

        #else

        log.warning('deleteFile() is not supported on this target');

        #end

    }

    /**
     * Reads the entire content of a text file as a string.
     * 
     * @param path Path to the file to read
     * @return The file content as a string, or null if unavailable
     */
    public static function getContent(path:String):Null<String> {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.io.File.getContent(path);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

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

    /**
     * Reads the entire content of a file as binary data.
     * 
     * @param path Path to the file to read
     * @return The file content as bytes, or null if unavailable
     */
    public static function getBytes(path:String):Null<Bytes> {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.io.File.getBytes(path);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

        if (fs == null) {
            log.warning('getBytes() is not supported on this target without fs module');
            return null;
        }
        else {
            var data:UInt8Array = fs.readFileSync(path);
            return data != null ? data.toBytes() : null;
        }

        #else

        log.warning('getBytes() is not supported on this target');
        return null;

        #end

    }

    /**
     * Writes a string to a file, replacing any existing content.
     * 
     * @param path Path to the file to write
     * @param content Text content to write to the file
     */
    public static function saveContent(path:String, content:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        sys.io.File.saveContent(path, content);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

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

    /**
     * Writes binary data to a file, replacing any existing content.
     * 
     * @param path Path to the file to write
     * @param bytes Binary data to write to the file
     */
    public static function saveBytes(path:String, bytes:Bytes):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        sys.io.File.saveBytes(path, bytes);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

        if (fs == null) {
            log.warning('saveBytes() is not supported on this target without fs module');
        }
        else {
            var buffer = ceramic.UInt8Array.fromBytes(bytes);
            fs.writeFileSync(path, buffer, 'binary');
        }

        #else

        log.warning('saveBytes() is not supported on this target');

        #end

    }

    /**
     * Creates a directory, including any necessary parent directories.
     * 
     * This method creates the full directory path if it doesn't exist,
     * similar to `mkdir -p` on Unix systems.
     * 
     * @param path Directory path to create
     */
    public static function createDirectory(path:String):Void {

        #if (cs || sys || node || nodejs || hxnodejs)

        sys.FileSystem.createDirectory(path);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

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

    /**
     * Checks if a file or directory exists.
     * 
     * @param path Path to check
     * @return True if the path exists (file or directory), false otherwise
     */
    public static function exists(path:String):Bool {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.FileSystem.exists(path);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

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

    /**
     * Checks if a path points to a directory.
     * 
     * @param path Path to check
     * @return True if the path exists and is a directory, false otherwise
     */
    public static function isDirectory(path:String):Bool {

        #if (cs || sys || node || nodejs || hxnodejs)

        return sys.FileSystem.isDirectory(path);

        #elseif (web && ceramic_use_electron)

        var fs = Platform.nodeRequire('fs');

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
