package tools;

import haxe.io.BytesInput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

class TarGz {

    public static function untarGzFile(source:String, targetPath:String, cwd:String):Void {

        #if (mac || linux)

        // On Mac/Linux we can use the native tar command
        command('tar', ['-xzf', source, '-C', targetPath], { cwd: cwd });

        #elseif windows

        // On Windows we need to handle it manually since there's no built-in tar utility
        var input = File.read(source, true);

        // First decompress the gzip
        var gzipData = format.gz.Reader.readGzipData(input);
        input.close();

        // Then extract the tar
        var tar = new format.tar.Reader(new BytesInput(gzipData.data));
        var entries = tar.read();

        for (entry in entries) {
            var fileName = entry.fileName;

            // Security check: avoid path traversal
            if (fileName.charAt(0) != "/" && fileName.charAt(0) != "\\" && fileName.split("..").length <= 1) {
                var dirs = ~/[\/\\]/g.split(fileName);

                var path = "";
                var file = dirs.pop();

                // Create directory structure
                for (d in dirs) {
                    path += d;
                    FileSystem.createDirectory(targetPath + "/" + path);
                    path += "/";
                }

                // Handle directories
                if (file == "" || entry.fileSize == 0) {
                    // Was just a directory or empty file
                    if (file != "") {
                        var f = File.write(targetPath + "/" + path + file, true);
                        f.close();
                    }
                    continue;
                }

                path += file;

                // Write file content
                var f = File.write(targetPath + "/" + path, true);
                f.write(entry.data);
                f.close();

                // Set permissions if available
                #if (sys)
                try {
                    if (entry.mode != null) {
                        FileSystem.chmod(targetPath + "/" + path, entry.mode);
                    }
                } catch (e:Dynamic) {
                    // Ignore permission errors
                }
                #end
            }
        }

        #else
        throw "Untar on platform " + platform + " not supported";
        #end

    }

}
