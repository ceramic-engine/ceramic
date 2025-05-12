package tools;

import haxe.io.Path;
import tools.Helpers.*;

class Zip {

    public static function unzipFile(source:String, targetPath:String, cwd:String):Void {

        #if (mac || linux)

        command('unzip', ['-q', source, '-d', targetPath], { cwd: cwd });

        #elseif windows

        var file = File.read(source, true);
        var entries = Reader.readZip(file);
        file.close();

        var numFiles = 0;

        for (entry in entries) {
            var fileName = entry.fileName;

            if (fileName.charAt(0) != "/" && fileName.charAt(0) != "\\" && fileName.split("..").length <= 1) {
                var dirs = ~/[\/\\]/g.split(fileName);

                var path = "";
                var file = dirs.pop();

                for (d in dirs) {
                    path += d;
                    FileSystem.createDirectory(targetPath + "/" + path);
                    path += "/";
                }

                if (file == "") {
                    continue; // Was just a directory
                }

                path += file;

                var data = Reader.unzip(entry);
                var f = File.write(targetPath + "/" + path, true);

                f.write(data);
                f.close();
            }
        }

        #else
        throw "Unzip on platform " + platform + " not supported";
        #end

    }

}
