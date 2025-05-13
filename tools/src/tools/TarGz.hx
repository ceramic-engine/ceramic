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

        #else

        throw "Untar on current platform not supported";

        #end

    }

}
