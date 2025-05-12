package tools;

import haxe.Http;
import haxe.Timer;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

class Download {

    public static function downloadFile(remotePath:String, localPath:String = "", tmpExtension:String = "tmp", followingLocation:Bool = false):Void {

        if (!followingLocation) {
            if (localPath == null || localPath.length == 0) {
                localPath = Path.withoutDirectory(remotePath);
            }
            if (!Path.isAbsolute(localPath)) {
                localPath = Path.join([context.cwd, localPath]);
            }
        }

        var finalLocalPath = localPath;

        if (!followingLocation) {
            if (tmpExtension != null && tmpExtension.length > 0) {
                localPath += "." + tmpExtension;
            }

            if (FileSystem.exists(localPath)) {
                FileSystem.deleteFile(localPath);
            }
        }

        var out = File.write(localPath, true);
        var progress = new Progress(out);
        var h = new Http(remotePath);

        h.cnxTimeout = 30;

        h.onError = function(e) {
            progress.close();
            FileSystem.deleteFile(localPath);
            throw e;
        };

        if (!followingLocation) {
            print("Downloading " + Path.withoutDirectory(remotePath) + "...");
        }

        h.customRequest(false, progress);

        if (h.responseHeaders != null && (h.responseHeaders.exists("Location") || h.responseHeaders.exists("location"))) {
            var location = h.responseHeaders.get("Location");
            if (location == null)
                location = h.responseHeaders.get("location");

            if (location != remotePath) {
                downloadFile(location, localPath, tmpExtension, true);
            }
        }

        if (!followingLocation) {
            if (finalLocalPath != localPath) {
                if (FileSystem.exists(finalLocalPath)) {
                    FileSystem.deleteFile(finalLocalPath);
                }
                FileSystem.rename(localPath, finalLocalPath);
            }
        }

    }

}

class Progress extends haxe.io.Output {
    var o:haxe.io.Output;
    var cur:Int;
    var max:Null<Int>;
    var start:Float;

    public function new(o) {
        this.o = o;
        cur = 0;
        start = Timer.stamp();
    }

    function bytes(n) {
        cur += n;
        if (max == null)
            Sys.print(cur + " bytes\r");
        else
            Sys.print(cur + "/" + max + " (" + Std.int((cur * 100.0) / max) + "%)\r");
    }

    public override function writeByte(c) {
        o.writeByte(c);
        bytes(1);
    }

    public override function writeBytes(s, p, l) {
        var r = o.writeBytes(s, p, l);
        bytes(r);
        return r;
    }

    public override function close() {
        super.close();
        o.close();
        var time = Timer.stamp() - start;
        var speed = (cur / time) / 1024;
        time = Std.int(time * 10) / 10;
        speed = Std.int(speed * 10) / 10;

        // When the path is a redirect, we don't want to display that the download completed

        if (cur > 400) {
            Sys.print("Download complete : " + cur + " bytes in " + time + "s (" + speed + "KB/s)\n");
        }
    }

    public override function prepare(m:Int) {
        max = m;
    }

}