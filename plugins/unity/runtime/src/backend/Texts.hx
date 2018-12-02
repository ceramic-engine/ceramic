package backend;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

import unityengine.TextAsset;

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
        
        var textFile:TextAsset = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.TextAsset>({0})', path);

        if (textFile == null) {
            ceramic.App.app.logger.error('Failed to load text file at path: $path');
            done(null);
            return;
        }

        var text = '' + textFile.text;
        untyped __cs__('Resources.UnloadAsset({0})', textFile);
        textFile = null;

        done(text);

        /*
        trace('UNITY LOAD TEXT $path / ' + Sys.getCwd());

        if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) {
            try {
                done(File.getContent(path));
            } catch (e:Dynamic) {
                ceramic.App.app.logger.error('Failed to load file at path: $path');
                done(null);
            }
        }
        else {
            ceramic.App.app.logger.error('File doesn\'t exist at path: $path');
            done(null);
        }*/

    } //load

} //Textures