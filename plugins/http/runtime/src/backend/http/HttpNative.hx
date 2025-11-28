package backend.http;

#if (cpp || sys)

import ceramic.Runner;
import ceramic.Shortcuts.*;
import sys.FileSystem;

class HttpNative {

    public static function download(url:String, tmpTargetPath:String, targetPath:String, done:String->Void):Void {

        #if (mac || linux)

        // Use built-in curl on mac & linux, that's the easiest!
        Runner.runInBackground(function() {
            Sys.command('curl', ['-sS', '-L', url, '--output', tmpTargetPath]);
            Runner.runInMain(function() {
                finishDownload(tmpTargetPath, targetPath, url, done);
            });
        });

        #elseif windows

        // Use curl through powershell on windows
        Runner.runInBackground(function() {
            var escapedArgs = [];
            for (arg in ['-sS', '-L' , url, '--output', tmpTargetPath]) {
                escapedArgs.push(haxe.SysTools.quoteWinArg(arg, true));
            }

            Sys.command('powershell', ['-command', escapedArgs.join(' ')]);
            Runner.runInMain(function() {
                finishDownload(tmpTargetPath, targetPath, url, done);
            });
        });

        #end

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
