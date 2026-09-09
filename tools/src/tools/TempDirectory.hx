package tools;

import cpp.Lib;
import haxe.crypto.Md5;
import timestamp.Timestamp;

using StringTools;

class TempDirectory {

    /**
        Returns the system's temporary directory path.
        Returns `null` if temp directory cannot be determined.
    **/
    static function systemTempDir():String {
        try {
            #if windows
            // Try Windows TEMP/TMP environment variables
            var temp = Sys.getEnv("TEMP");
            if (temp == null) temp = Sys.getEnv("TMP");
            if (temp != null) return haxe.io.Path.removeTrailingSlashes(temp);

            // Fallback to Windows default temp location
            return "C:\\Windows\\Temp";

            #elseif mac
            // macOS temporary directory
            return "/private/tmp";

            #else
            // Linux and other unix systems: honor TMPDIR, then fall back to
            // /tmp. Most distros (Fedora, Debian...) do NOT set TMPDIR, and
            // returning null here made every caller build paths from a null
            // base, which Path.join silently turns into a RELATIVE path: the
            // shade transpiler then littered the project root with Main.hx,
            // import.hx, build.hxml, shaders/ and shade-out/.
            var temp = Sys.getEnv("TMPDIR");
            if (temp != null && temp != "") return haxe.io.Path.removeTrailingSlashes(temp);
            return "/tmp";

            #end
        } catch (e:Dynamic) {
            // If all else fails
        }
        return null;
    }

    /**
        Creates a unique temporary directory within the system temp directory.
        @param prefix Optional prefix for the directory name
        @return String Path to the created directory with trailing slash, or null if creation failed
    **/
    public static function tempDir(prefix:String):Null<String> {

        try {
            var baseDir = systemTempDir();
            if (baseDir == null) return null;

            var timestamp = Timestamp.now();
            var random = Math.random();
            var dirName = '${prefix}_' + Md5.encode('${timestamp} ~ ${random}');
            var fullPath = haxe.io.Path.join([baseDir, dirName]);

            // Ensure directory doesn't exist
            while (sys.FileSystem.exists(fullPath)) {
                timestamp = Timestamp.now();
                random = Math.random();
                var dirName = '${prefix}_' + Md5.encode('${timestamp} ~ ${random}');
                fullPath = haxe.io.Path.join([baseDir, dirName]);
            }

            // Create the directory
            sys.FileSystem.createDirectory(fullPath);

            return haxe.io.Path.removeTrailingSlashes(fullPath);
        } catch (e:Dynamic) {
            return null;
        }

    }

}