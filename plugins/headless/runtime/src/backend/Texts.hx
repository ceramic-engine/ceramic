package backend;

import haxe.io.Path;

using StringTools;

typedef LoadTextOptions = {
    
}

class Texts implements spec.Texts {

    public function new() {}

    public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

        done('');

    } //load

} //Textures