package backend;

import haxe.io.Path;

using StringTools;

class Texts #if !completion implements spec.Texts #end {

    public function new() {}

    public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

        done('');

    } //load

} //Textures