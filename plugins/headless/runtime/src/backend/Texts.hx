package backend;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Texts implements spec.Texts {

    public function new() {}

    public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

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
                ceramic.App.app.logger.error('Failed to load file at path: $path');
                done(null);
            }
        }

    } //load

} //Textures