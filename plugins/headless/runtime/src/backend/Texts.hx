package backend;

import ceramic.Path;

#if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class Texts implements spec.Texts {

    public function new() {}

    public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

        #if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        if (path.startsWith('http://') || path.startsWith('https://')) {
            // Not implemented (yet?)
            done(null);
            return;
        }

        if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) {
            try {
                done(File.getContent(path));
            } catch (e:Dynamic) {
                ceramic.App.app.logger.error('Failed to load file at path: $path, $e');
                done(null);
            }
        }
        else {
            ceramic.App.app.logger.error('File doesn\'t exist at path: $path');
            done(null);
        }

        #else

        ceramic.App.app.logger.warning('Backend cannot read file at path: $path ; returning empty string');
        done('');

        #end

    } //load

} //Textures