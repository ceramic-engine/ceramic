package backend.http;

#if (cpp || sys)

import ceramic.Path;
import ceramic.Runner;
import ceramic.Shortcuts.*;
import sys.FileSystem;
import sys.io.File;

class HttpNative {

    public static function download(url:String, targetPath:String, done:String->Void):Void {

        var tmpTargetPath = targetPath + '.tmpdl';

        // Ensure we can write the file at the desired location
        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.isDirectory(tmpTargetPath)) {
                log.error('Cannot overwrite directory named $tmpTargetPath');
                done(null);
                return;
            }
            FileSystem.deleteFile(tmpTargetPath);
        }
        var dir = Path.directory(tmpTargetPath);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
        else if (!FileSystem.isDirectory(dir)) {
            log.error('Target directory $dir should be a directory, but it is a file');
            done(null);
            return;
        }

        Runner.runInBackground(function() {
            var success = downloadToFile(url, tmpTargetPath);
            Runner.runInMain(function() {
                if (success) {
                    finishDownload(tmpTargetPath, targetPath, url, done);
                } else {
                    log.error('Failed to download $url');
                    done(null);
                }
            });
        });

    }

    static function downloadToFile(url:String, localPath:String, followingLocation:Bool = false):Bool {
        var out = File.write(localPath, true);
        var h = new haxe.Http(url);
        h.cnxTimeout = 30;

        var success = true;
        h.onError = function(e) {
            out.close();
            if (FileSystem.exists(localPath)) {
                FileSystem.deleteFile(localPath);
            }
            success = false;
        };

        h.customRequest(false, out);
        out.close();

        // Handle redirects
        if (success && h.responseHeaders != null) {
            var location = h.responseHeaders.get("Location");
            if (location == null) location = h.responseHeaders.get("location");
            if (location != null && location != url) {
                return downloadToFile(location, localPath, true);
            }
        }

        return success;
    }

    static function finishDownload(tmpTargetPath:String, targetPath:String, url:String, done:String->Void):Void {

        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.exists(targetPath)) {
                if (FileSystem.isDirectory(targetPath)) {
                    log.error('Cannot overwrite directory named $targetPath');
                    done(null);
                    return;
                }
                FileSystem.deleteFile(targetPath);
            }
            FileSystem.rename(tmpTargetPath, targetPath);
            if (FileSystem.exists(targetPath) && !FileSystem.isDirectory(targetPath)) {
                log.success('Downloaded file from url $url at path $targetPath');
                done(targetPath);
                return;
            }
            else {
                log.error('Error when copying $tmpTargetPath to $targetPath');
                done(null);
                return;
            }
        }
        else {
            log.error('Failed to download $url at path $targetPath. No downloaded file.');
            done(null);
            return;
        }

    }

}

#end
